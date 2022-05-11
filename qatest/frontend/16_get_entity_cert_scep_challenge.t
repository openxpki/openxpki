#!/usr/bin/perl

use lib qw(../lib);
use strict;
use warnings;
use JSON;
use English;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use TestCGI;
use MIME::Base64 qw(decode_base64);
use Test::More tests => 8;

package main;

my $result;
my $client = TestCGI::factory('democa');

my $sscep = -e "./sscep" ? './sscep' : 'sscep';

`$sscep getca -c tmp/cacert -u http://localhost/scep/scep`;

ok((-s "tmp/cacert-0"),'CA certs present') || die;

# Create the pkcs10 (use batch and no subject to use setting from config file)
`openssl req -new -batch -nodes -keyout tmp/entity-scep-challenge.key -out tmp/entity-scep-challenge.csr -config openssl.conf 2>/dev/null`;

ok((-s "tmp/entity-scep-challenge.csr"), 'csr present') || die;

my $scep = `$sscep enroll -v -u http://localhost/scep/scep -r tmp/entity-scep-challenge.csr -k tmp/entity-scep-challenge.key -c tmp/cacert-0 -l tmp/entity-scep-challenge.crt  -t 1 -n 1 -v |  grep "Read request with transaction id"`;
my @t = split(/:\s+/, $scep);
my $sceptid = $t[2];

diag("Transaction Id: $sceptid");
ok($sceptid) || die "Unable to get transaction id";

# Log in and approve request
$result = $client->mock_request({
    'action' => 'workflow!search',
    'wf_creator' => '',
    'wf_proc_state' => '',
    'wf_state' => '',
    'wf_type' => 'certificate_enroll',
    'transaction_id' => $sceptid,
});

ok($result->{goto});
like($result->{goto}, "/workflow!result!id/");

$result = $client->mock_request({
    page => $result->{goto},
});

my $workflow_id = $result->{main}->[0]->{content}->{data}->[0]->[0];
diag('Found workflow ' . $workflow_id );

is($result->{main}->[0]->{content}->{data}->[0]->[3], 'PENDING');

# load raw context to find certificate id
$result = $client->mock_request({
    'page' => 'workflow!context!wf_id!' . $workflow_id
});

ok($client->get_field_from_result('challenge_password_valid'));

$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!enroll_reject_request!wf_id!' . $workflow_id,
});

is ($result->{right}->[0]->{content}->{data}->[3]->{value}, 'FAILURE', 'Status is FAILURE');
