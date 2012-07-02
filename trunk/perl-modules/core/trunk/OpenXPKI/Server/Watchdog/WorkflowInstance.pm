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

        eval { $self->__wake_up_workflow($db_result); };
        if ( my $exc = OpenXPKI::Exception->caught() ) {

            OpenXPKI::Exception->throw(
                message  => "'I18N_OPENXPKI_SERVER_WATCHDOG_WAKE_UP_WORKFLOW_FAILED",
                children => [$exc],
            );

        } elsif ($EVAL_ERROR) {
            OpenXPKI::Exception->throw(
                message => "'I18N_OPENXPKI_SERVER_WATCHDOG_WAKE_UP_WORKFLOW_FAILED",
                params  => { EVAL_ERROR => $EVAL_ERROR, },
            );
        }
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
    # get possible activities and try to execute if there is
    # only one available (same as "autorun" does, only
    # manually)
    ##! 16: 'getting activities for ' . $wf_type . '/' . $wf_id
    my $activities = $api->get_workflow_activities(
        {
            WORKFLOW => $wf_type,
            ID       => $wf_id,
        }
    );
    ##! 16: 'activities: ' . Dumper($activities)
    my $state;
    if ( scalar @{$activities} == 0 ) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WATCHDOG_FORK_WORKFLOW_NO_ACTIVITIES_AVAILABLE',
            params  => { WF_ID => $wf_id, WF_INFO => $wf_info }
        );
    } elsif ( scalar @{$activities} > 1 ) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WATCHDOG_FORK_WORKFLOW_MORE_THAN_ONE_ACTIVITY_AVAILABLE',
            params  => { WF_ID => $wf_id, WF_INFO => $wf_info }
        );
    } else {
        $state = $api->execute_workflow_activity(
            {
                WORKFLOW => $wf_type,
                ID       => $wf_id,
                ACTIVITY => $activities->[0],
            }
        );
        ##! 16: 'new state: ' . $state
    }

}

sub __check_session{
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
                   DIRECTORY => CTX('xml_config')->get_xpath(XPATH => "common/server/session_dir"),
                   LIFETIME  => CTX('xml_config')->get_xpath(XPATH => "common/server/session_lifetime"),
   });
   OpenXPKI::Server::Context::setcontext({'session' => $session});
   ##! 4: sprintf(" session %d created" , $session->get_id()) 
}

1;
