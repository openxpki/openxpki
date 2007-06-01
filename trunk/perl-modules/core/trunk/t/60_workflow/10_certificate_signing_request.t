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
my $NUMBER_OF_TESTS  = 33;

# do not use test numbers because forking destroys all order
Test::More->builder()->use_numbers(0);

diag("Certificate signing workflow\n");
print "1..$NUMBER_OF_TESTS\n";

my $instancedir = 't/60_workflow/test_instance';
my $socketfile = $instancedir . '/var/openxpki/openxpki.socket';
my $pidfile    = $instancedir . '/var/openxpki/openxpki.pid';

ok(deploy_test_server({
        DIRECTORY  => $instancedir,
    }), 'Test server deployed successfully');

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
    local $SIG{'CHLD'} = 'IGNORE';
    # this is the parent
    start_test_server({
        FOREGROUND => 1,
        DIRECTORY  => $instancedir,
    });
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

    # New workflow instance
    my $msg = $client->send_receive_command_msg(
        'create_workflow_instance',
        {
            WORKFLOW => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
            PARAMS   => {
                'cert_info' => "HASH\n0",
                'cert_profile' => 'I18N_OPENXPKI_PROFILE_TLS_SERVER',
                'cert_subject_alt_name_parts' => "HASH\n0",
                'cert_subject_parts' => "HASH\n94\n21\ncert_subject_hostname\nSCALAR\n27\nfully.qualified.example.com\n17\ncert_subject_port\nSCALAR\n0\n\n",
                'cert_subject_style' => 'tls_basic_style',
                'csr_type' => 'spkac',
                'spkac' => 'MIIBOjCBpDCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEA1Qwkd2oQ2Cds6b0+zT2qGUAFfTRRX5cRHAsbhjsw4PnPSgSJmbw7+9YerrKxfu/SqPjGSpm+yxx+skhb23hR3scGYX2WIbEsyALqkaNr4EYuB9VB7xZoNnolYYmjrR2YfmEpbPppUjnQgI9oGQHF1dh83QtQHGX4pJjonXvQ/I8CAwEAARYAMA0GCSqGSIb3DQEBBAUAA4GBAGdGhX9YgtcaWCHB9+TUdbEPuS5thC/Ox/AswcpE6gp31XTPWNQ0dl3RFq3fRDssvYgWJWeEp+03YpAf+GuW4yyEKiyMuXPlBfeMy9D9s2XZrr7f0R37w5ufFwZIr1dFO5M2K9vN5bFdBFs7xeJbVkPotMvW1Z3koQuHfhKe8rov',
            },
        },
    );
    ok(is_error_response($msg), 'Successfully complains about missing field');
    is($msg->{LIST}->[0]->{LABEL}, 'I18N_OPENXPKI_SERVER_API_WORKFLOW_MISSING_REQUIRED_FIELDS', 'Correct error message');
    $msg = $client->send_receive_command_msg(
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

    # change subject

    $msg = $client->send_receive_command_msg(
        'execute_workflow_activity',
        {
              'ACTIVITY' => 'I18N_OPENXPKI_WF_ACTION_CHANGE_CSR_SUBJECT',
              'ID' => $wf_id,
              'PARAMS' => {
                            'cert_subject' => 'CN=fully.qualified.example.com,DC=Test,DC=OpenXPKI,DC=org'
                          },
              'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
        },
    ); 

    TODO: {
        local $TODO = 'Changing CSR subject is currently broken. Bug report #1728258';
        ok(! is_error_response($msg), 'Successfully changed subject');
        is($msg->{PARAM}->{WORKFLOW}->{CONTEXT}->{cert_subject}, 'CN=fully.qualified.example.com,DC=Test,DC=OpenXPKI,DC=org', 'Changed subject in context');
    }

    # changing CSR profile
    
    $msg = $client->send_receive_command_msg(
        'get_workflow_info',
        {
            'ID' => $wf_id,
            'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
        },
    );
    ok(! is_error_response($msg), 'get_workflow_info()');

    my $sources = OpenXPKI::Serialization::Simple->new()->deserialize(
        $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{sources},
    );
    is($sources->{cert_profile}, 'USER', 'Profile source is USER');

    $msg = $client->send_receive_command_msg(
        'execute_workflow_activity',
        {
              'ACTIVITY' => 'I18N_OPENXPKI_WF_ACTION_CHANGE_CSR_PROFILE',
              'ID' => $wf_id,
              'PARAMS' => {
                            'cert_profile' => 'I18N_OPENXPKI_PROFILE_USER',
                          },
              'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
        },
    ); 

    ok(! is_error_response($msg), 'Successfully changed profile') or diag Dumper $msg;
    is($msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{cert_profile}, 'I18N_OPENXPKI_PROFILE_USER', 'Changed profile in context');

    $sources = OpenXPKI::Serialization::Simple->new()->deserialize(
        $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{sources},
    );
    is($sources->{cert_profile}, 'OPERATOR', 'Profile source has changed to OPERATOR');

    # changing CSR role
    
    $msg = $client->send_receive_command_msg(
        'get_workflow_info',
        {
            'ID' => $wf_id,
            'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
        },
    );
    ok(! is_error_response($msg), 'get_workflow_info()');

    $sources = OpenXPKI::Serialization::Simple->new()->deserialize(
        $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{sources},
    );
    is($sources->{cert_role}, 'USER', 'Profile source is USER');

    $msg = $client->send_receive_command_msg(
        'execute_workflow_activity',
        {
              'ACTIVITY' => 'I18N_OPENXPKI_WF_ACTION_CHANGE_CSR_ROLE',
              'ID' => $wf_id,
              'PARAMS' => {
                            'cert_role' => 'CA Operator',
                          },
              'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
        },
    ); 

    ok(! is_error_response($msg), 'Successfully changed role') or diag Dumper $msg;
    is($msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{cert_role}, 'CA Operator', 'Changed role in context');

    $sources = OpenXPKI::Serialization::Simple->new()->deserialize(
        $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{sources},
    );
    is($sources->{cert_role}, 'OPERATOR', 'Role source has changed to OPERATOR');

    # TODO - change additional info

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
    diag Dumper $msg;
    ok(! is_error_response($msg), 'Successfully approved') or diag Dumper $msg;
    ok($msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{'approvals'}, 'Context has approvals');
    my @approvals = ();
    eval {
        @approvals = @{ OpenXPKI::Serialization::Simple->new()->deserialize(
            $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{'approvals'}) };
    };
    is(scalar @approvals, 1, 'One approval present');
    is($msg->{PARAMS}->{WORKFLOW}->{STATE}, 'APPROVAL', 'New state is APPROVAL');

    # Cancel approval

    $msg = $client->send_receive_command_msg(
        'execute_workflow_activity',
        {
              'ACTIVITY' => 'I18N_OPENXPKI_WF_ACTION_CANCEL_CSR_APPROVAL',
              'ID' => $wf_id,
              'PARAMS' => {
                          },
              'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
        },
    ); 
    ok(! is_error_response($msg), 'Successfully cancelled approval') or diag Dumper $msg;
    is($msg->{PARAMS}->{WORKFLOW}->{STATE}, 'PENDING', 'State is PENDING again');
    ok($msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{'approvals'}, 'Context has approvals');
    @approvals = ();
    eval {
        @approvals = @{ OpenXPKI::Serialization::Simple->new()->deserialize(
            $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{'approvals'}) };
    };
    is(scalar @approvals, 0, 'No approvals present');

    # Reject CSR

    $msg = $client->send_receive_command_msg(
        'execute_workflow_activity',
        {
              'ACTIVITY' => 'I18N_OPENXPKI_WF_ACTION_REJECT_CSR',
              'ID' => $wf_id,
              'PARAMS' => {
                          },
              'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
        },
    ); 
    ok(! is_error_response($msg), 'Successfully rejected CSR') or diag Dumper $msg;
    is($msg->{PARAMS}->{WORKFLOW}->{STATE}, 'FAILURE', 'State is FAILURE');

    # LOGOUT
    eval {
        $msg = $client->send_receive_service_msg('LOGOUT');
    };
    diag "Terminated connection";
    exit 0;
}
