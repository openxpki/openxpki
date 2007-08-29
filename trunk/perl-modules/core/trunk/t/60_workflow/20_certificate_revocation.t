use strict;
use warnings;
use English;
use Test::More;
plan tests => 23;

use OpenXPKI::Tests;
use OpenXPKI::Client;
use Data::Dumper;
use OpenXPKI::Serialization::Simple;

diag("Certificate revocation request workflow\n");

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

$msg = $client->send_receive_command_msg(
    'get_workflow_info',
    {
        WORKFLOW => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
        ID       => $wf_id,
    },
);

ok(! is_error_response($msg), 'Successfully got workflow instance info')
    or diag Dumper $msg;

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
