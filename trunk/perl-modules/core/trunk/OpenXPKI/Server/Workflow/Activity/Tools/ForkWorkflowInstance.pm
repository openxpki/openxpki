# OpenXPKI::Server::Workflow::Activity::Tools::ForkWorkflowInstance.pm
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::ForkWorkflowInstance;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use POSIX qw(:signal_h :errno_h :sys_wait_h);

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Server::Session::Mock;

use IPC::ShareLite;
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
        if (!defined $role) {
            $role = CTX('session')->get_role();
            ##! 16: 'no (elevated) role configured, using session role: ' . $role
        }
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
        if (! scalar %{$params}) { 
            $params = $context->param();
        }
        $params->{'workflow_parent_id'} = $workflow->id();
        ##! 16: 'parent_id: ' . $params->{'workflow_parent_id'}
                                   
        $wf_info = $api->create_workflow_instance({
            WORKFLOW      => $wf_child_instance_type,
            FILTER_PARAMS => 1,
            PARAMS        => $params,
        });
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
        CTX('dbi_log')->disconnect();
        my $redo_count = 0;
        my $pid;
        $SIG{CHLD} = \&child_handler;

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
        elsif ($pid != 0) {
    	    ##! 16: 'parent here'
            ##! 16: 'parent: process group: ' . getpgrp(0)
            # we have forked successfully and have nothing to do any more
            # except for getting a new database handle
            CTX('dbi_log')->new_dbh();
            ##! 16: 'new parent dbi_log dbh'
            CTX('dbi_workflow')->new_dbh();
            ##! 16: 'new parent dbi_workflow dbh'
            CTX('dbi_backend')->new_dbh();
            ##! 16: 'new parent dbi_backend dbh'
            CTX('dbi_log')->connect();
            CTX('dbi_workflow')->connect();
            CTX('dbi_backend')->connect();
            # get new database handles
            ##! 16: 'parent: DB handles reconnected'
            OpenXPKI::Server::Context::setcontext({
                'session' => $old_session,
                'force' => 1,
            }); 
            ##! 16: 'old session restored, role: ' . CTX('session')->get_role()

            # TODO - figure out if the key is OK
            ##! 16: 'create (if necessary) new shared memory with key ' . $PID
            my $share = new IPC::ShareLite( -key     => $PID,
                                            -create  => 'yes',
                                            -destroy => 'no' );
            if (! defined $share) {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_FORKWORKFLOWINSTANCE_SHARED_MEMORY_NOT_CREATED',
                    params  => {
                        ERROR => $!,
                    },
                );
            }
            $share->lock();
            my $shared_content = $share->fetch();
            ##! 16: 'shared content: ' . $shared_content
            my $pids = {};
            if ($shared_content) {
                $pids = $serializer->deserialize($shared_content);
            }
            ##! 16: 'pids: ' . Dumper $pids
            ##! 64: 'parent workflow id: ' . $workflow->id()
            $pids->{$workflow->id()}->{$pid} = 1;
            ##! 16: 'new pids: ' . Dumper $pids

            $share->store($serializer->serialize($pids));
            $share->unlock();
        }
        else {
    	    ##! 16: 'child here'
            CTX('dbi_log')->new_dbh();
            ##! 16: 'new child dbi_log dbh'
            CTX('dbi_workflow')->new_dbh();
            ##! 16: 'new child dbi_workflow dbh'
            CTX('dbi_backend')->new_dbh();
            ##! 16: 'new child dbi_backend dbh'
            CTX('dbi_log')->connect();
            CTX('dbi_workflow')->connect();
            CTX('dbi_backend')->connect();
            ##! 16: 'child: DB handles reconnected'
            ##! 16: 'child dbi_workflow: ' . Dumper CTX('dbi_workflow')

            # save parent PID, because we will need it to reference
            # the correct IPC share later on. This will not work
            # with getppid if the parent dies in the meantime and
            # the child becomes a child of 1 (init).
            $OpenXPKI::Server::Context::who_forked_me{$workflow->id()} = [ getppid(), $PID ];

            ### we work in the background, so we don't need/want to
            ### communicate with anyone -> close the socket file
            ### note that if we don't, the child waits for a communication
            ### timeout in the Default service.
            my $socket_file = $self->get_xpath(
                XPATH     => [ 'common', 'server', 'socket_file' ],
                COUNTER   => [ 0       , 0       , 0            ],
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

sub child_handler {
    ##! 16: 'accessing shared mem with key ' . $PID
    my $share=0;
    eval {
        $share = new IPC::ShareLite( -key     => $PID,
                                    -create  => 'no',
                                    -destroy => 'no' );
    };
    if ($EVAL_ERROR){
        undef $share;
    };
    if (defined $share) {
        my $pid = waitpid(-1, &WNOHANG);
        ##! 16: 'pid: ' . $pid
        
        my $serializer = OpenXPKI::Serialization::Simple->new();
        # share might not be defined because it the child_handler
        # might be called from open or system after the share
        # has already been destroyed
        my $shared_content = $share->fetch();
        ##! 16: 'shared content: ' . $shared_content
        my $pids = {};
        if ($shared_content) {
            $pids = $serializer->deserialize($shared_content);
        }
        ##! 16: 'pids: ' . Dumper $pids
        # this should not be necessary, because the deletion is
        # supposed to take place in the CheckForkedWorkflowChildren
        # condition - this is only here to free shared memory in
        # case something goes wrong ...
        if (WIFEXITED($?)) {
            ##! 16: 'exited'
            foreach my $key (keys %{ $pids }) {
                if (exists $pids->{$key}->{$pid}) {
                    delete $pids->{$key}->{$pid};
                }
            }
            foreach my $key (keys %{ $pids}) {
                if (scalar keys %{ $pids->{$key} } == 0) {
                    delete $pids->{$key};
                }
            }
        }
        ##! 16: 'new pids: ' . Dumper $pids
        if (scalar keys %{ $pids } == 0) {
            # we are done, destroy shared memory
            $share = new IPC::ShareLite( -key     => $PID,
                                         -create  => 'no',
                                         -destroy => 'yes',
            );
            undef $share;
        }
        else {
            $share->store(OpenXPKI::Serialization::Simple->new()->serialize($pids));
        }
    }
    $SIG{'CHLD'} = \&child_handler;
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

When creating a new forked workflow, the activity adds an entry in
a shared memory segment indexed using the parent PID. This allows
to figure out which children are still running.
