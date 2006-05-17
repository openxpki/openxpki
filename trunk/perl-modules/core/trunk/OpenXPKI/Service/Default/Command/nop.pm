package OpenXPKI::Service::Default::Command::nop;

use English;

use Class::Std;

use base qw( OpenXPKI::Service::Default::Command );

use OpenXPKI::Debug 'OpenXPKI::Service::Default::Command::nop';
use OpenXPKI::Exception;
use OpenXPKI::Server::API;


sub execute {
    my $self    = shift;
    my $arg     = shift;
    my $ident   = ident $self;
    
    ##! 1: "execute"
    
    return {
	SERVICE_MSG => 'COMMAND',
	COMMAND => 'nop',
	PARAMS  => {
	},
    };
}

1;

__END__

=head1 Description

Does nothing at all (may be used as a skeleton implementation for 
other commands)

=head1 Functions

=head2 execute

Returns an empty service message.

