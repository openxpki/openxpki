## OpenXPKI::Service::SCEP::Command::GetCACert
##
## Written 2006 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project
##
package OpenXPKI::Service::SCEP::Command::GetCACert;

use English;

use Class::Std;

use base qw( OpenXPKI::Service::SCEP::Command );

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::API;
use OpenXPKI::Server::Context qw( CTX );

use Data::Dumper;

sub execute {
    my $self    = shift;
    my $arg_ref = shift;
    my $ident   = ident $self;

    ##! 8: "execute GetCACert"
    my $pki_realm = CTX('session')->data->pki_realm;

    my @ca_cert_chain = $self->__get_ca_certificate_chains();

    ##! 16: 'chain: ' . Dumper(\@ca_cert_Chain)

    my $token = CTX('api')->get_default_token();

    # use Crypto API to convert CA certificate chain from
    # an array of PEM strings to a PKCS#7 container.
    $result = $token->command({
        COMMAND          => 'convert_cert',
        DATA             => @ca_cert_chain,
        OUT              => 'DER',
        CONTAINER_FORMAT => 'PKCS7',
    });

    $result = "Content-Type: application/x-x509-ca-ra-cert\n\n" . $result;
    ##! 16: "result: $result"
    return $self->command_response($result);
}

sub __get_ca_certificate_chains : PRIVATE {
    ##! 4: 'start'
    my $self = shift;

    my $pki_realm = CTX('session')->data->pki_realm;
    my $server = CTX('session')->data->server;

    my $strip_root;
    if ($server) {
        $strip_root = CTX('config')->get(['scep', $server, 'response', 'getcacert_strip_root']) ? 1 : 0;
    }

    my $scep_cert_alias = $self->__get_token_alias( $server );
    my $scep_ca_cert_identifier = CTX('api')->get_certificate_for_alias({ ALIAS => $scep_cert_alias })->{IDENTIFIER};

    if (! defined $scep_ca_cert_identifier) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVICE_SCEP_COMMAND_GETCACERT_NO_IDENTIFIER_FOUND',
        );
    }

    my $api = CTX('api');
    my $scep_chain = $api->get_chain({
        'START_IDENTIFIER' => $scep_ca_cert_identifier,
        'OUTFORMAT'        => 'PEM',
    });
    ##! 32: 'chain: ' . Dumper($chain)

    my @chain_result = @{ $scep_chain->{CERTIFICATES} };

    # if the chain has the complete flag, the root is included
    # but we dont want it in the response, so pop it off the list
    # take care about scep server with a out-of-ca self signed cert
    if ($scep_chain->{COMPLETE} && scalar @chain_result > 1 && $strip_root) {
        ##! 16: 'Strip of scep root'
        pop @chain_result;
    }

    ##! 32: 'chain_result: ' . Dumper \@chain_result;

    # chain_result now has the full chain of the scep server entity certificate
    # Now we will include the current issuing certificate
    # The current issuer is obtained by get_token_alias_by_type api call


    my $ca_issuer_alias = CTX('api')->get_token_alias_by_type( { TYPE => 'certsign' });
    ##! 32: 'ca issuer: ' . Dumper $ca_issuer_alias ;


    my $ca_issuer = CTX('api')->get_certificate_for_alias( { ALIAS => $ca_issuer_alias } );

    my $ca_chain = $api->get_chain({
        'START_IDENTIFIER' => $ca_issuer->{IDENTIFIER},
        'OUTFORMAT'        => 'PEM',
    });

    # Holds the chain of the current issuer
    ##! 64: 'ca_chain: ' . Dumper $ca_chain

    # if the chain has the complete flag, the root is included
    # but we dont want it in the response, so pop it off the list
    my @issuer_chain = @{ $ca_chain->{CERTIFICATES} };
    if ($ca_chain->{COMPLETE} && $strip_root) {
        ##! 16: 'Strip of issuer root'
        pop @issuer_chain;
    }

    foreach my $cert (@issuer_chain) {
        ##! 128: 'cert: ' . $cert
        if (! grep { $_ eq $cert } @chain_result) {
            ##! 32: 'cert is not in chain_result list, adding it'
            push @chain_result, $cert;
        }
    }

    ##! 32: 'chain_result: ' . Dumper \@chain_result

    ##! 4: 'end'
    return \@chain_result;
}
1;
__END__

=head1 Name

OpenXPKI::Service::SCEP::Command::GetCACert

=head1 Description

Return information on the certificates used by the scep server.
Following certs are returned in order:

=over 8

=item scep server certificate

entity certificate used by the scep server

=item scep server chain

the full chain including without the root certificate for the scep entity certificate

=item current issuer certificate

the certificate currently used for certificate issuance.

=item issuer chain

the chain of the issuing ca, starting with the first intermediate certificate.

=back

Certificates used in both scep and issuer chain are only included once.

=head1 Functions

=head2 execute

Returns the CA certificate chain including the HTTP header needed
for the scep CGI script.

