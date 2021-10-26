package OpenXPKI::Server::Workflow::Condition::WorkflowHasState;

use strict;
use warnings;
use base qw( OpenXPKI::Server::Workflow::Condition );
use OpenXPKI::Server::Context qw( CTX );
use Workflow::Exception qw( condition_error );
use OpenXPKI::Debug;
use English;

sub _evaluate
{
    ##! 1: 'start'
    my ($self) = @_;

    my $wf_id = $self->param('workflow_id');

    my $wfl;
    eval {
        my $result = CTX('api2')->search_workflow_instances(
            id => [ $wf_id ],
            tenant => '',
        );
        ##! 32: $result->[0]
        $wfl = $result->[0] if ($result->[0]);
    };

    if (!$wfl) {
        condition_error('No workflow with id #'.$wf_id.' found');
    }

    if (my $state = $self->param('proc_state')) {
        my ($not, $state) = $state =~ m{(!?)(\w+)};
        my $res = ($state ne $wfl->{workflow_proc_state});
        if ($not xor $res) {
            condition_error('Workflow is not in expected proc_state');
        }
    }

    if (my $state = $self->param('state')) {
        my ($not, $state) = $state =~ m{(!?)(\w+)};
        my $res = ($state ne $wfl->{workflow_state});
        if ($not xor $res) {
            condition_error('Workflow is not in expected state');
        }
    }

    return 1;
}

1;

__END__


=head1 NAME

OpenXPKI::Server::Workflow::Condition::WorkflowHasState

=head1 DESCRIPTION

This condition checks whether the workflow given as workflow_id is in
the given state/proc_state. Condition can be negated by adding ! as
prefix.

If only the workflow_id is given, the condition will only check if the
workflow exists.

=head2 Parameters

=over

=item workflow_id

=item state

=item proc_state

=back