# OpenXPKI::Server::Workflow::Activity::Tools::NotifyParentWorkflow
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::NotifyParentWorkflow;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

use Data::Dumper;
use English;

sub execute {
    ##! 1: 'execute'
    my $self      = shift;
    my $workflow  = shift;
    my $context   = $workflow->context();
    my $result    = $self->param('result');
    ##! 16: 'result: ' . $result
    my $parent_id      = $context->param('workflow_parent_id');
    my $parent_wf_type = CTX('api')->get_workflow_type_for_id({
        ID => $parent_id,
    });
    ##! 16: 'workflow_id: ' . $workflow->id()
    ##! 16: 'parent_id: ' . $parent_id
    ##! 16: 'parent_wf_type: ' . $parent_wf_type
    my $serializer = OpenXPKI::Serialization::Simple->new();

    # before executing the activity, we need to clear the condition
    # cache of the parent workflow, as it otherwise (sometimes) falsely
    # reports that the corresponding condition is not available because
    # of an incorrectly cached result.
    # This is maybe a bug in Workflow.pm(?), but we can work around it
    # easily (get_workflow_activities clears the condition cache because
    # it assumes the users wants an up-to-date list of available activities):
    ##! 16: 'clearing cache ...'
    CTX('api')->get_workflow_activities({
        ID       => $parent_id,
        WORKFLOW => $parent_wf_type,
    });
    ##! 16: 'cache cleared ...'
    if ($result eq 'SUCCESS') {
        # fire and forget, if more than one workflow child is forked,
        # the activity might not be available, but we do not care ...
        eval {
            CTX('api')->execute_workflow_activity({
                ID       => $parent_id,
                WORKFLOW => $parent_wf_type,
                ACTIVITY => 'child_finished_successfully',
            });
        };
        ##! 64: 'eval_error from execute_workflow_activity: ' . Dumper $EVAL_ERROR
    }
    elsif ($result eq 'FAILURE') {
        # no eval because this activity should be present all the time
        CTX('api')->execute_workflow_activity({
            ID       => $parent_id,
            WORKFLOW => $parent_wf_type,
            ACTIVITY => 'child_finished_failure',
        });
    }

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::NotifyParentWorkflow

=head1 Description

This activity is used to signal the completion of the workflow to
the parent workflow. Depending on the configuration parameter "result",
an activity is called on the parent workflow to signal it that the
child has completed successfully or not.
