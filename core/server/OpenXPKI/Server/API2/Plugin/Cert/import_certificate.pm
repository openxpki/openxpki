package OpenXPKI::Server::API2::Plugin::Cert::import_certificate;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Cert::import_certificate

=cut

# CPAN modules
use Data::Dumper;

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::MooseParams;



=head1 COMMANDS

=head2 import_certificate

Parameters:

=over

=item * B<DATA>, certificate data (PEM encoded)

=item * B<PKI_REALM> (optional), set the PKI realm to this value (might be overridden by an
issuer's realm)

=item * B<FORCE_NOCHAIN> (optional), 1 = import certificate even if issuer is
unknown (then I<issuer_identifier> will not be set) or has an incomplete
signature chain.

=item * B<FORCE_ISSUER> (optional), 1 = enforce import even if it has an invalid
signature chain (i.e. verification failed).

=item * B<FORCE_NOVERIFY> (optional), 1 = do not validate signature chain (e.g.
if one of the certificates' CA has expired)

=item * B<REVOKED> (optional), Set to 1 to set the certificate status to "REVOKED"

=item * B<UPDATE> (optional), Do not throw an exception if certificate already exists, update it instead

=back

=cut
command "import_certificate" => {
    data           => { isa => 'PEMCert', required => 1, },
    issuer         => { isa => 'AlphaPunct', },
    pki_realm      => { isa => 'AlphaPunct', },
    force_nochain  => { isa => 'Bool', default => 0, },
    force_issuer   => { isa => 'Bool', default => 0, },
    force_noverify => { isa => 'Bool', default => 0, },
    revoked        => { isa => 'Bool', default => 0, },
    update         => { isa => 'Bool', default => 0, },
} => sub {
    my ($self, $params) = @_;

    if ($params->has_issuer and $params->force_nochain) {
        # TODO Use unique exception id instead of text and output command line specific hints in openxpkiadm
        OpenXPKI::Exception->throw(
            message => 'Option force-no-chain is not allowed with explicit issuer, use force-issuer instead!'
        );
    }

    my $dbi = CTX('dbi');
    my $default_token = $self->api->get_default_token();

    my $cert = OpenXPKI::Crypto::X509->new(
        TOKEN => $default_token,
        DATA  => $params->data,
    );
    my $cert_identifier = $cert->get_identifier();

    # Check if the certificate is already in the PKI
    my $existing_cert = $dbi->select_one(
        from => 'certificate',
        columns => [ qw( identifier pki_realm status ) ],
        where => { identifier => $cert_identifier },
    );

    OpenXPKI::Exception->throw(
        message => 'Certificate already exists in database',
        params  => {
            identifier => $existing_cert->{identifier},
            pki_realm => $existing_cert->{pki_realm} || '',
            status => $existing_cert->{status},
        },
    ) if ($existing_cert and not $params->update);

    # Prepare hash to be inserted into DB
    my $cert_legacy = { $cert->to_db_hash() };
    $cert_legacy->{STATUS} = ($params->revoked ? 'REVOKED' : 'ISSUED');
    $cert_legacy->{PKI_REALM} = $params->pki_realm if $params->has_pki_realm;

    # Query issuer certificate
    my $issuer_cert = $self->_get_issuer(
        cert            => $cert,
        explicit_issuer => $params->issuer,
        force_nochain   => $params->force_nochain,
    );

    # cert is self signed
    if ($issuer_cert and $issuer_cert eq "SELF") {
        $cert_legacy->{ISSUER_IDENTIFIER} = $cert_identifier;
    }
    # cert has known issuer
    elsif ($issuer_cert) {
        my $valid;
        #
        # No verfication requested ?
        #
        if ($params->force_noverify) {
            CTX('log')->system()->warn("Importing certificate without chain verification! $cert_identifier / " . $cert->get_subject);
            CTX('log')->audit('system')->warn('certificate import without chain validation', {
                certid    => $cert_identifier,
                key       => $cert->get_subject_key_id(),
            });
            $valid = 1;
        }
        else {
            $valid = $self->_is_issuer_valid(
                default_token  => $default_token,
                cert           => $cert,
                issuer_cert    => $issuer_cert,
                force_nochain  => $params->force_nochain,
            );
        }

        if (!$valid) {
            # force the invalid issuer
            if ($params->force_issuer) {
                CTX('log')->system->warn("Importing certificate with invalid chain with force! $cert_identifier / " . $cert->get_subject());
                CTX('log')->audit('system')->warn('certificate import without chain validation', {
                    certid    => $cert_identifier,
                    key       => $cert->get_subject_key_id(),
                });
            } else {
                OpenXPKI::Exception->throw(
                    message => 'Unable to build certificate chain',
                    params  => { issuer_identifier => $issuer_cert->{identifier}, issuer_subject => $issuer_cert->{subject} },
                );
            }
        }

        $cert_legacy->{ISSUER_IDENTIFIER} = $issuer_cert->{identifier};
        # if the issuer is in a realm, it forces the entity into the same one
        $cert_legacy->{PKI_REALM} = $issuer_cert->{pki_realm} if $issuer_cert->{pki_realm};
    }

    # TODO #legacydb Mapping for compatibility to old DB layer
    my $cert_hash = OpenXPKI::Server::Database::Legacy->certificate_from_legacy($cert_legacy);

    $dbi->merge(
        into => 'certificate',
        set => $cert_hash,
        where => { identifier => $cert_hash->{identifier} },
    );

    # unset data to save bytes and return the remainder of the hash
    delete $cert_hash->{data};

    return $cert_hash;
};

# Returns the certificate issuer DB hash or C<SELF> if it's self signed or
# C<undef> if no issuer was found (and force_nochain = 1).
sub _get_issuer {
    my ($self, %args) = named_args(\@_,   # OpenXPKI::MooseParams
        cert            => { isa => 'OpenXPKI::Crypto::X509' },
        explicit_issuer => { isa => 'Maybe[Str]' },
        force_nochain   => { isa => 'Maybe[Bool]' },
    );
    my $cert            = $args{cert};
    my $cert_identifier = $cert->get_identifier;
    my $explicit_issuer = $args{explicit_issuer};
    my $force_nochain   = $args{force_nochain};

    my $condition;

    #
    # Check for self signed certificate
    #

    # Check if self-signed based on Key Ids, if set
    if (defined $cert->get_subject_key_id and defined $cert->get_authority_key_id) {
        # TODO Handle case where get_authority_key_id() returns HashRef
        $condition = { subject_key_identifier => $cert->get_authority_key_id };
        # self signed
        return "SELF" if $cert->get_subject_key_id() eq $cert->get_authority_key_id;

    # certificates without AIK/SK set
    } else {
        $condition = { subject => $cert->{PARSED}->{BODY}->{ISSUER} };
        # self signed
        return "SELF" if $cert->{PARSED}->{BODY}->{SUBJECT} eq $cert->{PARSED}->{BODY}->{ISSUER};
    }

    #
    # Lookup issuer if not self-signed
    #

    # Explicit issuer wins over issuer query
    $condition = { identifier => $explicit_issuer } if $explicit_issuer;

    my $db_result = CTX('dbi')->select(
        from  => 'certificate',
        columns => [ '*' ],
        where => $condition,
    )->fetchall_arrayref({});

    # No issuer found
    if (scalar @{$db_result} == 0) {
        if ($force_nochain) {
            CTX('log')->system()->warn("Importing certificate without issuer! $cert_identifier / " . $cert->get_subject());
            return;
        }
        OpenXPKI::Exception->throw(
            message => 'Unable to find issuer',
            params  => { query => Dumper($condition) },
        );
    }

    # No issuer found
    if (scalar @{$db_result} > 1) {
        OpenXPKI::Exception->throw(
            message => 'Querying certificate issuer gives ambiguous results',
            params  => {
                result_count => scalar @{$db_result},
                query => Dumper($condition),
            },
        );
    }

    return $db_result->[0];
}

sub _is_issuer_valid  {
    my ($self, %args) = named_args(\@_,   # OpenXPKI::MooseParams
        default_token  => { isa => 'Object' },
        cert           => { isa => 'OpenXPKI::Crypto::X509' },
        issuer_cert    => { isa => 'HashRef' },
        force_nochain  => { isa => 'Maybe[Bool]' },
    );
    my $default_token   = $args{default_token};
    my $cert            = $args{cert};
    my $cert_identifier = $cert->get_identifier;
    my $issuer_cert     = $args{issuer_cert};
    my $force_nochain   = $args{force_nochain};

    #
    # If issuer is already a root
    #
    if ($issuer_cert->{identifier} eq $issuer_cert->{issuer_identifier}) {
        return $default_token->command({
            COMMAND => 'verify_cert',
            CERTIFICATE => $cert->{DATA},
            TRUSTED => $issuer_cert->{data},
        });
    }

    #
    # If issuer is no root, get the chain starting from the issuer
    #

    # validate_certificate
    my $chain = CTX('api')->get_chain({ START_IDENTIFIER => $issuer_cert->{identifier}, OUTFORMAT => 'PEM' });

    # verify a complete chain
    if ($chain->{COMPLETE}) {
        my @work_chain = @{$chain->{CERTIFICATES}};
        my $root = pop @work_chain;

        return $default_token->command({
            COMMAND => 'verify_cert',
            CERTIFICATE => $cert->{DATA},
            TRUSTED => $root,
            CHAIN => join "\n", @work_chain
        });
    }

    # Accept an incomplete chain
    if ($force_nochain) {
        CTX('log')->system()->warn("Importing certificate with incomplete chain! $cert_identifier / " . $cert->get_subject());
        return 1;
    }

    return 0;
}

__PACKAGE__->meta->make_immutable;
