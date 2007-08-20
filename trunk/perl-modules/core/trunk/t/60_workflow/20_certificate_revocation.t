use strict;
use warnings;
use English;
use Test::More qw( no_plan );

use OpenXPKI::Tests;
use OpenXPKI::Client;
use Data::Dumper;
use OpenXPKI::Serialization::Simple;

# this is needed because we need to manually output the number of tests run
Test::More->builder()->no_header(1);
my $OUTPUT_AUTOFLUSH = 1;
my $NUMBER_OF_TESTS  = 22;

# do not use test numbers because forking destroys all order
Test::More->builder()->use_numbers(0);

diag("Certificate revocation request workflow\n");
print "1..$NUMBER_OF_TESTS\n";

# reuse the already deployed server
my $instancedir = 't/60_workflow/test_instance';
my $socketfile = $instancedir . '/var/openxpki/openxpki.socket';
my $pidfile    = $instancedir . '/var/openxpki/openxpki.pid';

# Fork server, connect to it, test config IDs, create workflow instance
my $redo_count = 0;
my $pid;
FORK:
do {
    $pid = fork();
    if (! defined $pid) {
        if ($!{EAGAIN}) {
            # recoverable fork error
            if ($redo_count > 5) {
                die "Forking failed";
            }
            sleep 5;
            $redo_count++;
            redo FORK;
        }

        # other fork error
        die "Forking failed: $ERRNO";
        last FORK;
    }
} until defined $pid;

if ($pid) {
    local $SIG{'CHLD'} = 'IGNORE';
    Test::More->builder()->use_numbers(0);
    # this is the parent
    
    local $SIG{'ALRM'} = sub { die "Timeout ..." };
    alarm 300;
    start_test_server({
          FOREGROUND => 1,
          DIRECTORY  => $instancedir,
    });
    alarm 0;
}
else {
    Test::More->builder()->use_numbers(0);
    # child here

  CHECK_SOCKET:
    foreach my $i (1..60) {
        if (-e $socketfile) {
            last CHECK_SOCKET;
        }
        else {
            sleep 1;
        }
    }
    ok(-e $pidfile, "PID file exists");
    ok(-e $socketfile, "Socketfile exists");
    my $client = OpenXPKI::Client->new({
        SOCKETFILE => $instancedir . '/var/openxpki/openxpki.socket',
    });
    ok(login({
        CLIENT   => $client,
        USER     => 'raop',
        PASSWORD => 'RA Operator',
      }), 'Logged in successfully');

    my $msg = $client->send_receive_command_msg(
        'search_cert',
        {
          'SUBJECT' => '%example.com%',
        },
    );
    ok(! is_error_response($msg), 'Certificate search');
    my $identifier = $msg->{PARAMS}->[0]->{'IDENTIFIER'};
    ok($identifier, 'Identifier present');

    # Invalid identifier

    $msg = $client->send_receive_command_msg(
        'create_workflow_instance',
        {
          'PARAMS' => {
                        'cert_identifier' => 'identifier',
                        'comment' => 'compromised!!11',
                        'invalidity_time' => time(),
                        'reason_code' => 'keyCompromise',
                      },
          'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_REVOCATION_REQUEST',
        },
    );
    ok(is_error_response($msg) &&
        $msg->{LIST}->[0]->{LABEL} eq 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_INVALIDITYTIME_CERTIFICATE_NOT_FOUND_IN_DB', 'Complains about incorrect identifier') or diag Dumper $msg;

    # Invalid time (too early)

    $msg = $client->send_receive_command_msg(
        'create_workflow_instance',
        {
          'PARAMS' => {
                        'cert_identifier' => $identifier,
                        'comment' => 'compromised!!11',
                        'invalidity_time' => 0,
                        'reason_code' => 'keyCompromise',
                      },
          'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_REVOCATION_REQUEST',
        },
    );

    ok(is_error_response($msg) &&
        $msg->{LIST}->[0]->{LABEL} eq 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_INVALIDITYTIME_BEFORE_CERT_NOTBEFORE', 'Complains about invalidity time (too early)') or diag Dumper $msg;

    # Invalid time (too late)

    $msg = $client->send_receive_command_msg(
        'create_workflow_instance',
        {
          'PARAMS' => {
                        'cert_identifier' => $identifier,
                        'comment' => 'compromised!!11',
                        'invalidity_time' => 1999999999,
                        'reason_code' => 'keyCompromise',
                      },
          'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_REVOCATION_REQUEST',
        },
    );

    ok(is_error_response($msg) &&
        $msg->{LIST}->[0]->{LABEL} eq 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_INVALIDITYTIME_AFTER_CERT_NOTAFTER', 'Complains about invalidity time (too late)') or diag Dumper $msg;

    # invalid reason code

    $msg = $client->send_receive_command_msg(
        'create_workflow_instance',
        {
          'PARAMS' => {
                        'cert_identifier' => $identifier,
                        'comment' => 'compromised!!11',
                        'invalidity_time' => time(),
                        'reason_code' => 'fjweiofwe',
                      },
          'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_REVOCATION_REQUEST',
        },
    );

    ok(is_error_response($msg) &&
        $msg->{LIST}->[0]->{LABEL} eq 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_REASON_CODE_INVALID', 'Complains about invalid reason code') or diag Dumper $msg;

    # Correct data with valid reason codes
    my @valid_reason_codes = (
        'certificateHold',
        'removeFromCRL',
        'unspecified',
        'keyCompromise',
        'CACompromise',
        'affiliationChanged',
        'superseded',
        'cessationOfOperation',
    );
    foreach my $reason_code (@valid_reason_codes) {
        $msg = $client->send_receive_command_msg(
            'create_workflow_instance',
            {
              'PARAMS' => {
                            'cert_identifier' => $identifier,
                            'comment' => 'compromised!!11',
                            'invalidity_time' => time(),
                            'reason_code' => $reason_code,
                          },
              'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_REVOCATION_REQUEST',
            },
        );
        ok(! is_error_response($msg), 'Successfully created CRR workflow with reason code ' . $reason_code);
    }
    my $wf_id = $msg->{PARAMS}->{WORKFLOW}->{ID};
    $msg = $client->send_receive_command_msg(
        'execute_workflow_activity',
        {
              'ACTIVITY' => 'approve_crr',
              'ID' => $wf_id,
              'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_REVOCATION_REQUEST',
        },
    ); 
    ok(! is_error_response($msg), 'Successfully approved') or diag Dumper $msg;
    is($msg->{PARAMS}->{WORKFLOW}->{STATE}, 'APPROVAL', 'Workflow in state APPROVAL');

    $msg = $client->send_receive_command_msg(
        'execute_workflow_activity',
        {
              'ACTIVITY' => 'revoke_certificate',
              'ID' => $wf_id,
              'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_REVOCATION_REQUEST',
        },
    ); 
    ok(! is_error_response($msg), 'Successfully revoked') or diag Dumper $msg;
    is($msg->{PARAMS}->{WORKFLOW}->{STATE}, 'SUCCESS', 'Workflow in state SUCCESS');

    # LOGOUT
    eval {
        $msg = $client->send_receive_service_msg('LOGOUT');
    };
    diag "Terminated connection";
    exit 0;
}
ok(1, 'Done'); # this is to make Test::Builder happy, which otherwise
               # believes we did not do any testing at all ... :-/
