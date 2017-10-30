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

use Test::More tests => 8;

package main;

my $result;
my $client = TestCGI::factory();

my $sscep = -e "./sscep" ? './sscep' : 'sscep';

`$sscep getca -c tmp/cacert -u http://localhost/scep/scep`;

ok((-s "tmp/cacert-0"),'CA certs present') || die;

# Chain for TLS based requests later
`cat tmp/cacert-* > tmp/chain.pem`;

# Create the pkcs10
`openssl req -new -subj "/CN=entity-hmac-test.openxpki.org" -nodes -keyout tmp/entity-hmac.key -out tmp/entity-hmac.csr 2>/dev/null`;

ok((-s "tmp/entity-hmac.csr"), 'csr present') || die;

my $pem = `cat tmp/entity-hmac.csr`;
$pem =~ s/-----(BEGIN|END)[^-]+-----//g;
$pem =~ s/\s//xmsg;
my $hmac = hmac_sha256_hex(decode_base64($pem), 'verysecret');

# do on with hmac attached certificate
my $scep = `$sscep enroll -u http://localhost/scep/scep?hmac=$hmac -r tmp/entity-hmac.csr -k tmp/entity-hmac.key -c tmp/cacert-0 -l tmp/entity-hmac.crt  -t 1 -n 1 -v |  grep "Read request with transaction id"
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
    'wf_type' => 'enrollment',
    'scep_tid[]' => $sceptid,
});

ok($result->{goto});
like($result->{goto}, "/workflow!result!id/");

$result = $client->mock_request({
    page => $result->{goto},
});

my $workflow_id = $result->{main}->[0]->{content}->{data}->[0]->[0];
diag('Found workflow ' . $workflow_id );

is($result->{main}->[0]->{content}->{data}->[0]->[3], 'PENDING_APPROVAL');

# force failure
$result = $client->mock_request({
    'action' => $result->{right}->[0]->{buttons}->[0]->{action},
    'wf_token' => undef
});

# load raw context to find certificate id
$result = $client->mock_request({
    'page' => 'workflow!context!wf_id!' . $workflow_id
});

is($result->{main}->[0]->{content}->{data}->[7]->{value}, $hmac);
is($result->{main}->[0]->{content}->{data}->[43]->{value}, $hmac);

