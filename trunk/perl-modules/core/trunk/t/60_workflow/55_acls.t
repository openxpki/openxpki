use strict;
use warnings;
use English;
use Test::More;
plan tests => 19;

use OpenXPKI::Tests;
use OpenXPKI::Client;
use Data::Dumper;
use OpenXPKI::Serialization::Simple;

diag("Workflow ACL enforcement\n");

# reuse the already deployed server
my $instancedir = 't/60_workflow/test_instance';
my $socketfile = $instancedir . '/var/openxpki/openxpki.socket';
my $pidfile    = $instancedir . '/var/openxpki/openxpki.pid';

start_test_server({
        DIRECTORY  => $instancedir,
});
diag "Server started";

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

my $msg;
ok(login({
    CLIENT   => $client,
    USER     => 'anonymous',
    PASSWORD => '',
  }), 'Logged in successfully (anonymous)');

# try to create workflows for which we do not have permission
my @forbidden_workflows = qw(
    I18N_OPENXPKI_WF_TYPE_CERTIFICATE_ISSUANCE
    I18N_OPENXPKI_WF_TYPE_CERTIFICATE_LDAP_PUBLISHING
    I18N_OPENXPKI_WF_TYPE_CRL_ISSUANCE
    I18N_OPENXPKI_WF_TYPE_SMARTCARD_PERSONALIZATION
);
foreach my $wf_type (@forbidden_workflows) {
    $msg = $client->send_receive_command_msg(
        'create_workflow_instance',
        {
          'WORKFLOW' => $wf_type,
          'PARAMS' => {
          },
        },
    );
    ok(is_error_response($msg) &&
        $msg->{LIST}->[0]->{LABEL} eq 'I18N_OPENXPKI_SERVER_ACL_AUTHORIZE_WORKFLOW_CREATE_PERMISSION_DENIED', 'Disallows creation of ' . $wf_type) or diag Dumper $msg;
}
# ... but we should be able to create a CSR workflow
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
            'spkac' => 'MIICQDCCASgwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDN621PX4eWoDDhR8Rml0netOyGOjpYLIlSj3FKp/rnvpInGnh+8y2DZNwemAkzGs0kKDVKkA3ii1jlu7GCOyDvMU833MpGu5ao+pJ7LHaA2nhSGjHwaxq4UB4P58sKfdbWqTbpDrob+bsex38mEUaGGnZiCjBNOdnNpblq20rUwbTsAaaAex6lCpr1Y7ICblSE2ZrM8G1cwHFXlLNDdZFDIpxJIN2oOR7fR68HDN13l3jdZ+uaYEMTI9uO+DBYLzpEgLVPVx/vXKPDqOnB955BIsAqA8c8RvcWPkSCgZpJCJ84ryi71I33j/SyCYM6IT9qeli3bdMXCn6SbkXdaT57AgMBAAEWADANBgkqhkiG9w0BAQQFAAOCAQEAAhN6ge/5bkF9EhXWmsWuHbTmnWvBB8CuU6ZNKLCzG+cVyXDNGJOTqaupLwRuYWGTns/PJNAsD3kFVn1/qGaJwV/aMZda8hp80w1n/n++efO2hrNfbeNw7erdtG2dg1fd/AR5YF+HJDrKGHW2c0EcluU5m5Jkw4rBF7iPK/xhrsBplCm1KdGYpN/DkUqGx6G9o1t0zLmqZwG5im6PabNsAqDosFryLWPuQ8Sn1KdtGLwwLXYhDPMnZu3jYHnVZVDMMwllHuXS3hM2ofCJQ3HfohD3Poy+gX3HeHw/eHmtnLM64t8gQmmDobO1qGcNOJflmDVTfR9sAZ8j95pfgL8d5g==',
        },
    },
);
ok(! is_error_response($msg), 'Successfully created CSR workflow instance') or diag Dumper $msg;

# LOGOUT
eval {
    $msg = $client->send_receive_service_msg('LOGOUT');
};
undef $client;
diag "Terminated connection";

# login as user
$client = OpenXPKI::Client->new({
    SOCKETFILE => $instancedir . '/var/openxpki/openxpki.socket',
});

ok(login({
    CLIENT   => $client,
    USER     => 'user1',
    PASSWORD => 'User',
  }), 'Logged in successfully (user1)');

$msg = $client->send_receive_command_msg(
    'get_workflow_info',
    {
          'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
          'ID'       => 1023,
    },
); 
ok(is_error_response($msg) &&
    $msg->{LIST}->[0]->{LABEL} eq 'I18N_OPENXPKI_SERVER_ACL_AUTHORIZE_WORKFLOW_READ_PERMISSION_DENIED_WORKFLOW_CREATOR_NOT_ACCEPTABLE', 'Cannot call get_workflow_info on workflow of somebody else') or diag Dumper $msg;

$msg = $client->send_receive_command_msg(
    'execute_workflow_activity',
    {
          'ACTIVITY' => 'I18N_OPENXPKI_WF_ACTION_APPROVE_CSR',
          'ID' => '1023',
          'PARAMS' => {
                      },
          'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
    },
); 
ok(is_error_response($msg) &&
    $msg->{LIST}->[0]->{LABEL} eq 'I18N_OPENXPKI_SERVER_ACL_AUTHORIZE_WORKFLOW_READ_PERMISSION_DENIED_WORKFLOW_CREATOR_NOT_ACCEPTABLE', 'Cannot execute activity on workflow of somebody else') or diag Dumper $msg;

# create our own workflow
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
            'spkac' => 'MIIBOjCBpDCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEAzujZiaI/kTCUyDg8FAm8iklKWF4HFKsm/bv+UGjJPynp1r1862oHEgJI92rXmYZBUpwXR3hJSsORajV5bgq+aI7anoku7St2qotqLb60YGBn/S5QpYcO8JQqPkJzcRMxT1rJtcjpfb5ZSxYebKKHHyjeNXmrTUgVSWEEUHrEyhkCAwEAARYAMA0GCSqGSIb3DQEBBAUAA4GBAA1uICHrQz5wLOYR1p/Xo4FjtqJ1VYt1Qa2DnaOdyaalfp43Q02tWBL9Sl+0eE94IrSG62Mbk/YxwjnWqwXdcyFOgay4Nq3ZgDMyhsIpZr7AAV9ZfU+6rgJEKbjeJhG5RpL/HKLAeKOokly4z0SLqQpaDnFdkV5ahhjfRi/YQcHv',
        },
    },
);
ok(! is_error_response($msg), 'Successfully created CSR workflow instance') or diag Dumper $msg;
my $wf_id = $msg->{PARAMS}->{WORKFLOW}->{ID} ;

$msg = $client->send_receive_command_msg(
    'get_workflow_info',
    {
          'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
          'ID'       => $wf_id,
    },
); 
ok(! is_error_response($msg), 'Can get workflow info on our own workflow') or diag Dumper $msg;

$msg = $client->send_receive_command_msg(
    'execute_workflow_activity',
    {
          'ACTIVITY' => 'I18N_OPENXPKI_WF_ACTION_APPROVE_CSR',
          'ID'       => $wf_id,
          'PARAMS'   => {
                        },
          'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
    },
); 
ok(is_error_response($msg) &&
    $msg->{LIST}->[0]->{LABEL} !~ qr/I18N_OPENXPKI_SERVER_ACL_AUTHORIZE_WORKFLOW_READ_PERMISSION_DENIED/, 'Cannot execute activity on our own workflow - but not because of ACL reading problems') or diag Dumper $msg;

# LOGOUT
eval {
    $msg = $client->send_receive_service_msg('LOGOUT');
};
undef $client;
diag "Terminated connection";

# Login as RA Operator and approve workflow
$client = OpenXPKI::Client->new({
    SOCKETFILE => $instancedir . '/var/openxpki/openxpki.socket',
});

ok(login({
    CLIENT   => $client,
    USER     => 'raop',
    PASSWORD => 'RA Operator',
  }), 'Logged in successfully (raop)');

$msg = $client->send_receive_command_msg(
    'execute_workflow_activity',
    {
          'ACTIVITY' => 'I18N_OPENXPKI_WF_ACTION_APPROVE_CSR',
          'ID'       => $wf_id,
          'PARAMS'   => {
                        },
          'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
    },
); 
ok(! is_error_response($msg), 'Successfully approved workflow') or diag Dumper $msg;

eval {
    $msg = $client->send_receive_service_msg('LOGOUT');
};
undef $client;
diag "Terminated connection";

# Login as user again and check whether we can see the approval in the context
$client = OpenXPKI::Client->new({
    SOCKETFILE => $instancedir . '/var/openxpki/openxpki.socket',
});

ok(login({
    CLIENT   => $client,
    USER     => 'user1',
    PASSWORD => 'User',
  }), 'Logged in successfully (user1)');

$msg = $client->send_receive_command_msg(
    'execute_workflow_activity',
    {
          'ACTIVITY' => 'I18N_OPENXPKI_WF_ACTION_APPROVE_CSR',
          'ID'       => $wf_id,
          'PARAMS'   => {
                        },
          'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
    },
); 

$msg = $client->send_receive_command_msg(
    'get_workflow_info',
    {
          'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
          'ID'       => $wf_id,
    },
); 
ok(! is_error_response($msg), 'Can get workflow info on our own workflow') or diag Dumper $msg;

ok(! exists $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{approvals}, 'Approvals are not present in the workflow context view');
