# OpenXPKI::Server::Workflow::Condition::IsWorkflowChildInstanceFinished
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision$
package OpenXPKI::Server::Workflow::Condition::IsWorkflowChildInstanceFinished;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug 'OpenXPKI::Server::API::Workflow::Condition::IsWorkflowChildInstanceFinished';
use English;

use Data::Dumper;

sub _init
{
    my ( $self, $params ) = @_;

    return 1;
}

sub evaluate {
    ##! 16: 'start'
    my ( $self, $workflow ) = @_;

    my $negate = 0;
    if ($self->name() eq 'wf_child_instance_not_finished') {
        $negate = 1;
    }
    my $context  = $workflow->context();
    ##! 16: 'context: ' . Dumper($context)

    my $child_id   = $context->param('wf_child_instance_id');
    my $child_type = $context->param('wf_child_instance_type');

    ##! 16: 'child: ' . $child_id
    
    if (! defined $child_id || ! defined $child_type) {
        ##! 16: 'child not found!'
        my $errors = [[ 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_ISWORKFLOWCHILDINSTANCEFINISHED_NO_WF_CHILD_INSTANCE_ID_OR_TYPE_FOUND' ]];
        $context->param('__error' => $errors);
        condition_error($errors->[0]);
    }
    
    my $api = CTX('api')->get_api('Workflow');

    my $child_info = $api->get_workflow_info({
        ID       => $child_id,
        WORKFLOW => $child_type,
    });
    ##! 16: 'child state: ' . $child_info->{WORKFLOW}->{STATE}

    if ($child_info->{WORKFLOW}->{STATE} eq 'FINISHED') {
        ##! 16: 'child is finished'
        if ($negate == 1) {
            condition_error('I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_ISWORKFLOWCHILDINSTANCEFINISHED_CHILD_FINISHED');
        }
        else {
            return 1; # child is finished
        }
    }
    else { # there is more then one entry left
        ##! 16: 'child is not finished'
        if ($negate == 1) {
            return 1; # child not finished is true
        }
        else {
            condition_error('I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_ISWORKFLOWCHILDINSTANCEFINISHED_CHILD_NOT_FINISHED');
        } 
    }
    return;
    ##! 16: 'end'
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::IsWorkflowChildInstanceFinished

=head1 SYNOPSIS

<action name="do_something">
  <condition name="workflow_child_instance_finished"
             class="OpenXPKI::Server::Workflow::Condition::IsWorkflowChildInstanceFinished">
  </condition>
</action>

=head1 DESCRIPTION

The condition checks if the workflow child instance (instantiated using
the CreateWorkflowInstance activity class) is in state 'FINISHED'
already or whether it is still doing something / waiting for input.
If the magic condition name 'wf_child_instance_not_finished' is used,
it returns the opposite.

