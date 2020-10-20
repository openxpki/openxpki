package OpenXPKI::Server::API2::Plugin::Cert::validate_certificate;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Cert::validate_certificate

=cut

use Data::Dumper;

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Crypt::X509;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 validate_certificate

Validate a certificate by creating the chain, extra certificates passed via
chain or in a pkcs7 container are used together with the certificates held
in the database.

If a PKCS7 container is provided, I<pem> and I<chain> are ignored.

If I<chain> is given but I<pem> is not, the first item of the given array
is taken as entity, the remaining certificates are used to build the chain.
The recommended use is to pass the entity via I<pem> and any extra chain
certificates via I<chain>, where chain can be omitted if the required
chain certificates are all in the database.

If I<anchor> is set, the resulting chain is tested against the list. If any
of the given certificates is found in the chain, the result is I<TRUSTED>.
Otherwise it is I<UNTRUSTED>.

The return value is a I<HashRef>:

    {
        status => '...',    # validation result
        chain => [ ... ],   # full certificate chain starting with the entity
    }

C<status> can be one of:

=over

=item * I<VALID> - only if C<anchor> is NOT given: certificate chain can be
build and ends with a root certificate held inside the database.

=item * I<BROKEN> - broken certificate chain (e.g. expired certificates)

=item * I<REVOKED> - chain contains a revoked certificate (revocation
status is considered for certificates in local database only!)

=item * I<NOROOT> - root certificate not found

=item * I<UNTRUSTED> - chain can be build but root certificate is not in
local database, if C<anchor> is given: chain does not match trust list

=item * I<TRUSTED> - only if C<anchor> is given: chain is valid and matches
trust list.

=back

B<Parameters>

=over

=item * C<pem> I<Str> - PEM encoded certificate (I<Str>)

=item * C<chain> I<ArrayRef> - full certificate chain (list of PEM encoded
certificates)

=item * C<pkcs7> I<Str> - PEM encoded PKCS7 container

=item * C<anchor> I<ArrayRef> - list of trust anchors (certificate identifiers).

=back

B<Changes compared to API v1:>

The new parameter C<chain> is used to specify a chain (instead of passing an
I<ArrayRef> to C<PEM>):

    CTX('api')->validate_certificate(PEM   => [ .. ]); # old
    CTX('api2')->validate_certificate(chain => [ .. ]); # new

The previously unused parameter C<NOCRL> was removed.

=cut
command "validate_certificate" => {
    pem    => { isa => 'PEM', },
    chain  => { isa => 'ArrayRefOrPEMCertChain', coerce => 1, },
    pkcs7  => { isa => 'PEM', },
    anchor => { isa => 'ArrayRef[Str]', },
    novalidity => { isa => 'Bool', default => 0 },
    crl_check => { isa => 'AlphaPunct', matching => qr{ \A ( none | leaf | all ) \Z }x, default => "none" },

} => sub {
    my ($self, $params) = @_;

    my $default_token = $self->api->get_default_token();

    my $chain_status = 'NOROOT';
    my @extra_certs;

    my $entity;

    if ($params->has_pem) {
        $entity = $params->pem;
    }

    if ($params->has_chain) {
        @extra_certs = @{$params->chain};
        $entity = shift @extra_certs unless($entity);
    }
    elsif ($params->has_pkcs7) {
        my $pkcs7_certs = $default_token->command({
            COMMAND => 'pkcs7_get_chain',
            PKCS7 => $params->pkcs7,
        });
        @extra_certs = @{$pkcs7_certs};
        $entity = shift @extra_certs;
    }

    if (!$entity) {
        die "One of the following parameters must be specified: 'pem', 'chain', 'pkcs7'";
    }

    # check if the entity is in the db so we have the chain already
    ##! 8: 'PEM certificate'

    my $x509 = OpenXPKI::Crypt::X509->new( $entity );
    my $cert_identifier = $x509->get_cert_identifier();

    ##! 16: 'cert_identifier ' . $cert_identifier
    # this will only return data if the entity itself is in the database
    my $chain = $self->api->get_chain(
        'start_with' => $cert_identifier,
        'format'     => 'PEM',
        'keeproot'   => 1,
    );

    ##! 32: 'Chain ' . Dumper $chain

    my @signer_chain;
    # if the chain is complete in the db we just use it
    if ($chain->{revoked}) {
        ##! 16: 'Entity found but revoked';
        $chain_status = 'REVOKED';
        @signer_chain =  @{$chain->{certificates}};

    } elsif ($chain->{complete}) {
        ##! 16: 'Entity found and valid';
        $chain_status = 'VALID';
        @signer_chain =  @{$chain->{certificates}};

    # try to build the chain and also use the provided certificates
    } else  {

        ##! 16: 'Entity not in database';
        my $byIdentifier = { $cert_identifier => $x509 };
        my $bySubject = { $x509->get_subject => $cert_identifier };
        my $byKeyId = { $x509->get_subject_key_id => $cert_identifier };

        while (my $pem = shift @extra_certs) {
            ##! 64: 'Next cert ' . $pem
            my $cert = OpenXPKI::Crypt::X509->new( $pem );
            my $id = $cert->get_cert_identifier();
            ##! 32: 'Next cert id ' . $id
            $byIdentifier->{ $id } = $cert ;
            $bySubject->{ $cert->get_subject } = $id;
            $byKeyId->{ $cert->get_subject_key_id } = $id;

        }

        # Start with the entity and try to find the next issuer
        my $cert = $x509;

        my $MAX_DEPTH = 16;
        while ($cert && $MAX_DEPTH--) {

            push @signer_chain, $cert->pem;

            if ($cert->is_selfsigned()) {
                ##! 16: 'Found self-signed'
                $chain_status = 'UNTRUSTED';
                last;
            }

            my $where;
            my $aki = $cert->get_authority_key_id;
            if ($aki) {
                $where = { 'subject_key_identifier' => $aki };
            } else {
                $where = { 'subject' => $cert->get_issuer };
            }

            ##! 64: 'Query database ' . Dumper $where;

            my $db_cert = CTX('dbi')->select_one(
                columns => [ 'identifier' ],
                from => 'certificate',
                where => $where
            );

            # if the certificate is in the database, we expect that we can
            # resolve the chain using the database
            my $next_id;
            if ($db_cert) {
                ##! 32: 'Issuer found in database ' . $db_cert->{identifier}
                my $db_chain = $self->api->get_chain(
                    start_with => $db_cert->{identifier},
                    format => 'PEM'
                );
                push @signer_chain, @{$db_chain->{certificates}};

                if ($db_chain->{revoked}) {
                    ##! 16: 'Chain in database but revoked'
                    $chain_status = 'REVOKED';
                    last;
                } elsif ($db_chain->{complete}) {
                    ##! 16: 'Chain in database and valid'
                    $chain_status = 'VALID';
                    last;
                } else {
                    ##! 16: 'Chain in database but incomplete'
                    CTX('log')->application()->warn('Incomplete chain in database during validate certificate');
                    my $cc = OpenXPKI::Crypt::X509->new( pop @{$db_chain->{certificates}} );
                    $next_id = $cc->get_cert_identifier();
                    if (!$byIdentifier->{ $next_id }) {
                        $byIdentifier->{ $next_id } = $cc;
                        $bySubject->{ $cc->get_subject } = $next_id;
                        $byKeyId->{ $cc->get_subject_key_id } = $next_id;
                    }
                    # remove as the certificate is added at the top of the loop
                    pop @signer_chain;
                }
            # issuer is not in the database, check the input lists
            } elsif (!$aki || !$byKeyId->{$aki}) {
                ##! 32: 'Lookup using subject '  . $cert->get_issuer
                $next_id  = $bySubject->{ $cert->get_issuer };
            } else {
                ##! 32: 'Lookup using AKI ' . $aki
                $next_id = $byKeyId->{$aki};
            }
            $cert = $next_id ? $byIdentifier->{ $next_id } : undef;
        }
    }

    # it is useless to run a validation if we dont have a root
    # so we can abort here
    ##! 16: 'Got chain with status ' . $chain_status
    if ($chain_status eq 'NOROOT' || $chain_status eq 'REVOKED') {
        return { status => $chain_status, chain => \@signer_chain };
    }

    my @work_chain = @signer_chain;
    ##! 64: 'Work Chain ' . Dumper \@work_chain

    my $root = pop @work_chain;

    ##! 32: 'Root ' . $root
    ##! 32: 'Entity' . $entity

    my $command = {
        COMMAND => 'verify_cert',
        # TODO - replace with NOVALIDITY once we have openssl 1.1 - see #446
        ATTIME => $params->novalidity ? ($x509->notafter - 1) : 0,
        CERTIFICATE => $entity,
        TRUSTED => $root,
        CHAIN => join "\n", @work_chain,
    };

    if ($params->crl_check eq 'leaf') {
        ##! 32: 'CRL check for leaf'
        my $issuer_identifier = CTX('api2')->get_cert_identifier( cert => $signer_chain[1] );
        ##! 64: 'need crl for ' . $issuer_identifier
        $command->{CRL} = CTX('api2')->get_crl( issuer_identifier => $issuer_identifier );
        $command->{CRL_CHECK} = 'leaf';
    } elsif ($params->crl_check ne 'none') {
        ##! 32: 'CRL check for full chain'
        my @crls;
        for (my $ii=1; $ii<@signer_chain;$ii++) {
            my $issuer_identifier = CTX('api2')->get_cert_identifier( cert => $signer_chain[$ii] );
            ##! 64: 'need crl for ' . $issuer_identifier
            push @crls, CTX('api2')->get_crl( issuer_identifier => $issuer_identifier );
        }
        $command->{CRL} = join "\n", @crls;
        $command->{CRL_CHECK} = 'all';
    }

    my $valid = $default_token->command($command);

    ##! 64: 'Validation result ' . Dumper $valid

    $chain_status = 'BROKEN' unless($valid);

    # check given trust anchors
    if ($valid and $params->has_anchor) {
        $chain_status = 'UNTRUSTED';
        my @trust_anchors = @{ $params->anchor };
        ##! 16: 'Checking valid certificate against trust anchor list'
        ##! 32: 'Anchors ' . Dumper @trust_anchors
        foreach my $pem (@signer_chain) {
            my $identifier = $self->api->get_cert_identifier( cert => $pem );
            ##! 16: 'identifier: ' . $identifier
            if (grep { $identifier eq $_ } @trust_anchors) {
                ##! 16: 'Found on trust anchor list'
                $chain_status = 'TRUSTED';
                last;
            }
        }
    }

    return { status => $chain_status, chain => \@signer_chain };

};

__PACKAGE__->meta->make_immutable;
