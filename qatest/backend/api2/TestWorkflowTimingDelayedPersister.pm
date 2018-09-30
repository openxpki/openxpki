package TestWorkflowTimingDelayedPersister;
use strict;
use warnings;

use OpenXPKI::Server::Context qw( CTX );

use base qw( OpenXPKI::Server::Workflow::Persister::DBI );


sub update_workflow {
    my ($self, $workflow) = @_;

    if (
        -e $ENV{OXI_TESTENV_ROOT} . '/TestWorkflowTiming_wait_a_bit'
        && $workflow->proc_state eq "running"
        && $workflow->state eq "INTERMEDIATE"
    ) {
        CTX('log')->system()->warn("Delaying workflow for testing...");

        sleep 1;
    }

    return $self->SUPER::update_workflow($workflow);
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Persister::NoHistory

=head1 Description

This persister inherits from the DBI persister but does not create history
items which is very handy for bulk workflows with a large number of steps.
