# (C) Copyright 2006 by The OpenXPKI Project
package OpenXPKI::Service::Default::Command::nop;

use English;

use Class::Std;

use base qw( OpenXPKI::Service::Default::Command );

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::API;


sub execute {
    my $self    = shift;
    my $arg     = shift;
    my $ident   = ident $self;
    
    ##! 1: "execute"
    
    return $self->command_response();
}

1;
__END__

=head1 Name

OpenXPKI::Service::Default::Command::nop

=head1 Description

Does nothing at all (may be used as a skeleton implementation for 
other commands)

=head1 Functions

=head2 execute

Returns an empty service message.

