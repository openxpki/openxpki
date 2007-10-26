# OpenXPKI::Server::Workflow::Activity::Tools::NotifyParentWorkflow
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision$

package OpenXPKI::Server::Workflow::Activity::Tools::NotifyParentWorkflow;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

use IPC::ShareLite;
use Data::Dumper;
use English;

sub execute {
    ##! 1: 'execute'
    my $self      = shift;
    my $workflow  = shift;
    my $context   = $workflow->context();
    my $result    = $self->param('result');
    ##! 16: 'result: ' . $result
    my $parent_id = $context->param('workflow_parent_id');
    ##! 16: 'workflow_id: ' . $workflow->id()
    ##! 16: 'parent_id: ' . $parent_id
    my $serializer = OpenXPKI::Serialization::Simple->new();

    if ($result eq 'SUCCESS') {
        # fire and forget, if more than one workflow child is forked,
        # the activity might not be available, but we do not care ...
        eval {
            CTX('api')->execute_workflow_activity({
                ID       => $parent_id,
                ACTIVITY => 'child_finished_successfully',
            });
        };
        ##! 64: 'eval_error from execute_workflow_activity: ' . defined $EVAL_ERROR ? $EVAL_ERROR : 'none'
    }
    elsif ($result eq 'FAILURE') {
        # no eval because this activity should be present all the time
        CTX('api')->execute_workflow_activity({
            ID       => $parent_id,
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
