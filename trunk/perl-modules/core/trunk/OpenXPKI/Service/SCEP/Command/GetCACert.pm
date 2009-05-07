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
    my $pki_realm = CTX('session')->get_pki_realm();

    my @ca_cert_chain = $self->__get_ca_certificate_chains();

    ##! 16: 'chain: ' . Dumper(\@ca_cert_Chain)

    my $token_manager = CTX('crypto_layer');
    my $token = $token_manager->get_token(
        TYPE      => 'DEFAULT',
        PKI_REALM => $pki_realm,
    );

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

    my $pki_realm = CTX('session')->get_pki_realm();
    my $server = CTX('session')->get_server();

    my $scep_ca_cert_identifier = CTX('pki_realm')->{$pki_realm}->{scep}->{id}->{$server}->{identifier};
    if (! defined $scep_ca_cert_identifier) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVICE_SCEP_COMMAND_GETCACERT_NO_IDENTIFIER_FOUND',
        );
    }

    my $api = CTX('api');
    my $chain = $api->get_chain({
        'START_IDENTIFIER' => $scep_ca_cert_identifier,
        'OUTFORMAT'        => 'PEM',
    });
    ##! 32: 'chain: ' . Dumper($chain)

    my @ca_chains = @{ $chain->{CERTIFICATES} };

    ##! 32: 'ca_chains: ' . Dumper \@ca_chains;
    
    # we also need to include (other) known CA certificates (and
    # their chain) because the SCEP certificate might be issued by
    # a third party

    my $ca_identifiers = CTX('api')->get_ca_list();

    ##! 32: 'ca identifiers: ' . Dumper $ca_identifiers;
    
    CA:
    foreach my $ca (keys %{ $ca_identifiers }) {
        ##! 16: 'ca identifier: ' . $ca
        my $ca_obj = $ca_identifiers->{$ca}->{'cacert'};

        next CA if (! defined $ca_obj); # skip if no CA object available,
                                        # for example if CA has been configured
                                        # but not yet imported

        my $ca_chain = $api->get_chain({
            'START_IDENTIFIER' => $ca_obj->get_identifier(),
            'OUTFORMAT'        => 'PEM',
        });
        ##! 64: 'ca_chain: ' . Dumper $ca_chain
        foreach my $cert (@{ $ca_chain->{CERTIFICATES} }) {
            ##! 128: 'cert: ' . $cert
            if (! grep { $_ eq $cert } @ca_chains) {
                ##! 32: 'cert is not in ca_chains list, adding it'
                push @ca_chains, $cert;
            }
        }
    }

    ##! 32: 'ca_chains: ' . Dumper \@ca_chains

    ##! 4: 'end'
    return \@ca_chains;
}
1;
__END__

=head1 Name

OpenXPKI::Service::SCEP::Command::GetCACert

=head1 Description

Gets the CA certificate chain.

=head1 Functions

=head2 execute

Returns the CA certificate chain including the HTTP header needed
for the scep CGI script.

