## OpenXPKI::Server::Watchdog::WorkflowInstance.pm
##
## Written 2012 by Dieter Siebeck for the OpenXPKI project
## Copyright (C) 2012-20xx by The OpenXPKI Project

package OpenXPKI::Server::Watchdog::WorkflowInstance;
use strict;
use English;
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::DateTime;

use Data::Dumper;

sub new {
    my $that  = shift;
    my $class = ref($that) || $that;
    my $self  = {};
    bless $self, $class;
    return $self;
}

sub run {
    my $self = shift;

    my ($db_result) = @_;

    my $wf_id = $db_result->{WORKFLOW_SERIAL};
    unless ($wf_id) {
        OpenXPKI::Exception->throw( message => 'I18N_OPENXPKI_SERVER_WATCHDOG_FORK_WORKFLOW_NO_ID_GIVEN' );
    }

    
    my $pid;
    my $redo_count = 0;

    $SIG{'CHLD'} = sub { wait; };
    while ( !defined $pid && $redo_count < 5 ) {
        ##! 16: 'trying to fork'
        $pid = fork();
        ##! 16: 'pid: ' . $pid
        if ( !defined $pid ) {
            if ( $!{EAGAIN} ) {

                # recoverable fork error
                sleep 2;
                $redo_count++;
            } else {

                # other fork error
                OpenXPKI::Exception->throw( message => 'I18N_OPENXPKI_SERVER_WATCHDOG_FORK_WORKFLOW_EXECUTION_FAILED', );
            }
        }
    }
    if ( !defined $pid ) {
        OpenXPKI::Exception->throw( message => 'I18N_OPENXPKI_SERVER_WATCHDOG_FORK_WORKFLOW_EXECUTION_FAILED', );
    } elsif ( $pid != 0 ) {
        ##! 16: 'fork_workflow_execution: parent here'
        ##! 16: 'parent: process group: ' . getpgrp(0)
        # we have forked successfully and have nothing to do any more except for getting a new database handle
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
       
    } else {
        
        # We need to unset the child reaper (waitpid) as the universal waitpid 
        # causes problems with Proc::SafeExec  
        $SIG{CHLD} = 'DEFAULT';
        
        ##! 16: 'fork_workflow_execution: child here'
        CTX('dbi_log')->new_dbh();
        CTX('dbi_workflow')->new_dbh();
        CTX('dbi_backend')->new_dbh();
        CTX('dbi_log')->connect();
        CTX('dbi_workflow')->connect();
        CTX('dbi_backend')->connect();
        ##! 16: 'child: DB handles reconnected'
        
        # append fork info to process name
        $0 .= sprintf( ' watchdog reinstantiating %d', $wf_id );
        
        # the wf instance child processs should ALWAYS exit properly and not let bubble up his exceptions up to Watchdog::_scan_for_paused_workflows
        eval { $self->__wake_up_workflow($db_result); };
        my $error_msg;
        if ( my $exc = OpenXPKI::Exception->caught() ) {

            $exc->show_trace(1);
            $error_msg = "OpenXPKI::Server::Watchdog::WorkflowInstance: Exception caught while executing _wake_up_workflow: $exc";

        } elsif ($EVAL_ERROR) {
            $error_msg = "OpenXPKI::Server::Watchdog::WorkflowInstance: Fatal error while executing _wake_up_workflow:" . $EVAL_ERROR;
        }
        if ($error_msg) {
            CTX('log')->log(
                MESSAGE  => $error_msg,
                PRIORITY => "fatal",
                FACILITY => "workflow"
            );
        }
        #ALWAYS exit  child process
        exit;
    }
}

sub __wake_up_workflow {
    my $self = shift;
    my ($db_result) = @_;
    
    $self->__check_session();
    
    CTX('dbi_workflow')->commit();
    
    

    my $wf_id   = $db_result->{WORKFLOW_SERIAL};
    my $wf_type = $db_result->{WORKFLOW_TYPE};+
    my $pki_realm = $db_result->{PKI_REALM};
    my $session_info = $db_result->{WORKFLOW_SESSION};
    unless ($wf_id) {
        OpenXPKI::Exception->throw( message => 'I18N_OPENXPKI_SERVER_WATCHDOG_FORK_WORKFLOW_NO_ID_GIVEN' );
    }
    unless ($wf_type) {
        OpenXPKI::Exception->throw( message => 'I18N_OPENXPKI_SERVER_WATCHDOG_FORK_WORKFLOW_NO_WFTYPE_GIVEN' );
    }
    unless ($pki_realm) {
        OpenXPKI::Exception->throw( message => 'I18N_OPENXPKI_SERVER_WATCHDOG_FORK_WORKFLOW_NO_PKI_REALM_GIVEN' );
    }
    unless ($session_info) {
        OpenXPKI::Exception->throw( message => 'I18N_OPENXPKI_SERVER_WATCHDOG_FORK_WORKFLOW_NO_SESSION_INFO_GIVEN' );
    }
    
    CTX('session')->set_pki_realm($pki_realm);
    CTX('session')->import_serialized_info($session_info);
    

    my $api = CTX('api');
    ### get workflow and "manually autostart".
    my $wf_info = $api->get_workflow_info(
        {
            WORKFLOW => $wf_type,
            ID       => $wf_id,
        }
    );
    ##! 16: 'child: wf_info fetched'
    ##! 16: Dumper($wf_info)
    
    my $wf_history = $api->get_workflow_history({ID => $wf_id});
    ##! 80: Dumper($wf_history)
    
    unless(@$wf_history){
        OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WATCHDOG_FORK_WORKFLOW_NO_HISTORY_AVAILABLE',
                params  => { WF_ID => $wf_id, WF_INFO => $wf_info }
            );
    }
    
    my $last_history = pop(@$wf_history);
    ##! 16: 'last history '.Dumper($last_history)
    my $last_action = $last_history->{WORKFLOW_ACTION};
    ##! 16: 'last action '.$last_action
    unless($last_action){
        OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WATCHDOG_FORK_WORKFLOW_NO_LAST_ACTIVITY',
                params  => { WF_ID => $wf_id, WF_INFO => $wf_info }
            );
    }
    my $new_wf_info = $api->execute_workflow_activity(
        {
            WORKFLOW => $wf_type,
            ID       => $wf_id,
            ACTIVITY => $last_action,
        }
    );
    ##! 16: 'new wf info: ' .Dumper( $new_wf_info )
    
    
}

sub __check_session {
    #my $self = shift;
    my $session;
    eval{
       $session = CTX('session');
    };
    if($session ){
        return;
    }
    ##! 4: "create new session"
    $session = OpenXPKI::Server::Session->new({
                   DIRECTORY => CTX('config')->get("system.server.session.directory"),
                   LIFETIME  => CTX('config')->get("system.server.session.lifetime"),
   });
   OpenXPKI::Server::Context::setcontext({'session' => $session});
   ##! 4: sprintf(" session %s created" , $session->get_id()) 
}

1;

=head1 NAME

The workflow instance thread 

=head1 DESCRIPTION

This class is responsible for waking up paused workflows. Its run-method is called from OpenXPKI::Server::Watchdog and 
recieves the db resultset as only argument. Immediately a child process will be created via fork() and _wake_up_workflow is called within the child.
 
_wake_up_workflow reads all necessary infos from the resultset (representing one row from workflow table)
the serialized session infos are imported in the current (watchdog's) session, so that the wqorkflow is executed within its original environment.

the last performed action is retrieved from workflow history, than executed again (via OpenXPKI::Server::API::Workflow)


1;
