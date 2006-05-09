package OpenXPKI::Service::Default::Command::list_workflows;

use English;

use Class::Std;

use base qw( OpenXPKI::Service::Default::Command );

use OpenXPKI::Debug 'OpenXPKI::Service::Default::Command::list_workflows';
use OpenXPKI::Exception;
use OpenXPKI::Server::API;


sub execute {
    my $self  = shift;
    my $arg   = shift;
    my $ident = ident $self;

    return {
	SERVICE_MSG => 'COMMAND',
	COMMAND => $command{$ident},
	PARAMS  => {
	    MESSAGE => [ 123, 456, 789 ],
	},
    };
    ##! 1: execute
}
