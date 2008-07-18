use Test::More tests => 1;
use English;

use strict;
use warnings;

use OpenXPKI::Client;

our %config;
require 't/common.pl';

my $debug = $config{debug};

diag("SCEP Client Test: approving the SCEP request");
my $sscep = 'sscep';
SKIP: {
    if (system("$sscep >/dev/null 2>&1") != 0) {
	skip "sscep binary not installed.", 1;
    }
    if (! (`$config{openssl} version` =~ m{\A OpenSSL\ 0\.9\.8 }xms)) {
        skip "OpenSSL 0.9.8 not available.", 1;
    }
    
    # we need to backup the sqlite db, as the approval might fail
    # because of DB issues. We retry up to 10 times so that we don't
    # fail for this reason (which is no problem with a non-SQlite-DB)
    `mkdir t/instance/sqlite_backup`;
    `cp t/instance/var/openxpki/sqlite* t/instance/sqlite_backup`;

    my $success;

    APPROVE:
    for (my $i = 0; $i < 10; $i++) {
        my $message = "Approval try #" . ($i+1);
        diag($message);
        my $stderr = "2>/dev/null";
        # hangs prove, see OpenXPKI::Tests
        #if ($debug) {
        #    $stderr = "";
        #}
        if ($i > 0) {
            # restore sqlite backup & restart server
            `openxpkictl --config $config{config_file} stop $stderr`;
            `cp t/instance/sqlite_backup/* t/instance/var/openxpki/`;
            my $args = "--debug 150" if ($debug);
            `openxpkictl --config $config{config_file} $args start $stderr`;
        }

        my $client = OpenXPKI::Client->new({
            SOCKETFILE => $config{'socket_file'},
        });
        $client->init_session();
    
        #my $msg = $client->collect();
    
        my $msg = $client->send_receive_service_msg(
            'GET_AUTHENTICATION_STACK',
            {
                'AUTHENTICATION_STACK' => 'External Dynamic',
            },
        );
        $msg = $client->send_receive_service_msg(
            'GET_PASSWD_LOGIN',
            {
                'LOGIN'  => 'raop',
                'PASSWD' => 'RA Operator',
            },
        );
        if (exists $msg->{'SERVICE_MSG'} &&
                   $msg->{'SERVICE_MSG'} eq 'SERVICE_READY') {
            if ($debug) {
                print STDERR "logged in ...\n";
            }
        }
        else {
            next APPROVE;
        }
        
        $msg = $client->send_receive_command_msg(
            'search_workflow_instances',
            {
                TYPE    => 'I18N_OPENXPKI_WF_TYPE_SCEP_REQUEST',
                CONTEXT => [
                    {
                        KEY   => 'cert_subject',
                        VALUE => '%Test%',
                    },
                ],
            }
        );
        
        if (ref $msg->{'PARAMS'} eq 'ARRAY' &&
            exists $msg->{'PARAMS'}->[0]->{'WORKFLOW.WORKFLOW_STATE'} &&
            $msg->{'PARAMS'}->[0]->{'WORKFLOW.WORKFLOW_STATE'} eq 'PENDING') {
            if ($debug) {
                print STDERR "pending ...\n";
            }
        }
        else {
            next APPROVE;
        }
        my $wf_id = $msg->{'PARAMS'}->[0]->{'WORKFLOW.WORKFLOW_SERIAL'};
        
        $msg = $client->send_receive_command_msg(
            'execute_workflow_activity',
            {
                'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_SCEP_REQUEST',
                'ID'       => $wf_id,
                'ACTIVITY' =>  'I18N_OPENXPKI_WF_ACTION_APPROVE_CSR',
            },
        );
        
        if (exists $msg->{'PARAMS'}->{'WORKFLOW'}->{'STATE'}  &&
            $msg->{'PARAMS'}->{'WORKFLOW'}->{'STATE'} eq 'APPROVAL') {
            if ($debug) {
                print STDERR "approved ...\n";
            }
        }
        else {
            next APPROVE;
        }
        
        $msg = $client->send_receive_command_msg(
            'execute_workflow_activity',
            {
                'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_SCEP_REQUEST',
                'ID'       => $wf_id,
                'ACTIVITY' =>  'I18N_OPENXPKI_WF_ACTION_PERSIST_CSR',
            },
        );
        
        $msg = $client->send_receive_command_msg(
            'get_workflow_info',
            {
                'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_SCEP_REQUEST',
                'ID'       => $wf_id,
            },
        );
        if (exists $msg->{'PARAMS'}->{'WORKFLOW'}->{'STATE'} &&
            ($msg->{'PARAMS'}->{'WORKFLOW'}->{'STATE'} eq 'SUCCESS'
          || $msg->{'PARAMS'}->{'WORKFLOW'}->{'STATE'} eq 'WAITING_FOR_CHILD')) {
            $success = 1;
            if ($debug) {
                print STDERR "success ...\n";
            }
            last APPROVE;
        }
    }
    ok($success);
}
