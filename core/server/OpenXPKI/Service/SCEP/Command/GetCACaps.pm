## OpenXPKI::Service::SCEP::Command::GetCACaps
##
## Written 2013 by Oliver Welter for the OpenXPKI project
## (C) Copyright 2013 by The OpenXPKI Project
##
package OpenXPKI::Service::SCEP::Command::GetCACaps;

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
    
    ##! 8: 'start'
    
    my $algs = CTX('api')->get_alg_names();
    
    ##! 8: 'Algs ' . Dumper $algs
 
    # we silently asume that all digests are supported and the server can handle post requests
    # which is true on current systems using the suggested toolchain
    my @caps = qw(GetNextCACert POSTPKIOperation Renewal SHA-512 SHA-256 SHA-1 DES3);
 
    $result = "Content-Type: text/plain\n\n" . join "\n", @caps;
          
    ##! 16: "result: $result"
    return $self->command_response($result);
}
 
1;
__END__

=head1 Name

OpenXPKI::Service::SCEP::Command::GetCACaps

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

