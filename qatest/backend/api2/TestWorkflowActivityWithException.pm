package TestWorkflowActivityWithException;
use OpenXPKI;

use base qw( OpenXPKI::Server::Workflow::Activity );

sub execute {
    my ($self, $workflow) = @_;
    if ($TestWorkflowResume::trigger_exception) {
        OpenXPKI::Exception->throw(
            message => 'Something went terribly wrong',
            params  => { face => 'sad', },
        );
    }
}

1;
