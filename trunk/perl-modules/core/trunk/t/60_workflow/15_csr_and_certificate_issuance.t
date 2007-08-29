use strict;
use warnings;
use English;
use Test::More;
plan tests => 23;

use OpenXPKI::Tests;
use OpenXPKI::Client;
use Data::Dumper;
use OpenXPKI::Serialization::Simple;

# this is needed because we need to manually output the number of tests run
diag("CSR with cert issuance workflow forking\n");

# reuse the already deployed server
my $instancedir = 't/60_workflow/test_instance';
my $socketfile = $instancedir . '/var/openxpki/openxpki.socket';
my $pidfile    = $instancedir . '/var/openxpki/openxpki.pid';

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
            'cert_subject_style' => '00_tls_basic_style',
            'csr_type' => 'spkac',
            'spkac' => 'MIIBOjCBpDCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEA1Qwkd2oQ2Cds6b0+zT2qGUAFfTRRX5cRHAsbhjsw4PnPSgSJmbw7+9YerrKxfu/SqPjGSpm+yxx+skhb23hR3scGYX2WIbEsyALqkaNr4EYuB9VB7xZoNnolYYmjrR2YfmEpbPppUjnQgI9oGQHF1dh83QtQHGX4pJjonXvQ/I8CAwEAARYAMA0GCSqGSIb3DQEBBAUAA4GBAGdGhX9YgtcaWCHB9+TUdbEPuS5thC/Ox/AswcpE6gp31XTPWNQ0dl3RFq3fRDssvYgWJWeEp+03YpAf+GuW4yyEKiyMuXPlBfeMy9D9s2XZrr7f0R37w5ufFwZIr1dFO5M2K9vN5bFdBFs7xeJbVkPotMvW1Z3koQuHfhKe8rov',
        },
    },
);
ok(! is_error_response($msg), 'Successfully created CSR workflow instance');
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
$wf_id = $msg->{PARAMS}->{WORKFLOW}->{ID} ;
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
my $try = 1;
while ($try <= 60 && $msg->{PARAMS}->[0]->{'WORKFLOW.WORKFLOW_STATE'} ne 'SUCCESS') {
    # wait up to 60 seconds for cert issuance state to become SUCCESS
    $msg = $client->send_receive_command_msg(
        'search_workflow_instances',
        {
              'TYPE' => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_ISSUANCE',
        },
    ); 
    if ($ENV{DEBUG}) {
        diag "Try number $try, state: " . $msg->{PARAMS}->[0]->{'WORKFLOW.WORKFLOW_STATE'};
    }
    sleep 1;
    $try++;
}
is($msg->{PARAMS}->[0]->{'WORKFLOW.WORKFLOW_STATE'}, 'SUCCESS', 'Certificate issuance workflow is in state SUCCESS') or diag Dumper $msg;

$msg = $client->send_receive_command_msg(
    'get_workflow_info',
    {
          'ID'       => $msg->{PARAMS}->[0]->{'WORKFLOW.WORKFLOW_SERIAL'},
          'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_ISSUANCE',
    },
); 
ok(! is_error_response($msg), 'get_workflow_info') or diag Dumper $msg;
my $cert = $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{'certificate'};
ok($cert, 'Certificate is present in workflow context');

open my $TESTCERT, '>', "$instancedir/testcert.pem";
print $TESTCERT $cert;
close $TESTCERT;

my $openssl = `cat t/cfg.binary.openssl`;
my $openssl_output = `$openssl x509 -noout -text -in $instancedir/testcert.pem`;
ok($openssl_output =~ m{
        Subject:\ DC=org,\ DC=OpenXPKI,\ DC=Test\ Deployment,\ CN=fully.qualified.example.com
    }xms, 
    'Parsing certificate using OpenSSL works (subject)') or diag "Certificate: $cert\nOpenSSL output: $openssl_output";

ok($openssl_output =~ m{ DNS:fully\.qualified\.example\.com }xms,
    'Parsing certificate using OpenSSL works (subject alternative name)') or diag "Certificate: $cert\nOpenSSL output: $openssl_output";

# LOGOUT
eval {
    $msg = $client->send_receive_service_msg('LOGOUT');
};
diag "Terminated connection";
