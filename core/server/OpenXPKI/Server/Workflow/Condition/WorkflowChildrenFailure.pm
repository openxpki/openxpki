# OpenXPKI::Server::Workflow::Condition::WorkflowChildrenFailure
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::WorkflowChildrenFailure;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use English;
use OpenXPKI::Serialization::Simple;

use Data::Dumper;

sub evaluate {
    ##! 16: 'start'
    my ( $self, $workflow ) = @_;
    my $serializer = OpenXPKI::Serialization::Simple->new();

    my $context  = $workflow->context();
    ##! 16: 'context: ' . Dumper($context)
    my @wf_children = @{$serializer->deserialize($context->param('wf_children_instances'))};

    my $child_failure = 0;

    foreach my $child (@wf_children) {
        my $child_id   = $child->{ID};
        my $child_type = $child->{TYPE};

        ##! 16: 'child: ' . $child_id
    
        if (! defined $child_id || ! defined $child_type) {
            ##! 16: 'child not found!'
            my $errors = [[ 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_WORKFLOWCHILDRENFAILURE_NO_WF_CHILD_INSTANCE_ID_OR_TYPE_FOUND' ]];
            $context->param('__error' => $errors);
            condition_error($errors->[0]);
        }
    
        my $api = CTX('api');

        my $child_info = $api->get_workflow_info({
            ID       => $child_id,
            WORKFLOW => $child_type,
        });
        ##! 16: 'child state: ' . $child_info->{WORKFLOW}->{STATE}

        if ($child_info->{WORKFLOW}->{STATE} eq 'FAILURE') {
            ##! 16: 'child failed'
            $child_failure = 1;
        }
    }
    if (! $child_failure) {
            condition_error('I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_WORKFLOWCHILDRENFAILURE_NO_CHILD_FAILED');
    }
    return 1;
    ##! 16: 'end'
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::WorkflowChildrenFailure

=head1 SYNOPSIS

<action name="do_something">
  <condition name="workflow_child_instance_failed"
             class="OpenXPKI::Server::Workflow::Condition::WorkflowChildrenFailure">
  </condition>
</action>

=head1 DESCRIPTION

The condition checks if one of the workflow children instances
(instantiated using the CreateWorkflowInstance or ForkWorkflowInstance
activity classes) is in state 'FAILURE'.
