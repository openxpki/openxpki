package OpenXPKI::Server::API2::Plugin::Cert::import_certificate;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Cert::import_certificate

=cut

# CPAN modules
use Data::Dumper;

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::MooseParams;
use OpenXPKI::Crypt::X509;

use OpenXPKI::Server::Database; # to get AUTO_ID

=head1 COMMANDS

=head2 import_certificate

Parameters:

=over

=item * C<data> I<Str> - certificate data (PEM encoded)

=item * C<pki_realm> I<Str> - set the PKI realm to this value (optional, might be
overridden by an issuer's realm)

=item * C<force_nochain> I<Str> - 1 = import certificate even if issuer is
unknown (then I<issuer_identifier> will not be set) or has an incomplete
signature chain. Default: 0

=item * C<force_issuer> I<Bool> - 1 = enforce import even if it has an invalid
signature chain (i.e. verification failed). Default: 0

=item * C<force_noverify> I<Bool> - 1 = do not validate signature chain (e.g.
if one of the certificates' CAs has expired). Default: 0

=item * C<revoked> I<Bool> - set to 1 to set the certificate status to
I<REVOKED>. Default: 0

=item * C<update> I<Bool> - do not throw an exception if certificate already
exists, update it instead. Default: 0

=item * C<profile> I<Str> - set the profile for this certificate as it was
issued by this realm. This requires that the issuer is registered as certsign
alias in the realm and creates a "fake" entry in the CSR table. This should
only be used to import certificates in "dummy realms" or for migration
purposes. B<Note> that the CSR attributes table are NOT filled and not all
workflows might be fully operational with such certificates! The profile
must exist but its settings are not checked against the imported certificate.

=back

=cut
command "import_certificate" => {
    data           => { isa => 'PEMCert', required => 1, },
    issuer         => { isa => 'AlphaPunct', },
    pki_realm      => { isa => 'AlphaPunct', },
    force_nochain  => { isa => 'Bool', default => 0, },
    force_issuer   => { isa => 'Bool', default => 0, },
    force_noverify => { isa => 'Bool', default => 0, },
    revoked        => { isa => 'Bool|HashRef', default => 0, },
    update         => { isa => 'Bool', default => 0, },
    attributes     => { isa => 'HashRef'},
    profile        => { isa => 'Ident'},
} => sub {
    my ($self, $params) = @_;

    if ($params->has_issuer and $params->force_nochain) {
        # TODO Use unique exception id instead of text and output command line specific hints in openxpkiadm
        OpenXPKI::Exception->throw(
            message => 'Option force-no-chain is not allowed with explicit issuer, use force-issuer instead!'
        );
    }

    my $dbi = CTX('dbi');

    my $x509 = OpenXPKI::Crypt::X509->new( $params->data );

    my $cert_identifier = $x509->get_cert_identifier();

    # Check if the certificate is already in the PKI
    my $existing_cert = $dbi->select_one(
        from => 'certificate',
        columns => [ qw( identifier pki_realm status req_key ) ],
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


    my $cert_hash = {
        status => 'ISSUED',
        identifier => $cert_identifier,
        data => $x509->pem,
        issuer_dn => $x509->get_issuer,
        cert_key => $x509->get_serial,
        subject => $x509->get_subject,
        subject_key_identifier =>  $x509->get_subject_key_id,
        authority_key_identifier => $x509->get_authority_key_id,
        notbefore => $x509->get_notbefore()->epoch(),
        notafter => $x509->get_notafter()->epoch(),
    };

    $cert_hash->{pki_realm} = $params->pki_realm if $params->has_pki_realm;

    if ($existing_cert && $existing_cert->{req_key}) {
        $cert_hash->{req_key} = $existing_cert->{req_key};
    }

    # attach revocation information if provided
    if ($params->has_revoked) {
        if (ref $params->revoked eq 'HASH' && scalar keys %{$params->revoked}) {

            $cert_hash->{status} = 'REVOKED';

            my $r = $params->revoked;
            if (!$r->{revocation_time}) {
                $cert_hash->{revocation_time} = time();
            } elsif ($r->{revocation_time} =~ m{\A\d+\z}) {
                $cert_hash->{revocation_time} = $r->{revocation_time};
            } else {
                OpenXPKI::Exception->throw(
                    message => 'Provided revocation_time has invalid format (epoch expected)',
                );
            }

            if (!$r->{invalidity_time}) {
                # leave null
            } elsif ($r->{invalidity_time} =~ m{\A\d+\z}) {
                $cert_hash->{invalidity_time} = $r->{invalidity_time};
            } else {
                OpenXPKI::Exception->throw(
                    message => 'Provided invalidity_time has invalid format (epoch expected)',
                );
            }

            my $reason_code = $r->{reason_code} || 'unspecified';
            if ($reason_code !~ m{ \A (?: unspecified | keyCompromise | CACompromise | affiliationChanged | superseded | cessationOfOperation | certificateHold | removeFromCRL ) \z }xms) {
                OpenXPKI::Exception->throw(
                    message => 'Provided reason_code is not valid',
                );
            }
            $cert_hash->{reason_code} = $reason_code;

            #  hold_instruction_code not supported yet
        } elsif (ref $params->revoked eq '' && $params->revoked) {
            $cert_hash->{status} = 'REVOKED';
            $cert_hash->{revocation_time} = time();
            $cert_hash->{reason_code} = 'unspecified';
        }
    }


    # Query issuer certificate
    my $issuer_cert = $self->_get_issuer(
        cert            => $x509,
        explicit_issuer => $params->issuer,
        force_nochain   => $params->force_nochain,
    );

    my $csr_hash;

    # cert is self signed
    if ($issuer_cert and $issuer_cert eq "SELF") {
        $cert_hash->{issuer_identifier} = $cert_identifier;
    }
    # cert has known issuer
    elsif ($issuer_cert) {
        my $valid;
        #
        # No verfication requested ?
        #
        if ($params->force_noverify) {
            CTX('log')->system()->warn("Importing certificate without chain verification! $cert_identifier / " . $x509->get_subject);
            CTX('log')->audit('system')->warn('certificate import without chain validation', {
                certid    => $cert_identifier,
                key       => $x509->get_subject_key_id(),
            });
            $valid = 1;
        }
        else {
            $valid = $self->_is_issuer_valid(
                cert           => $x509,
                issuer_cert    => $issuer_cert,
                force_nochain  => $params->force_nochain,
            );
        }

        if (!$valid) {
            # force the invalid issuer
            if ($params->force_issuer) {
                CTX('log')->system->warn("Forced import of certificate with invalid! $cert_identifier / " . $x509->get_subject());
                CTX('log')->audit('system')->warn('certificate import without chain validation', {
                    certid    => $cert_identifier,
                    key       => $x509->get_subject_key_id(),
                });
            } else {
                OpenXPKI::Exception->throw(
                    message => 'Unable to build certificate chain',
                    params  => { issuer_identifier => $issuer_cert->{identifier}, issuer_subject => $issuer_cert->{subject} },
                );
            }
        }

        $cert_hash->{issuer_identifier} = $issuer_cert->{identifier};
        # inherit realm if not set explicitly
        if (!$cert_hash->{pki_realm} && $issuer_cert->{pki_realm}) {
            $cert_hash->{pki_realm} = $issuer_cert->{pki_realm};
        }

        if ($params->has_profile) {

            if (!$cert_hash->{pki_realm}) {
                OpenXPKI::Exception->throw(
                    message => 'Realm must be set when importing with profile',
                );
            }

            if (!CTX('config')->exists([ 'realm', $cert_hash->{pki_realm}, 'profile', $params->profile] )) {
                OpenXPKI::Exception->throw(
                    message => 'Profile does not exist',
                    params  => { profile => $params->profile, pki_realm => $cert_hash->{pki_realm} },
                );
            }

            my $cs_group = CTX('config')->get(['realm', $cert_hash->{pki_realm}, 'crypto', 'type', 'certsign']);
            my $issuer_alias = $dbi->select_one(
                from   => 'aliases',
                columns => ['alias'],
                where => {
                    identifier => $cert_hash->{issuer_identifier},
                    pki_realm => $cert_hash->{pki_realm},
                    group_id => $cs_group
                },
            );

            if (!$issuer_alias) {
                OpenXPKI::Exception->throw(
                    message => 'Import with profile requires issuer to be registered as certsign token',
                    params  => { issuer_identifier => $cert_hash->{issuer_identifier}, pki_realm => $cert_hash->{pki_realm}, group_id => $cs_group},
                );
            }

            if (!$cert_hash->{req_key}) {
                $cert_hash->{req_key} = CTX('dbi')->next_id('csr');
                CTX('log')->system()->info("Importing certificate with profile / creating dummy csr");
            }

            $dbi->merge(
                into => 'csr',
                set => {
                    pki_realm => $cert_hash->{pki_realm},
                    format => 'import',
                    profile => $params->profile,
                    subject => $cert_hash->{subject},
                    req_key => $cert_hash->{req_key},
                },
                where => { req_key => $cert_hash->{req_key} },
            );

        }

    } else {
        $cert_hash->{issuer_identifier} = 'unknown';
    }

    $dbi->merge(
        into => 'certificate',
        set => $cert_hash,
        where => { identifier => $cert_hash->{identifier} },
    );

    # unset data to save bytes and return the remainder of the hash
    delete $cert_hash->{data};

    # append attributes if any
    my $attr = $params->has_attributes ? $params->attributes : {};

    if ($attr) {
        ##! 32: 'Attributes ' . Dumper $attr
        foreach my $key (keys %{$attr}) {
            my $val = $attr->{$key};
            if (ref $val eq '') { $val = [ $val ] };

            $dbi->delete(from => 'certificate_attributes',
            where => {
                identifier => $cert_identifier,
                attribute_contentkey => 'meta_'.$key
            });

            foreach my $v (@{$val}) {
                ##! 64: "Adding meta $key : $v"
                $dbi->insert(
                    into => 'certificate_attributes',
                    values => {
                        attribute_key        => AUTO_ID,
                        identifier           => $cert_identifier,
                        attribute_contentkey => 'meta_'.$key,
                        attribute_value      => $v,
                    }
                );
            }
        }
    }

    CTX('log')->system()->info("Certificate ".$cert_hash->{subject}."/$cert_identifier was imported");

    return $cert_hash;
};

# Returns the certificate issuer DB hash or C<SELF> if it's self signed or
# C<undef> if no issuer was found (and force_nochain = 1).
sub _get_issuer {
    my ($self, %args) = named_args(\@_,   # OpenXPKI::MooseParams
        cert            => { isa => 'OpenXPKI::Crypt::X509' },
        explicit_issuer => { isa => 'Maybe[Str]' },
        force_nochain   => { isa => 'Maybe[Bool]' },
    );
    my $cert            = $args{cert};
    my $cert_identifier = $cert->get_cert_identifier;
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
        $condition = { subject => $cert->get_issuer };
        # self signed
        return "SELF" if $cert->get_issuer eq $cert->get_subject;
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
        cert           => { isa => 'OpenXPKI::Crypt::X509' },
        issuer_cert    => { isa => 'HashRef' },
        force_nochain  => { isa => 'Maybe[Bool]' },
    );
    my $default_token   = $self->api->get_default_token();
    my $cert            = $args{cert};
    my $cert_identifier = $cert->get_cert_identifier;
    my $issuer_cert     = $args{issuer_cert};
    my $force_nochain   = $args{force_nochain};

    ##! 64: 'Cert ' . Dumper $cert
    #
    # If issuer is already a root
    #
    if ($issuer_cert->{identifier} eq $issuer_cert->{issuer_identifier}) {
        ##! 32: 'Validate self-signed ' . $issuer_cert->{identifier}
        return $default_token->command({
            COMMAND => 'verify_cert',
            CERTIFICATE => $cert->pem,
            TRUSTED => $issuer_cert->{data},
            # TODO - replace with NOVALIDITY once we have openssl 1.1 - see #446
            ATTIME => $cert->notbefore + 1,
        });
    }

    #
    # If issuer is no root, get the chain starting from the issuer
    #

    # validate_certificate
    my $chain = $self->api->get_chain( start_with => $issuer_cert->{identifier}, format => 'PEM' );

    # verify a complete chain
    ##! 64: 'Validate chain ' . Dumper $chain
    if ($chain->{complete}) {
        my @work_chain = @{$chain->{certificates}};
        my $root = pop @work_chain;

        my $res = $default_token->command({
            COMMAND => 'verify_cert',
            CERTIFICATE => $cert->pem,
            # TODO - replace with NOVALIDITY once we have openssl 1.1 - see #446
            ATTIME => $cert->notbefore + 1,
            TRUSTED => $root,
            CHAIN => join "\n", @work_chain
        });
        ##! 32: 'verify result ' . Dumper $res
        return $res;
    }

    # Accept an incomplete chain
    if ($force_nochain) {
        CTX('log')->system()->warn("Importing certificate with incomplete chain! $cert_identifier / " . $cert->get_subject());
        return 1;
    }

    return 0;
}

__PACKAGE__->meta->make_immutable;
