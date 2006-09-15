# OpenXPKI::Server::Workflow::Activity::Tools::ForkWorkflowInstance.pm
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision: 320 $

package OpenXPKI::Server::Workflow::Activity::Tools::ForkWorkflowInstance;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug 'OpenXPKI::Server::Workflow::Activity::Tools::ForkWorkflowInstance';

use Data::Dumper;

sub execute {
    my $self = shift;
    my $workflow = shift;

    ## get needed informations
    my $context                = $workflow->context();
    my $wf_child_instance_type = $self->param('workflow_type');
    my $api                    = CTX('api');

    ##! 16: 'context: ' . Dumper($context->param())
    ## create new workflow
    $api = $api->get_api('Workflow');
    my $wf_info = $api->create_workflow_instance({
            WORKFLOW      => $wf_child_instance_type,
            FILTER_PARAMS => 1,
            PARAMS        => $context->param(),
    });

    my $wf_child_instance_id   = $wf_info->{WORKFLOW}->{ID};
    # TODO: use serialized array for the case where we have
    # more than one child?
    $context->param(
        'wf_child_instance_id'   => $wf_child_instance_id,
    );
    $context->param(
        'wf_child_instance_type' => $wf_child_instance_type,
    );
    ##! 16: 'child workflow created, id: ' . $wf_child_instance_id
    # TODO: can we force this to be inserted into the DB _right now_?

    # disconnect DB handles as they can not be forked connected
    CTX('dbi_workflow')->disconnect();
    CTX('dbi_backend')->disconnect();

    ##! 16: 'DB handles disconnected'
    my $redo_count = 0;
    my $pid;
    $SIG{CHLD} = 'IGNORE'; # avoids zombies, TODO: research on
                           # which systems this actually works
    while (!defined $pid && $redo_count < 5) {
        ##! 32: 'trying to fork'
	$pid = fork();
        ##! 32: 'pid: ' . $pid
	if (! defined $pid) {
	    if ($!{EAGAIN}) {
		# recoverable fork error
		sleep 2;
		$redo_count++;
	    }
            else {
	        # other fork error
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_FORKWORKFLOWINSTANCE_FORK_FAILED',
                );
            }
	}
    }
    if (!defined $pid) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_FORKWORKFLOWINSTANCE_FORK_FAILED',
        );
    } 
    elsif ($pid == 0) {
	##! 16: 'parent here'
        ##! 16: 'parent: process group: ' . getpgrp(0)
        # we have forked successfully and have nothing to do any more
        # except for connecting the DB handles again
        CTX('dbi_workflow')->connect();
        CTX('dbi_backend')->connect();
        ##! 16: 'parent: DB handles reconnected'
    }
    else {
	##! 16: 'child here'
        CTX('dbi_workflow')->connect();
        CTX('dbi_backend')->connect();
        ##! 16: 'child: DB handles reconnected'

        ### we work in the background, so we don't need/want to
        ### communicate with anyone -> close the socket file
        ### note that if we don't, the child waits for a communication
        ### timeout in the Default service.
        my $socket_file = CTX('xml_config')->get_xpath(
            XPATH   => [ 'common', 'server', 'socket_file' ],
            COUNTER => [ 0       , 0       , 0            ],
        );
        ##! 16: 'socket file: ' . $socket_file
        close($socket_file);

        ### get child workflow and "manually autostart".
        my $wf_info = $api->get_workflow_info({
            WORKFLOW => $wf_child_instance_type,
            ID       => $wf_child_instance_id,
        });
        ##! 16: 'child: wf_info fetched'
        ##! 16: Dumper($wf_info)

        # append fork info to process name
        $0 .= ' (forked workflow instance ' . $wf_child_instance_id . ')';

        if ($wf_info->{WORKFLOW}->{STATE} ne 'I18N_OPENXPKI_WF_STATE_WAITING_FOR_START') {
            OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_FORKWORKFLOWINSTANCE_INSTANCE_NOT_IN_STATE_WAITING_FOR_START',
                    params  => {
                        'STATE' => $wf_info->{WORKFLOW}->{STATE},
                    },
            );
        }
        my $state;
        eval {
            # get possible activities and try to execute if there is
            # only one available (same as "autorun" does, only
            # manually)
            my $activities = $api->get_workflow_activities({
                WORKFLOW => $wf_child_instance_type,
                ID       => $wf_child_instance_id,
            });
            if (scalar @{$activities} == 0) {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_FORKWORKFLOWINSTANCE_NO_ACTIVITIES_AVAILABLE',
                );
            }
            elsif (scalar @{$activities} > 1) {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_FORKWORKFLOWINSTANCE_MORE_THAN_ONE_ACTIVITY_AVAILABLE',
                );
            }
            else {
                $state = $api->execute_workflow_activity({
                    WORKFLOW => $wf_child_instance_type,
                    ID       => $wf_child_instance_id,
                    ACTIVITY => $activities->[0],
                });
            }
        };
        if ($EVAL_ERROR || $state eq 'I18N_OPENXPKI_WF_STATE_WAITING_FOR_START') {
            OpenXPKI::Exception->throw (
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_FORKWORKFLOWINSTANCE_ERROR_EXECUTING_ACTIVITY',
                params  => {
                    'EVAL_ERROR' => $EVAL_ERROR,
                    'STATE'      => $state,
                },
            );
        } 
        ##! 16: 'child: process group: ' . getpgrp(0)
        ##! 16: 'child: successfully started WF activity, exiting'
        exit(0);
    }
    return;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::ForkWorkflowInstance

=head1 Description

This class creates a new instance of a workflow from with a parent workflow.
The child workflow is running independent and asynchronously from the
parent. This is useful if you want to start a (potentially) long-running
workflow. You can always see what state it is in by looking at your
context parameters wf_child_instance_type and _id and retrieving the
workflow info using the Server Workflow API. As with CreateWorkflowInstance,
the type is specified in the activity parameter workflow_type.

Example:
  <action name="I18N_OPENXPKI_WF_ACTION_SPAWN_CERT_ISSUANCE"
	  class="OpenXPKI::Server::Workflow::Activity::Tools::ForkWorkfowInstance"
	  workflow_type="I18N_OPENXPKI_WF_TYPE_CERTIFICATE_ISSUANCE">
  </action>
