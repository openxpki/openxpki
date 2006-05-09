package OpenXPKI::Service::Default::Command::list_workflow_titles;

use English;

use Class::Std;

use base qw( OpenXPKI::Service::Default::Command );

use OpenXPKI::Debug 'OpenXPKI::Service::Default::Command::list_workflow_titles';
use OpenXPKI::Exception;
use OpenXPKI::Server::API;


sub execute {
    my $self    = shift;
    my $arg     = shift;
    my $ident   = ident $self;
    
    ##! 1: "execute"
    
    return {
	SERVICE_MSG => 'COMMAND',
	COMMAND => 'list_workflow_titles',
	PARAMS  => {
	    INSTANCES => OpenXPKI::Server::API::list_workflow_titles(),
	},
    };
}

1;

__END__

=head1 Description

Returns a list of all available workflow titles that can be instantiated
via create_workflow().

=head1 Functions

=head2 execute

Implements the command.
