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
use Digest::SHA qw(hmac_sha256_hex);

use Test::More tests => 10;

package main;

my $result;
my $client = TestCGI::factory('democa');

my $sscep = -e "./sscep" ? './sscep' : 'sscep';

SKIP: { skip 'sscep not available', 10 if (system "$sscep > /dev/null 2>&1");

`$sscep getca -c tmp/cacert -u http://localhost/scep/scep`;

ok((-s "tmp/cacert-0"),'CA certs present') || die;

# Create the pkcs10
`openssl req -new -subj "/CN=entity-scep-hmac-test.openxpki.org" -nodes -keyout tmp/entity-scep-hmac.key -out tmp/entity-scep-hmac.csr 2>/dev/null`;

ok((-s "tmp/entity-scep-hmac.csr"), 'csr present') || die;

my $pem = `cat tmp/entity-scep-hmac.csr`;
$pem =~ s/-----(BEGIN|END)[^-]+-----//g;
$pem =~ s/\s//xmsg;

my $hmac = hmac_sha256_hex(decode_base64($pem), 'verysecret');

# do on with hmac attached certificate
my $scep = `$sscep enroll -v -u http://localhost/scep/scep -M signature=$hmac -r tmp/entity-scep-hmac.csr -k tmp/entity-scep-hmac.key -c tmp/cacert-0 -l tmp/entity-scep-hmac.crt  -t 1 -n 1 -v |  grep "Read request with transaction id"
`;
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

is($client->get_field_from_result('url_signature'), $hmac);
is($client->get_field_from_result('csr_hmac'), $hmac);
ok($client->get_field_from_result('is_valid_hmac'));

$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!enroll_reject_request!wf_id!' . $workflow_id,
});

is ($result->{right}->[0]->{content}->{data}->[3]->{value}, 'FAILURE', 'Status is FAILURE');

}
