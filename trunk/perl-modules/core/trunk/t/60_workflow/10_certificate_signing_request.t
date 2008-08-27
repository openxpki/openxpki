use strict;
use warnings;
use English;
use Test::More;
plan tests => 38;

use OpenXPKI::Tests;
use OpenXPKI::Client;
use Data::Dumper;
use OpenXPKI::Serialization::Simple;
use File::Copy;
use Cwd;

diag("Certificate signing workflow\n");

my $instancedir = 't/60_workflow/test_instance';
my $socketfile = $instancedir . '/var/openxpki/openxpki.socket';
my $pidfile    = $instancedir . '/var/openxpki/openxpki.pid';
my $configfile = cwd()."/$instancedir/openssl.cnf";

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
            'cert_info' => "HASH\n0\n",
            'cert_profile' => 'I18N_OPENXPKI_PROFILE_TLS_SERVER',
            'cert_subject_alt_name_parts' => "HASH\n0\n",
            'cert_subject_parts' => "HASH\n94\n21\ncert_subject_hostname\nSCALAR\n27\nfully.qualified.example.com\n17\ncert_subject_port\nSCALAR\n0\n\n",
            'cert_subject_style' => '00_tls_basic_style',
            'csr_type' => 'spkac',
            'spkac' => 'MIIBOjCBpDCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEA1Qwkd2oQ2Cds6b0+zT2qGUAFfTRRX5cRHAsbhjsw4PnPSgSJmbw7+9YerrKxfu/SqPjGSpm+yxx+skhb23hR3scGYX2WIbEsyALqkaNr4EYuB9VB7xZoNnolYYmjrR2YfmEpbPppUjnQgI9oGQHF1dh83QtQHGX4pJjonXvQ/I8CAwEAARYAMA0GCSqGSIb3DQEBBAUAA4GBAGdGhX9YgtcaWCHB9+TUdbEPuS5thC/Ox/AswcpE6gp31XTPWNQ0dl3RFq3fRDssvYgWJWeEp+03YpAf+GuW4yyEKiyMuXPlBfeMy9D9s2XZrr7f0R37w5ufFwZIr1dFO5M2K9vN5bFdBFs7xeJbVkPotMvW1Z3koQuHfhKe8rov',
        },
    },
);
ok(is_error_response($msg), 'Successfully complains about missing field')
    or diag Dumper $msg;
is($msg->{LIST}->[0]->{LABEL}, 'I18N_OPENXPKI_SERVER_API_WORKFLOW_MISSING_REQUIRED_FIELDS', 'Correct error message');
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
ok(! is_error_response($msg), 'Successfully created CSR workflow instance')
    or diag Dumper $msg;

# LOGOUT
eval {
    $msg = $client->send_receive_service_msg('LOGOUT');
};
diag "Terminated connection";

$client = OpenXPKI::Client->new({
    SOCKETFILE => $instancedir . '/var/openxpki/openxpki.socket',
});
ok(login({
    CLIENT   => $client,
    USER     => 'raop2',
    PASSWORD => 'RA Operator',
  }), 'Logged in (as raop2) successfully');
my $wf_id = $msg->{PARAMS}->{WORKFLOW}->{ID} ;

$msg = $client->send_receive_command_msg(
    'get_workflow_info',
    {
        WORKFLOW => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
        ID       => $wf_id,
    },
);
ok(! is_error_response($msg), 'Successfully got workflow instance info')
    or diag Dumper $msg;
ok(exists $msg->{PARAMS}->{ACTIVITY}->{'I18N_OPENXPKI_WF_ACTION_APPROVE_CSR'}, 'Approve activity exists');
ok(defined $wf_id, 'Workflow ID exists');
is($msg->{PARAMS}->{WORKFLOW}->{STATE}, 'PENDING', 'WF is in state PENDING');
is($msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{'cert_subject'}, 'CN=fully.qualified.example.com,DC=Test Deployment,DC=OpenXPKI,DC=org', 'Correct cert subject') or diag $msg->{PARAMS};

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

ok(! is_error_response($msg), 'Successfully changed subject');
is($msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{cert_subject}, 'CN=fully.qualified.example.com,DC=Test,DC=OpenXPKI,DC=org', 'Changed subject in context')
    or diag Dumper $msg;

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

# Changing notbefore/notafter date

$msg = $client->send_receive_command_msg(
    'execute_workflow_activity',
    {
          'ACTIVITY' => 'I18N_OPENXPKI_WF_ACTION_CHANGE_NOTBEFORE',
          'ID' => $wf_id,
          'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
          'PARAMS' => {
                        'notbefore' => '20000101000000',
           },
    },
); 

ok(! is_error_response($msg), 'Successfully changed notbefore date');
is($msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{notbefore}, '20000101000000', 'Changed notbefore date in context')
    or diag Dumper $msg;

$msg = $client->send_receive_command_msg(
    'execute_workflow_activity',
    {
          'ACTIVITY' => 'I18N_OPENXPKI_WF_ACTION_CHANGE_NOTAFTER',
          'ID' => $wf_id,
          'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
          'PARAMS' => {
                        'notafter' => '20200101000000',
           },
    },
); 

ok(! is_error_response($msg), 'Successfully changed notafter date');
is($msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{notafter}, '20200101000000', 'Changed notafter date in context')
    or diag Dumper $msg;

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
