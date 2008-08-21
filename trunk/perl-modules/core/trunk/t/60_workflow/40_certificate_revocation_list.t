use strict;
use warnings;
use English;
use Test::More;
plan tests => 9;

use OpenXPKI::Tests;
use OpenXPKI::Client;
use Data::Dumper;
use OpenXPKI::Serialization::Simple;

diag("Certificate revocation list workflow\n");

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
    PASSWORD => 'CA Operator',
  }), 'Logged in successfully');

# New workflow instance
my $msg = $client->send_receive_command_msg(
    'create_workflow_instance',
    {
        WORKFLOW => 'I18N_OPENXPKI_WF_TYPE_CRL_ISSUANCE',
        PARAMS   => {
        },
    },
);
ok(! is_error_response($msg), 'Successfully created CRL workflow instance') or diag "msg: " . Dumper $msg;
is($msg->{PARAMS}->{WORKFLOW}->{STATE}, 'SUCCESS', 'WF is in state SUCCESS');
ok(-s "$instancedir/etc/openxpki/ca/testdummyca1/crl.pem", "CRL file exists");

# Parsing using OpenSSL

my $openssl = `cat t/cfg.binary.openssl`;
my $openssl_output = `$openssl crl -noout -text -in $instancedir/etc/openxpki/ca/testdummyca1/crl.pem`;
if ($ENV{DEBUG}) {
    diag "OpenSSL output: $openssl_output";
}
ok($openssl_output =~ m{
        Certificate\ Revocation\ List
    }xms, 
    'Parsing CRL using OpenSSL works') or diag "OpenSSL output: $openssl_output";
ok($openssl_output =~ m{ 01FF }xms, 'Parsing using OpenSSL works (serial)')
    or diag "OpenSSL output: $openssl_output";
ok($openssl_output =~ m{ Cessation\ Of\ Operation }xms,
    'Parsing using OpenSSL works (reason code)')
    or diag "OpenSSL output: $openssl_output";

# LOGOUT
eval {
    $msg = $client->send_receive_service_msg('LOGOUT');
};
diag "Terminated connection";
