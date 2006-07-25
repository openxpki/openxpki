## OpenXPKI::Service::SCEP::Command::GetCACert
##
## Written 2006 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project
## $Revision: 235 $
##
package OpenXPKI::Service::SCEP::Command::GetCACert;

use English;

use Class::Std;

use base qw( OpenXPKI::Service::SCEP::Command );

use OpenXPKI::Debug 'OpenXPKI::Service::SCEP::Command::GetCACert';
use OpenXPKI::Exception;
use OpenXPKI::Server::API;
use OpenXPKI::Server::Context qw( CTX );
use Data::Dumper;
use OpenXPKI::Crypto::TokenManager;

sub execute {
    my $self    = shift;
    my $arg_ref = shift;
    my $ident   = ident $self;
    
    ##! 8: "execute GetCACert"
    my $pki_realm = CTX('session')->get_pki_realm();

    my @ca_cert_chain = $self->__get_ca_certificate_chain();

    my $token_manager = OpenXPKI::Crypto::TokenManager->new();
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

sub __get_ca_certificate_chain : PRIVATE {
    # debugging only for now, we need to be able to get the real
    # certificate chain as an array of X509 objects
    # $cert1 and $cert2 are just random test CA certs created by
    # the OpenXPKI tests.
    $cert1 = << "XEOF";
-----BEGIN CERTIFICATE-----
MIIEJjCCA4+gAwIBAgIBATANBgkqhkiG9w0BAQUFADA/MRQwEgYKCZImiZPyLGQB
GRYEaW5mbzEYMBYGCgmSJomT8ixkARkWCE9wZW5YUEtJMQ0wCwYDVQQDDARDQV8x
MB4XDTA1MDcyMDEwNTA0NloXDTA3MDcyMDExNTA0NlowPzEUMBIGCgmSJomT8ixk
ARkWBGluZm8xGDAWBgoJkiaJk/IsZAEZFghPcGVuWFBLSTENMAsGA1UEAwwEQ0Ff
MTCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEA3vb3ZYQ3NMwFZyMwVo22dH/3
u8/R8FtsKUL6bjWoXiYUpWGo/BnlxAI53YQZWo3UQ2UeH6YmMGL4qnz2sNxHczeN
sojfwh9J7Ahuai1fKhHzKA2noAAXe7sTbkS8HCgR2xfJJGHVmUQ22MxtZgOZo0Xo
W/pOo6UplqKt9qGwrUsCAwEAAaOCAjAwggIsMF4GCCsGAQUFBwEBBFIwUDAnBggr
BgEFBQcwAoYbaHR0cDovL2xvY2FsaG9zdC9jYWNlcnQuY3J0MCUGCCsGAQUFBzAB
hhlodHRwOi8vb2NzcC5vcGVueHBraS5vcmcvMFEGA1UdIwRKMEihQ6RBMD8xFDAS
BgoJkiaJk/IsZAEZFgRpbmZvMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTAL
BgNVBAMMBENBXzGCAQEwDwYDVR0TAQH/BAUwAwEB/zBhBgNVHR8EWjBYMCCgHqAc
hhpodHRwOi8vbG9jYWxob3N0L2NhY3JsLmNydDA0oDKgMIYubGRhcDovL2xvY2Fs
aG9zdC9jbj1NeSUyMENBLGRjPU9wZW5YUEtJLGRjPW9yZzAJBgNVHRIEAjAAMAsG
A1UdDwQEAwIBBjApBglghkgBhvhCAQQEHBYaaHR0cDovL2xvY2FsaG9zdC9jYWNy
bC5jcnQwKQYJYIZIAYb4QgEDBBwWGmh0dHA6Ly9sb2NhbGhvc3QvY2FjcmwuY3J0
MBEGCWCGSAGG+EIBAQQEAwIEsDBjBglghkgBhvhCAQ0EVhZUVGhpcyBpcyB0aGUg
Um9vdCBDQSBjZXJ0aWZpY2F0ZS5cbgkgICAgR2VuZXJhdGVkIHdpdGggT3BlblhQ
S0kgdHJ1c3RjZW50ZXIgc29mdHdhcmUuMB0GA1UdDgQWBBQOEZ2GX5jQ8RY5sJTs
1f6K7Nj/jzANBgkqhkiG9w0BAQUFAAOBgQB4oZ/sbB/v03ZR4JmCTTd42exWMWAS
H7zv9m0W5yzh7WiCwsxerO+xi0RzpbzZfyIMGH/lHRcRSJqdGlEQTmSkvvqkHDhL
AE8pwig8ePNBRfEogVw3qsHrXQfKbMHDIY+j+6Z6VZNdYP/SoYDwLxbF50T0LN/1
LRSpOyYNUSu9Eg==
-----END CERTIFICATE-----
XEOF
    $cert2 = << "XEOF";
-----BEGIN CERTIFICATE-----
MIIEJjCCA4+gAwIBAgIBATANBgkqhkiG9w0BAQUFADA/MRQwEgYKCZImiZPyLGQB
GRYEaW5mbzEYMBYGCgmSJomT8ixkARkWCE9wZW5YUEtJMQ0wCwYDVQQDDARDQV8x
MB4XDTA1MDcyMDExMTg1OFoXDTA3MDcyMDEyMTg1OFowPzEUMBIGCgmSJomT8ixk
ARkWBGluZm8xGDAWBgoJkiaJk/IsZAEZFghPcGVuWFBLSTENMAsGA1UEAwwEQ0Ff
MTCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEAz9lk0YTvgRXm8F8sAJPsO2cB
rgIr9XE4IrwJy4qneP3DEJDIQrlz6ahigADYXeUlgCq9L8QM0fy3coUj9FNknakA
nI8Hfflcbj6+Q/AA8FUfxp8CzWz2eEsif90IsmANrjVGzBOkWn3OuaQuPrXdWHkh
RDZx+yfNQYQtCrd0CnMCAwEAAaOCAjAwggIsMF4GCCsGAQUFBwEBBFIwUDAnBggr
BgEFBQcwAoYbaHR0cDovL2xvY2FsaG9zdC9jYWNlcnQuY3J0MCUGCCsGAQUFBzAB
hhlodHRwOi8vb2NzcC5vcGVueHBraS5vcmcvMFEGA1UdIwRKMEihQ6RBMD8xFDAS
BgoJkiaJk/IsZAEZFgRpbmZvMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTAL
BgNVBAMMBENBXzGCAQEwDwYDVR0TAQH/BAUwAwEB/zBhBgNVHR8EWjBYMCCgHqAc
hhpodHRwOi8vbG9jYWxob3N0L2NhY3JsLmNydDA0oDKgMIYubGRhcDovL2xvY2Fs
aG9zdC9jbj1NeSUyMENBLGRjPU9wZW5YUEtJLGRjPW9yZzAJBgNVHRIEAjAAMAsG
A1UdDwQEAwIBBjApBglghkgBhvhCAQQEHBYaaHR0cDovL2xvY2FsaG9zdC9jYWNy
bC5jcnQwKQYJYIZIAYb4QgEDBBwWGmh0dHA6Ly9sb2NhbGhvc3QvY2FjcmwuY3J0
MBEGCWCGSAGG+EIBAQQEAwIEsDBjBglghkgBhvhCAQ0EVhZUVGhpcyBpcyB0aGUg
Um9vdCBDQSBjZXJ0aWZpY2F0ZS5cbgkgICAgR2VuZXJhdGVkIHdpdGggT3BlblhQ
S0kgdHJ1c3RjZW50ZXIgc29mdHdhcmUuMB0GA1UdDgQWBBR/7y7L553yB366pSCf
JsOGMBIZpjANBgkqhkiG9w0BAQUFAAOBgQBTWJvhyk+jOpLDRCo8n5KBpkLsmq6N
PlpQXqOjP5DYnWwfkkI08Dh7E4a3WvaBWz/mdgykvs502Fle55cmFEe3ZDV3PxQA
ci9/oXsZuqSk5tAEfQg18yqMZWcTjdQ1n/ZGLRyS+47dbLetJmog2cWIhtq7JiZ+
cYR5JKg1cUvcpw==
-----END CERTIFICATE-----
XEOF
    my @cert_array = ($cert1, $cert2);
    return \@cert_array;
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

