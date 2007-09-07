use strict;
use warnings;
use English;
use Test::More qw( no_plan );

use OpenXPKI::Tests;
use OpenXPKI::Client;
use Data::Dumper;

# this is needed because we need to manually output the number of tests
# run at the end. 
Test::More->builder()->no_header(1);
my $OUTPUT_AUTOFLUSH = 1;
my $NUMBER_OF_TESTS = 26;

# do not use test numbers because forking destroys all order
Test::More->builder()->use_numbers(0);

diag("Config versioning\n");
print "1..$NUMBER_OF_TESTS\n";

my $instancedir = 't/80_config_versioning/test_instance';
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

    # Current config ID
    my $msg = $client->send_receive_command_msg(
        'get_current_config_id',
    );
    ok(! is_error_response($msg), 'No error received on get_current_config_id');
    my $first_config_id = $msg->{PARAMS};
    if ($ENV{DEBUG}) {
        diag "Current config ID: " . $first_config_id;
    }

    # List of all config IDs
    $msg = $client->send_receive_command_msg(
        'list_config_ids',
    );
    ok(! is_error_response($msg), 'No error received on list_config_ids');
    if ($ENV{DEBUG}) {
        diag "Config IDs: " . Dumper $msg->{PARAMS};
    }
    ok(ref $msg->{PARAMS} eq 'ARRAY' && scalar @{ $msg->{PARAMS} } == 1,
        '1 config ID present')
        or diag "list_config_ids: " . Dumper $msg->{PARAMS};
    is($msg->{PARAMS}->[0], $first_config_id, 'Listed config ID is current one') or diag "list_config_ids: " . Dumper $msg->{PARAMS};

    # New workflow instance
    $msg = $client->send_receive_command_msg(
        'create_workflow_instance',
        {
            WORKFLOW => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
            PARAMS   => {
                'cert_info' => "HASH\n0\n",
                'cert_profile' => 'I18N_OPENXPKI_PROFILE_TLS_SERVER',
                'cert_role' => 'Web Server',
                'cert_subject_alt_name_parts' => "HASH\n0\n",
                'cert_subject_parts' => "HASH\n94\n21\ncert_subject_hostname\nSCALAR\n27\nfully.qualified.example.com\n17\ncert_subject_port\nSCALAR\n0\n\n",
                'cert_subject_style' => '00_tls_basic_style',
                'csr_type' => 'spkac',
                'spkac' => 'MIIBOjCBpDCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEA1Qwkd2oQ2Cds6b0+zT2qGUAFfTRRX5cRHAsbhjsw4PnPSgSJmbw7+9YerrKxfu/SqPjGSpm+yxx+skhb23hR3scGYX2WIbEsyALqkaNr4EYuB9VB7xZoNnolYYmjrR2YfmEpbPppUjnQgI9oGQHF1dh83QtQHGX4pJjonXvQ/I8CAwEAARYAMA0GCSqGSIb3DQEBBAUAA4GBAGdGhX9YgtcaWCHB9+TUdbEPuS5thC/Ox/AswcpE6gp31XTPWNQ0dl3RFq3fRDssvYgWJWeEp+03YpAf+GuW4yyEKiyMuXPlBfeMy9D9s2XZrr7f0R37w5ufFwZIr1dFO5M2K9vN5bFdBFs7xeJbVkPotMvW1Z3koQuHfhKe8rov',
            },
        },
    );
    ok(! is_error_response($msg), 'Successfully created CSR workflow instance');
    is($first_config_id, $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{config_id}, "Workflow's config id is the current one");

    eval {
        $msg = $client->send_receive_service_msg('LOGOUT');
    };
    diag "Terminated connection";
    exit 0;
}


# change some configuration (CSR workflow and role definitions)

ok(system("patch -p0 < t/80_config_versioning/config.patch") == 0, 'Successfully patched configuration');

###########################################################################
################# SECOND CONNECTION WITH DIFFERENT CONFIG #################
###########################################################################

unlink $pidfile;
# Fork server, connect to it, test config IDs, create workflow instance
$redo_count = 0;
undef $pid;
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
    # this is the parent
    Test::More->builder()->use_numbers(0);
    local $SIG{'ALRM'} = sub { die "Timeout ..." };
    alarm 300;
    start_test_server({
        FOREGROUND => 1,
        DIRECTORY  => $instancedir,
    });
    alarm 0;
}
else {
    # child here
    Test::More->builder()->use_numbers(0);
    my $socketfile = $instancedir . '/var/openxpki/openxpki.socket';
    my $pidfile    = $instancedir . '/var/openxpki/openxpki.pid';

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

    # Current config ID
    my $msg = $client->send_receive_command_msg(
        'get_current_config_id',
    );
    ok(! is_error_response($msg), 'No error received on get_current_config_id');
    my $second_config_id = $msg->{PARAMS};
    if ($ENV{DEBUG}) {
        diag "Current config ID: " . $second_config_id;
    }

    # New workflow instance
    $msg = $client->send_receive_command_msg(
        'create_workflow_instance',
        {
            WORKFLOW => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
            PARAMS   => {
                'cert_info' => "HASH\n0\n",
                'cert_profile' => 'I18N_OPENXPKI_PROFILE_TLS_SERVER',
                'cert_role' => 'Web Server',
                'cert_subject_alt_name_parts' => "HASH\n0\n",
                'cert_subject_parts' => "HASH\n94\n21\ncert_subject_hostname\nSCALAR\n27\nfully.qualified.example.com\n17\ncert_subject_port\nSCALAR\n0\n\n",
                'cert_subject_style' => '00_tls_basic_style',
                'csr_type' => 'spkac',
                'spkac' => 'MIIBOjCBpDCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEA1Qwkd2oQ2Cds6b0+zT2qGUAFfTRRX5cRHAsbhjsw4PnPSgSJmbw7+9YerrKxfu/SqPjGSpm+yxx+skhb23hR3scGYX2WIbEsyALqkaNr4EYuB9VB7xZoNnolYYmjrR2YfmEpbPppUjnQgI9oGQHF1dh83QtQHGX4pJjonXvQ/I8CAwEAARYAMA0GCSqGSIb3DQEBBAUAA4GBAGdGhX9YgtcaWCHB9+TUdbEPuS5thC/Ox/AswcpE6gp31XTPWNQ0dl3RFq3fRDssvYgWJWeEp+03YpAf+GuW4yyEKiyMuXPlBfeMy9D9s2XZrr7f0R37w5ufFwZIr1dFO5M2K9vN5bFdBFs7xeJbVkPotMvW1Z3koQuHfhKe8rov',
            },
        },
    );
    ok(! is_error_response($msg), 'Successfully created 2nd CSR workflow instance');
    my $second_workflow_id = $msg->{PARAMS}->{WORKFLOW}->{ID};
    is($second_config_id, $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{config_id}, "Workflow's config id is the current one");

    # Find first WF ID
    $msg = $client->send_receive_command_msg(
        'list_workflow_instances',
        {
            LIMIT => 2,
            START => 0,
        },
    );
    ok(! is_error_response($msg), 'No error received on list_workflow_instances') or diag Dumper $msg;
    if ($ENV{DEBUG}) {
        diag "list_workflow_instances: " . Dumper $msg;
    }
    my $first_workflow_id;
  FIND_FIRST_WF_ID:
    foreach my $instance (@{ $msg->{PARAMS} }) {
        if ($ENV{DEBUG}) {
            diag "Instance: " . Dumper $instance;
        }
        if ($instance->{WORKFLOW_SERIAL} != $second_workflow_id) {
            $first_workflow_id = $instance->{WORKFLOW_SERIAL};
            last FIND_FIRST_WF_ID;
        }
    }
    ok($first_workflow_id, 'Found first workflow ID from instance list');
    if ($ENV{DEBUG}) {
        diag("First workflow ID: $first_workflow_id");
    }

    # 1st workflow's config ID
    $msg = $client->send_receive_command_msg(
        'get_workflow_info',
        {
            WORKFLOW => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
            ID       => $first_workflow_id,
        },
    );
    my $first_config_id = $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{config_id};
    ok($first_config_id, 'Retrieved first config ID from first workflow');
    if ($ENV{DEBUG}) {
        diag("First config ID: $first_config_id");
    }

    # First and second ID should be different
    isnt($first_config_id, $second_config_id, 'Config IDs differ');

    # All config IDs
    $msg = $client->send_receive_command_msg(
        'list_config_ids',
    );
    ok(! is_error_response($msg), 'No error received on list_config_ids');
    if ($ENV{DEBUG}) {
        diag "Config IDs: " . Dumper $msg->{PARAMS};
    }
    ok(ref $msg->{PARAMS} eq 'ARRAY' && scalar @{ $msg->{PARAMS} } == 2,
        '2 config IDs present')
        or diag "list_config_ids: " . Dumper $msg->{PARAMS};

    # retrieve WF activities of first WF
    $msg = $client->send_receive_command_msg(
        'get_workflow_activities',
        {
            WORKFLOW => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
            ID       => $first_workflow_id,
        },
    );
    ok(! is_error_response($msg), 'get_workflow_activities() 1st WF');
    my $first_workflow_activities = $msg->{PARAMS};

    # List of activities for the second workflow
    $msg = $client->send_receive_command_msg(
        'get_workflow_activities',
        {
            WORKFLOW => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
            ID       => $second_workflow_id,
        },
    );
    ok(! is_error_response($msg), 'get_workflow_activities() 2nd WF');
    my $second_workflow_activities = $msg->{PARAMS};
    isnt_deeply($first_workflow_activities, $second_workflow_activities, 'Workflow activities for first and second workflow differ');
    eval {
        $msg = $client->send_receive_service_msg('LOGOUT');
    };
    diag "Terminated connection";
    exit 0;
}
