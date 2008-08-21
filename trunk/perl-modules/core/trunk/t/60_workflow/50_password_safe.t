use strict;
use warnings;
use English;
use Test::More qw( no_plan );

use OpenXPKI::Tests;
use OpenXPKI::Client;
use Data::Dumper;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Crypto::TokenManager;
use OpenXPKI::Crypto::X509;

diag("Password safe workflow\n");

# reuse the already deployed server
my $instancedir = 't/60_workflow/test_instance';
my $socketfile = $instancedir . '/var/openxpki/openxpki.socket';
my $pidfile    = $instancedir . '/var/openxpki/openxpki.pid';

open my $TESTCERT, '<', $instancedir . '/testcert.pem';
my $cert = do {
    local $INPUT_RECORD_SEPARATOR;
    <$TESTCERT>;
};
close $TESTCERT;
eval `cat t/25_crypto/common.pl`;
my $tm = OpenXPKI::Crypto::TokenManager->new('IGNORE_CHECK' => 1);
my $default_token = $tm->get_token(
    TYPE      => 'DEFAULT',
    PKI_REALM => 'Test Root CA',
);
my $x509 = OpenXPKI::Crypto::X509->new(
    TOKEN => $default_token,
    DATA  => $cert,
);
my $identifier = $x509->get_identifier();
if ($ENV{DEBUG}) {
    diag "Encryption certificate identifier: $identifier";
}
`openxpkiadm certificate alias --config t/60_workflow/test_instance/etc/openxpki/config.xml --identifier $identifier --alias passwordsafe1 --realm I18N_OPENXPKI_DEPLOYMENT_TEST_DUMMY_CA`;
`mkdir t/60_workflow/test_instance/etc/openxpki/ca/passwordsafe1`;
`cp t/60_workflow/password_safe_key t/60_workflow/test_instance/etc/openxpki/ca/passwordsafe1/key.pem`;

#### restart server so that the password safe is initialized
ok(system("openxpkictl --config t/60_workflow/test_instance/etc/openxpki/config.xml stop") == 0,
        'Successfully stopped OpenXPKI instance');
ok(
    start_test_server({ DIRECTORY  => $instancedir }),
    'Successfully (re)started OpenXPKI instance',
);

ok(-e $pidfile, "PID file exists");
ok(-e $socketfile, "Socketfile exists");
my $client = OpenXPKI::Client->new({
    SOCKETFILE => $instancedir . '/var/openxpki/openxpki.socket',
});
ok(login({
    CLIENT   => $client,
    USER     => 'user',
    PASSWORD => 'User',
  }), 'Logged in successfully');

my $msg = $client->send_receive_command_msg(
    'create_workflow_instance',
    {
        WORKFLOW => 'I18N_OPENXPKI_WF_TYPE_PASSWORD_SAFE',
        PARAMS   => {
        },
    },
);
ok(! is_error_response($msg), 'Successfully created password safe workflow instance') or diag Dumper $msg;
is($msg->{PARAMS}->{WORKFLOW}->{STATE}, 'SUCCESS', 'WF is in state SUCCESS') or diag Dumper $msg;

# store password
my $wf_id = $msg->{PARAMS}->{WORKFLOW}->{ID};
$msg = $client->send_receive_command_msg(
    'execute_workflow_activity',
    {
        WORKFLOW => 'I18N_OPENXPKI_WF_TYPE_PASSWORD_SAFE',
        ID       => $wf_id,
        ACTIVITY => 'store_password',
        PARAMS   => {
            '_input_data' => {
                'test' => 'dummy',
            },
        },
    },
);
ok(! is_error_response($msg), 'Successfully executed store_password activity') or diag Dumper $msg;
like($msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{encrypted_test}, qr/-----BEGIN PKCS7/, 'PKCS#7 data present in workflow');

# retrieve password
$msg = $client->send_receive_command_msg(
    'execute_workflow_activity',
    {
        WORKFLOW => 'I18N_OPENXPKI_WF_TYPE_PASSWORD_SAFE',
        ID       => $wf_id,
        ACTIVITY => 'retrieve_password',
        PARAMS   => {
            '_id' => 'test'
        },
    },
);
ok(! is_error_response($msg), 'Successfully executed retrieve_password activity') or diag Dumper $msg;
is($msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{_passwords}->{'test'}, 'dummy', 'Password matches original') or diag Dumper $msg;

# change password
$msg = $client->send_receive_command_msg(
    'execute_workflow_activity',
    {
        WORKFLOW => 'I18N_OPENXPKI_WF_TYPE_PASSWORD_SAFE',
        ID       => $wf_id,
        ACTIVITY => 'change_password',
        PARAMS   => {
            '_input_data' => {
                'test' => 'dummy2',
            },
        },
    },
);
ok(! is_error_response($msg), 'Successfully executed change_password activity') or diag Dumper $msg;

# retrieve changed password
$msg = $client->send_receive_command_msg(
    'execute_workflow_activity',
    {
        WORKFLOW => 'I18N_OPENXPKI_WF_TYPE_PASSWORD_SAFE',
        ID       => $wf_id,
        ACTIVITY => 'retrieve_password',
        PARAMS   => {
            '_id' => 'test',
        },
    },
);
ok(! is_error_response($msg), 'Successfully executed retrieve_password activity for changed password') or diag Dumper $msg;
is($msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{_passwords}->{'test'}, 'dummy2', 'Password matches changed password') or diag Dumper $msg;

# LOGOUT
eval {
    $msg = $client->send_receive_service_msg('LOGOUT');
};
diag "Terminated connection";
