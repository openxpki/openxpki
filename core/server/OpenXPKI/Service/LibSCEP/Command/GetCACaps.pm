## OpenXPKI::Service::LibSCEP::Command::GetCACaps
##
## Written 2013 by Oliver Welter for the OpenXPKI project
## (C) Copyright 2013 by The OpenXPKI Project
##
package OpenXPKI::Service::LibSCEP::Command::GetCACaps;

use English;

use Class::Std;

use base qw( OpenXPKI::Service::LibSCEP::Command );

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );


sub execute {

    my $self    = shift;
    my $arg_ref = shift;
    my $ident   = ident $self;

    ##! 8: 'start'

    # we silently asume that all digests are supported
    # which is true on current systems using the suggested toolchain
    my @caps = qw( Renewal POSTPKIOperation SHA-512 SHA-384 SHA-256 SHA-224 SHA-1 DES3 AES);
    my $next_ca = $self->get_next_ca_certificate();
    if ($next_ca) {
        push @caps, 'GetNextCACert';
    }

    $result = "Content-Type: text/plain\n\n" . join "\n", @caps;

    ##! 16: "result: $result"
    return $self->command_response($result);
}

1;
__END__

=head1 Name

OpenXPKI::Service::LibSCEP::Command::GetCACaps

=head1 Description

Return information on the certificates used by the scep server.
Following certs are returned in order:

=over 8

=item scep server certificate

entity certificate used by the scep server

=item scep server chain

the full chain including the root certificate for the scep entity certificate

=item current issuer certificate

the certificate currently used for certificate issuance.

=item issuer chain

the full chain of the issuing ca, starting with the first intermediate certificate.

=back

Certificates used in both scep and issuer chain are only included once.

=head1 Functions

=head2 execute

Returns the CA certificate chain including the HTTP header needed
for the scep CGI script.

