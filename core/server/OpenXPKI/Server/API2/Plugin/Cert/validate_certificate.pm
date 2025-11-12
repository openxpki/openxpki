package OpenXPKI::Server::API2::Plugin::Cert::validate_certificate;
use OpenXPKI -plugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Cert::validate_certificate

=cut

use List::Util qw( any );

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Crypt::X509;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Types;



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

Given extra certificates used in the chain are persisted in the database
if the chain ends up to a known root unless I<volatile> is set.

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

=item * C<novalidity> I<Bool> - treat expired certificates as good

=item * C<crl_check> I<Str> - one of none, soft, leaf, all

=back

B<CRL Check>

For certificates that are managed by this PKI instance, the revocation
status is ALWAYS checked based in the information in the database.

If you want to validate externally issued certificates, you can pass the
I<crl_check> parameter with one of the following values (default is I<none>).
There is currently no special return value for CRL checks, failure to
validate will just return the status "BROKEN".

For details on CRL checking see C<handle_external_crl>, I<import> and
I<autoupdate> will be set to true unless I<volatile> is set.

B<NOTE>: Feature is only available with the enterprise extensions installed.

=over

=item none

Do not perform a CRL check, this is the default.

=item soft

Tries to find a valid CRL for the leaf certificate but will silently skip
the revocation check if no CRL is found.

=item leaf

Tries to find a valid CRL for the leaf certificate, will throw an exception
if there is no fresh CRL information.

=item all

Tries to find a valid CRL for all certifiates in the chain, will throw an
exception if there is no fresh CRL information for any element.

=back

=item * C<volatile> I<Bool> - do not persist chain certificates


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
    crl_check => { isa => 'AlphaPunct', matching => qr{ \A ( none | soft | leaf | all ) \Z }x, default => "none" },
    volatile => { isa => 'Bool', default => 0 },

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
        # receive chain certificates that are not yet in the db
        my @import_cert;
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
                    my $next_id = $cc->get_cert_identifier();
                    if (!$byIdentifier->{ $next_id }) {
                        $byIdentifier->{ $next_id } = $cc;
                        $bySubject->{ $cc->get_subject } = $next_id;
                        $byKeyId->{ $cc->get_subject_key_id } = $next_id;
                    }
                    $cert = $byIdentifier->{ $next_id };
                    # remove as the certificate is added at the top of the loop
                    pop @signer_chain;
                }
            # issuer is not in the database, check the input lists
            } elsif ($aki && $byKeyId->{$aki}) {

                ##! 32: 'Lookup using AKI ' . $aki
                $cert = $byIdentifier->{ $byKeyId->{$aki} };
                push @import_cert, $cert if ($cert);

            } elsif ($bySubject->{ $cert->get_issuer }) {

                ##! 32: 'Lookup using subject '  . $cert->get_issuer
                $cert = $byIdentifier->{ $bySubject->{ $cert->get_issuer } };
                push @import_cert, $cert if ($cert);
            } else {

                ##! 32: 'no more certificates - aborting'
                # unable to proceed as no more certifcates were found
                last;
            }
        }

        # chain building using extra certificates is done
        # check if we need to import stuff
        if ($chain_status eq 'VALID' && @import_cert && !$params->volatile) {
            ##! 32: 'got certs for auto import'
            ##! 64: \@import_cert
            try {
                foreach my $cert (@import_cert) {
                    my $db_insert = $self->api->import_certificate(
                        data  => $cert,
                        ignore_existing => 1,
                    );
                    CTX('log')->system()->info('automated import of chain certificate ' . $cert->get_cert_identifier);
                }
            }
            catch ($err) {
                my $msg = $err;
                $msg = $err->message if ref $err eq 'OpenXPKI::Exception';
                CTX('log')->system->warn("automated import of chain certificate failed with: $msg");
            }
        }
    }

    # it is useless to run a validation if we dont have a root
    # so we can abort here
    ##! 16: 'Got chain with status ' . $chain_status
    if ($chain_status eq 'NOROOT' || $chain_status eq 'REVOKED') {
        return { status => $chain_status, chain => \@signer_chain };
    }

    my @work_chain = @signer_chain;
    ##! 64: \@signer_chain

    my $root = pop @work_chain;

    ##! 64: 'Root ' . $root
    ##! 64: 'Entity' . $entity

    my $command = {
        COMMAND => 'verify_cert',
        # TODO - replace with NOVALIDITY once we have openssl 1.1 - see #446
        ATTIME => $params->novalidity ? ($x509->notafter - 1) : 0,
        CERTIFICATE => $entity,
        TRUSTED => $root,
        CHAIN => join "\n", @work_chain,
    };

    my @cert_to_fetch_crl;
    if (any { $params->crl_check eq $_ } ('soft','leaf')) {
        ##! 32: 'CRL check for leaf only'
        @cert_to_fetch_crl = ($signer_chain[0], $signer_chain[1]);
        $command->{CRL_CHECK} = 'leaf';
    } elsif ($params->crl_check eq 'all') {
        ##! 32: 'CRL check for full chain'
        @cert_to_fetch_crl = @signer_chain;
        $command->{CRL_CHECK} = 'all';
    } elsif ($params->crl_check ne 'none') {
        OpenXPKI::Exception->throw(
            message => 'Unexpected value for crl_check: ' .$params->crl_check
        );
    }

    my @crls;
    for (my $ii=1; $ii<@cert_to_fetch_crl;$ii++) {
        my $issuer_identifier = CTX('api2')->get_cert_identifier( cert => $signer_chain[$ii] );
        ##! 16 'start crl lookup for ' . $issuer_identifier
        my $pem_crl = $self->api->handle_external_crl(
            cert  => $signer_chain[$ii - 1],
            issuer_identifier => $issuer_identifier,
            import  => 1,
            autoupdate => 1,
        );
        OpenXPKI::Exception->throw(
            message => 'Unable to fetch CRL when crl_check is mandatory',
            params => {
                issuer_identifier => $issuer_identifier,
            }
        ) unless ($pem_crl || $params->crl_check eq 'soft');

        ##! 32: 'got crl for ' . $issuer_identifier
        push @crls, $pem_crl;
    }
    $command->{CRL} = join "\n", @crls if (@crls);

    my $valid;
    try{
        $valid = $default_token->command($command);
    } catch ($err) {
        ##! 32: $err
        CTX('log')->system->debug("certificate validation failed with $err");
    }

    ##! 64: 'Validation result ' . Dumper $valid

    if (!$valid) {
        $chain_status = 'BROKEN';

    # check against given trust anchors
    } elsif ($params->has_anchor) {

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
