package OpenXPKI::Server::API2::Plugin::Cert::validate_certificate;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Cert::validate_certificate

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 validate_certificate

Validate a certificate by creating the chain.

Input can be either a single PEM encoded certificate, a PEM array with the whole
certificate chain or a PKCS7 container.

The return value is a I<HashRef>:

    {
        status => '...',    # validation result
        chain => [ ... ],   # full certificate chain starting with the entity
    }

C<status> can be one of:

=over

=item * I<VALID> - only if C<anchor> is NOT given: valid certificate chain

=item * I<BROKEN> - broken certificate chain (e.g. expired certificates)

=item * I<REVOKED>

=item * I<NOROOT> - incomplete chain or no root certificate found

=item * I<UNTRUSTED> - self signed chain or if C<anchor> is given: none of the
given trust anchors where found in the chain

=back

B<Parameters>

=over

=item * C<pem> I<Str> - PEM encoded certificate (I<Str>)

=item * C<chain> I<ArrayRef> - full certificate chain (list of PEM encoded
certificates) starting with the entity

=item * C<pkcs7> I<Str> - PEM encoded PKCS7 container

=item * C<anchor> I<ArrayRef> - list of trust anchors (certificate identifiers).

The resulting chain is tested against the list. If any of the given certificates
is found in the chain, the result is I<TRUSTED>. Otherwise it is I<UNTRUSTED>.

=back

B<Changes compared to API v1:>

The new parameter C<chain> is used to specify a chain (instead of passing an
I<ArrayRef> to C<PEM>):

    CTX('api')->validate_certificate(PEM   => [ .. ]); # old
    CTX('api')->validate_certificate(chain => [ .. ]); # new

The previously unused parameter C<NOCRL> was removed.

=cut
command "validate_certificate" => {
    pem    => { isa => 'PEM', },
    chain  => { isa => 'ArrayRef[PEM]', },
    pkcs7  => { isa => 'PEM', },
    anchor => { isa => 'ArrayRef[Str]', },
} => sub {
    my ($self, $params) = @_;

    my $default_token = CTX('api')->get_default_token();

    my $signer_chain = [];
    my $chain_status = 'VALID';

    # single PEM certificate, try to load the chain from the database
    if ($params->has_pem) {
        my $info = $self->_get_signer_chain_by_cert($default_token, $params->pem);
        $signer_chain = $info->{chain};
        if (not $info->{is_complete}) {
            return { status => 'NOROOT', chain => $signer_chain },
        }
    }
    elsif ($params->has_chain) {
        $signer_chain = $params->chain;
    }
    elsif ($params->has_pkcs7) {
        $signer_chain = $default_token->command({
            COMMAND => 'pkcs7_get_chain',
            PKCS7 => $params->pkcs7,
        });
    }
    else {
        die "One of the following parameters must be specified: 'pem', 'chain', 'pkcs7'";
    }


    if ($params->has_chain or $params->has_pkcs7) {
        # Get the topmost issuer from the chain
        my $last_in_chain = OpenXPKI::Crypto::X509->new(
            DATA => $signer_chain->[-1], TOKEN => $default_token
        );

        # We use the Authority Key or the Subject as a fallback
        # to find the next matching certificate in our database
        my $result;
        # TODO Handle case where get_authority_key_id() returns HashRef
        if (my $issuer_authority_key_id = $last_in_chain->get_authority_key_id()) {
            ##! 16: ' Search issuer by authority key ' . $issuer_authority_key_id
            $result = $self->api->search_cert(
                subject_key_identifier => $issuer_authority_key_id,
                pki_realm => '_ANY'
            );
        } else {
            my $issuer_subject = $last_in_chain->get_parsed('BODY','ISSUER');
            ##! 16: ' Search issuer by subject ' .$issuer_subject
            $result = $self->api->search_cert(
                subject => $issuer_subject,
                pki_realm => '_ANY'
            );
        }

        my $last_in_chain_is_root =
            $last_in_chain->get_parsed('BODY','ISSUER') eq
            $last_in_chain->get_parsed('BODY','SUBJECT');

        # Nothing found - check if the issuer is already selfsigned
        if (not scalar @$result) {
            if (not $last_in_chain_is_root) {
                ##! 16: 'No issuer on top of pkcs7 found'
                return { status => 'NOROOT', chain => $signer_chain };
            }
            ##! 16: 'Self-Signed pkcs7 chain'
            $chain_status = 'UNTRUSTED';
        }
        # last chain certificate found in database
        else {
            my $found_cert_issuer = $result->[0]->{issuer_identifier};
            my $found_cert_id =     $result->[0]->{identifier};
            # if it is already a root certificate (most likely it is)
            if ($found_cert_issuer eq $found_cert_id) {
                ##! 16: 'Next issuer is already a trusted root'
                if (not $last_in_chain_is_root) {
                    # Load the PEM from the database
                    my $issuer_cert = CTX('api')->get_cert({ IDENTIFIER => $found_cert_id, FORMAT => 'PEM' });
                    ##! 32: 'Push PEM of root ca to chain ' . $issuer_cert
                    push @$signer_chain, $issuer_cert;
                }
            }
            else {
                # The first known certificate is an intermediate, so fetch the
                # remaining certs to complete the chain
                ##! 16: 'cert_identifier ' . $cert_identifier
                my $chain = CTX('api')->get_chain({
                    START_IDENTIFIER => $found_cert_id,
                    OUTFORMAT        => 'PEM',
                });

                push @$signer_chain, @{ $chain->{CERTIFICATES} };

                ##! 32: 'Chain ' . Dumper $chain
                if (!$chain->{COMPLETE}) {
                    return { status => 'NOROOT', chain => $signer_chain };
                };
            }
        }
    }

    my @work_chain = @$signer_chain;
    ##! 32: 'Work Chain ' . Dumper @work_chain

    my $root = pop @work_chain;
    my $entity = shift @work_chain;

    ##! 32: 'Root ' . $root
    ##! 32: 'Entity' . $entity

    my $valid = $default_token->command({
        COMMAND => 'verify_cert',
        CERTIFICATE => $entity,
        TRUSTED => $root,
        CHAIN => join "\n", @work_chain
    });

    $chain_status = 'BROKEN' unless($valid);

    # check given trust anchors
    if ($valid and $params->has_anchor) {
        $chain_status = 'UNTRUSTED';
        my @trust_anchors = @{ $params->anchor };
        ##! 16: 'Checking valid certificate against trust anchor list'
        ##! 32: 'Anchors ' . Dumper @trust_anchors
        for my $pem (@$signer_chain) {
            my $x509 = OpenXPKI::Crypto::X509->new( DATA => $pem, TOKEN => $default_token );
            my $identifier = $x509->get_identifier();
            ##! 16: 'identifier: ' . $identifier
            if (grep { $identifier eq $_ } @trust_anchors) {
                ##! 16: 'Found on trust anchor list'
                $chain_status = 'TRUSTED';
                last;
            }
        }
    }

    return { status => $chain_status, chain => $signer_chain };

};

# Returns the chain of the given certificate
sub _get_signer_chain_by_cert {
    my ($self, $token, $cert_as_pem) = @_;

    ##! 8: 'PEM certificate'
    my $x509 = OpenXPKI::Crypto::X509->new( DATA => $cert_as_pem, TOKEN => $token );
    my $cert_identifier = $x509->get_identifier();

    ##! 16: 'cert_identifier ' . $cert_identifier
    my $chain = CTX('api')->get_chain({
        'START_IDENTIFIER' => $cert_identifier,
        'OUTFORMAT'        => 'PEM',
    });

    ##! 32: 'Chain ' . Dumper $chain
    return {
        is_complete => $chain->{COMPLETE} ? 1 : 0,
        chain => $chain->{CERTIFICATES},
    };
}

__PACKAGE__->meta->make_immutable;
