## OpenXPKI::Service::SCEP::Command::GetCACert
##
## Written 2010 by Joachim Astel for the OpenXPKI project
## (C) Copyright 2010 by The OpenXPKI Project
##
package OpenXPKI::Service::SCEP::Command::GetCACaps;

use English;

use Class::Std;

use base qw( OpenXPKI::Service::SCEP::Command );

use OpenXPKI::Debug -l
use OpenXPKI::Exception;
use OpenXPKI::Server::API;
use OpenXPKI::Server::Context qw( CTX );

use Data::Dumper;

sub execute {
    my $self    = shift;
    my $arg_ref = shift;
    my $ident   = ident $self;
    
    ##! 8: "execute GetCACaps"
    my $pki_realm = CTX('session')->get_pki_realm();

    $result = "GetNextCACert\nSHA-256\nSHA-1\nDES3";

    $result = "Content-Type: text/plain\n\n" . $result;
    ##! 16: "result: $result"
    return $self->command_response($result);
}

1;
__END__

=head1 Name

OpenXPKI::Service::SCEP::Command::GetCACaps

=head1 Description

Prints out the capabilities of the SCEP server

=head1 Functions

=head2 execute

Prints out the capabilities of the SCEP server
