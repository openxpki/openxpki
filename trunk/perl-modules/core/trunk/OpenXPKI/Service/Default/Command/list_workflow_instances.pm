package OpenXPKI::Service::Default::Command::list_workflow_instances;

use English;

use Class::Std;

use base qw( OpenXPKI::Service::Default::Command );

use OpenXPKI::Debug 'OpenXPKI::Service::Default::Command::list_workflow_instances';
use OpenXPKI::Exception;
use OpenXPKI::Server::API;


sub execute {
    my $self    = shift;
    my $arg     = shift;
    my $ident   = ident $self;

    ##! 1: "execute"

    return {
	SERVICE_MSG => 'COMMAND',
	COMMAND => 'list_workflows',
	PARAMS  => {
	    INSTANCES => OpenXPKI::Server::API::list_workflow_instances(),
	},
    };
}

1;

1;

__END__

=head1 Description

List active workflow instances.

=head1 Functions

=head2 execute

Returns a list of all active workflow instances.
