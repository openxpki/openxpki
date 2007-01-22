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
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Server::Session::Mock;

use Data::Dumper;

sub execute {
    my $self     = shift;
    my $workflow = shift;
    my $wf_child_instance_type = shift; # if called from another
    my $params   = shift;               # activity class
    my $role; # the role to run the forked workflow in
    if (exists $params->{'role'}) {
        $role = $params->{'role'};
        ##! 16: 'called from activity class, role = ' . $role
    }
    else {
        $role = $self->param('role');
        ##! 16: 'called directly, role = ' . $role
    }
    my $old_session = CTX('session');
    

    ## get needed information
    my $context = $workflow->context();
    if (!defined $wf_child_instance_type) { # 'normal', retrieve from
                                            # configuration
        $wf_child_instance_type = $self->param('workflow_type');
    }
    my $api                    = CTX('api');
    my $serializer             = OpenXPKI::Serialization::Simple->new();

    ##! 16: 'context: ' . Dumper($context->param())
    ## create new workflow

    ##! 16: 'params: ' . Dumper($params)

    # this elevates the context of the currently logged in user!
    # this is reset to the old session immediately after
    # forking
    my $fake_session = OpenXPKI::Server::Session::Mock->new({
            SESSION => CTX('session'),
    });
    ##! 16: 'fake session created'
    $fake_session->set_role($role);
    OpenXPKI::Server::Context::setcontext({
        'session' => $fake_session,
        'force'   => 1,
    }); 
    my $wf_info;
    eval {
    ##! 16: 'fake session role set, role: ' . CTX('session')->get_role()
        if (defined $params) { # we are called from within another activity
                               # class, use the params passed
            $wf_info = $api->create_workflow_instance({
                WORKFLOW      => $wf_child_instance_type,
                FILTER_PARAMS => 1,
                PARAMS        => $params,
            });
        }
        else { # normal behaviour, copy params from parent context
            $wf_info = $api->create_workflow_instance({
                WORKFLOW      => $wf_child_instance_type,
                FILTER_PARAMS => 1,
                PARAMS        => $context->param(),
            });
        }
        my $wf_child_instance_id = $wf_info->{WORKFLOW}->{ID};
        if (!defined $wf_child_instance_id) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_FORKWORKFLOWINSTANCE_CHILD_INSTANCE_ID_UNDEFINED',
            );
        }
    
        my $wf_child_info_ref = {
            'ID'   => $wf_child_instance_id,
            'TYPE' => $wf_child_instance_type,
        };
        ##! 16: 'wf_child_info_ref: ' . Dumper $wf_child_info_ref
    
        # fetch wf_child_instances from workflow context
        # and add $wf_child_info_ref
        my @wf_children;
        my $wf_children_instances = $context->param('wf_children_instances');
        if (defined $wf_children_instances) {
            @wf_children = @{$serializer->deserialize($wf_children_instances)};
        }
        push @wf_children, $wf_child_info_ref;
        ##! 16: '@wf_children: ' . Dumper \@wf_children
        
        $context->param(
            'wf_children_instances'   => $serializer->serialize(\@wf_children),
        );
    
        ##! 16: 'child workflow created, id: ' . $wf_child_info_ref->{ID}

        # disconnect DB handles as they can not be forked connected
        # a new database handle is created in the child workflow
        CTX('dbi_workflow')->disconnect();
        CTX('dbi_backend')->disconnect();
        my $redo_count = 0;
        my $pid;
        $SIG{CHLD} = 'IGNORE'; # avoids zombies, TODO: research on
                               # which systems this actually works
                               # Martin suggests to set up a handler for
                               # SIGCHLD that does waitpid ...
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
            # except for getting a new database handle
            CTX('dbi_workflow')->new_dbh();
            ##! 16: 'new parent dbi_workflow dbh'
            CTX('dbi_backend')->new_dbh();
            ##! 16: 'new parent dbi_backend dbh'
            CTX('dbi_workflow')->connect();
            CTX('dbi_backend')->connect();
            # get new database handles
            ##! 16: 'parent: DB handles reconnected'
            OpenXPKI::Server::Context::setcontext({
                'session' => $old_session,
                'force' => 1,
            }); 
            ##! 16: 'old session restored, role: ' . CTX('session')->get_role()
            CTX('log')->re_init();
            ##! 16: 'child: log re-init done'
        }
        else {
    	    ##! 16: 'child here'
            CTX('dbi_workflow')->new_dbh();
            ##! 16: 'new child dbi_workflow dbh'
            CTX('dbi_backend')->new_dbh();
            ##! 16: 'new child dbi_backend dbh'
            CTX('dbi_workflow')->connect();
            CTX('dbi_backend')->connect();
            ##! 16: 'child: DB handles reconnected'
            ##! 16: 'child dbi_workflow: ' . Dumper CTX('dbi_workflow')
    
            CTX('log')->re_init();
            ##! 16: 'child: log re-init done'
            
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
    
            if ($wf_info->{WORKFLOW}->{STATE} ne 'WAITING_FOR_START') {
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
                ##! 16: 'getting activities for ' . $wf_child_instance_type . '/' . $wf_child_instance_id
                my $activities = $api->get_workflow_activities({
                    WORKFLOW => $wf_child_instance_type,
                    ID       => $wf_child_instance_id,
                });
                ##! 16: 'activities: ' . Dumper($activities)
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
            if ($EVAL_ERROR || $state eq 'WAITING_FOR_START') {
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
    };
    if ($EVAL_ERROR) {
        # something wrent wrong, IMMEDIATELY reset elevated session
        OpenXPKI::Server::Context::setcontext({
            'session' => $old_session,
            'force' => 1,
        }); 
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_FORKWORKFLOWINSTANCE_ERROR_FORKING',
            params => {
                'EVAL_ERROR' => $EVAL_ERROR,
            },
        );
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

Alternatively, this activity may be creatively used in another
activity class, for example when you want to fork several
workflow instances. This requires that you pass on the workflow
type and the parameters as parameters to the execute method.

Example:

my $fork_wf_instance = OpenXPKI::Server::Workflow::Activity::Tools->new();
$fork_wf_instance->execute(
    $workflow,
    'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_ISSUANCE',
    $params
);
