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
my $NUMBER_OF_TESTS  = 19;

# do not use test numbers because forking destroys all order
Test::More->builder()->use_numbers(0);

diag("CSR with cert issuance workflow forking\n");
print "1..$NUMBER_OF_TESTS\n";

my $instancedir = 't/60_workflow/test_instance_cert_issuance';
my $socketfile = $instancedir . '/var/openxpki/openxpki.socket';
my $pidfile    = $instancedir . '/var/openxpki/openxpki.pid';

ok(deploy_test_server({
        DIRECTORY  => $instancedir,
    }), 'Test server deployed successfully');
ok(create_ca_cert({
        DIRECTORY => $instancedir,
    }), 'CA certificate created and installed successfully');

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
    Test::More->builder()->use_numbers(0);
    # this is the parent
    start_test_server({
        FOREGROUND => 1,
        DIRECTORY  => $instancedir,
    });
}
else {
    Test::More->builder()->use_numbers(0);
    # child here

  CHECK_PIDFILE:
    foreach my $i (1..60) {
        if (-e $pidfile) {
            last CHECK_PIDFILE;
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
        'create_workflow_instance',
        {
            WORKFLOW => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
            PARAMS   => {
                'cert_info' => "HASH\n0",
                'cert_profile' => 'I18N_OPENXPKI_PROFILE_TLS_SERVER',
                'cert_role' => 'Web Server',
                'cert_subject_alt_name_parts' => "HASH\n0",
                'cert_subject_parts' => "HASH\n94\n21\ncert_subject_hostname\nSCALAR\n27\nfully.qualified.example.com\n17\ncert_subject_port\nSCALAR\n0\n\n",
                'cert_subject_style' => 'tls_basic_style',
                'csr_type' => 'spkac',
                'spkac' => 'MIIBOjCBpDCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEA1Qwkd2oQ2Cds6b0+zT2qGUAFfTRRX5cRHAsbhjsw4PnPSgSJmbw7+9YerrKxfu/SqPjGSpm+yxx+skhb23hR3scGYX2WIbEsyALqkaNr4EYuB9VB7xZoNnolYYmjrR2YfmEpbPppUjnQgI9oGQHF1dh83QtQHGX4pJjonXvQ/I8CAwEAARYAMA0GCSqGSIb3DQEBBAUAA4GBAGdGhX9YgtcaWCHB9+TUdbEPuS5thC/Ox/AswcpE6gp31XTPWNQ0dl3RFq3fRDssvYgWJWeEp+03YpAf+GuW4yyEKiyMuXPlBfeMy9D9s2XZrr7f0R37w5ufFwZIr1dFO5M2K9vN5bFdBFs7xeJbVkPotMvW1Z3koQuHfhKe8rov',
            },
        },
    );
    ok(! is_error_response($msg), 'Successfully created CSR workflow instance');
    ok(exists $msg->{PARAMS}->{ACTIVITY}->{'I18N_OPENXPKI_WF_ACTION_APPROVE_CSR'}, 'Approve activity exists');
    my $wf_id = $msg->{PARAMS}->{WORKFLOW}->{ID} ;
    ok(defined $wf_id, 'Workflow ID exists');
    is($msg->{PARAMS}->{WORKFLOW}->{STATE}, 'PENDING', 'WF is in state PENDING');
    is($msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{'cert_subject'}, 'CN=fully.qualified.example.com,DC=Test Deployment,DC=OpenXPKI,DC=org', 'Correct cert subject');

    # Approve

    $msg = $client->send_receive_command_msg(
        'execute_workflow_activity',
        {
              'ACTIVITY' => 'I18N_OPENXPKI_WF_ACTION_APPROVE_CSR',
              'ID' => $wf_id,
              'PARAMS' => {
                          },
              'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
        },
    ); 
    ok(! is_error_response($msg), 'Successfully approved') or diag Dumper $msg;
    ok($msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{'approvals'}, 'Context has approvals');
    my @approvals = ();
    eval {
        @approvals = @{ OpenXPKI::Serialization::Simple->new()->deserialize(
            $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{'approvals'}) };
    };
    is(scalar @approvals, 1, 'One approval present');
    is($msg->{PARAMS}->{WORKFLOW}->{STATE}, 'APPROVAL', 'New state is APPROVAL');
    # Persist CSR. This automagically creates cert issuance workflows

    $msg = $client->send_receive_command_msg(
        'execute_workflow_activity',
        {
              'ACTIVITY' => 'I18N_OPENXPKI_WF_ACTION_PERSIST_CSR',
              'ID' => $wf_id,
              'PARAMS' => {
                          },
              'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
        },
    ); 
    ok(! is_error_response($msg), 'Successfully persisted CSR') or diag Dumper $msg;
    ok(
           ($msg->{PARAMS}->{WORKFLOW}->{STATE} eq 'CHECK_CHILD_FINISHED')
        || ($msg->{PARAMS}->{WORKFLOW}->{STATE} eq 'SUCCESS'),
        'State is CHECK_CHILD_FINISHED or SUCCESS'
    ) or diag Dumper $msg;

    $msg = $client->send_receive_command_msg(
        'search_workflow_instances',
        {
              'TYPE' => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_ISSUANCE',
        },
    ); 
    ok(! is_error_response($msg), 'search_workflow_instances') or diag Dumper $msg;
    is(scalar @{ $msg->{PARAMS} }, 1, 'One workflow instance present');
    is($msg->{PARAMS}->[0]->{'WORKFLOW.WORKFLOW_STATE'}, 'SUCCESS', 'Certificate issuance workflow is in state SUCCESS');

    # LOGOUT
    eval {
        $msg = $client->send_receive_service_msg('LOGOUT');
    };
    diag "Terminated connection";
    exit 0;
}
