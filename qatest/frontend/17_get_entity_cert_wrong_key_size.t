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

use Test::More tests => 7;

package main;

my $result;
my $client = TestCGI::factory('democa');

my $sscep = -e "./sscep" ? './sscep' : 'sscep';

SKIP: { skip 'sscep not available', 7 if (system "$sscep > /dev/null 2>&1");

`$sscep getca -c /tmp/oxi-test/cacert -u http://localhost/scep/scep`;

ok((-s "/tmp/oxi-test/cacert-0"),'CA certs present') || die;

`rm -f /tmp/oxi-test/entity-hmac*`;

# Create the pkcs10
`openssl req -new -newkey rsa:512 -md5 -subj "/CN=entity-hmac-test.openxpki.org" -nodes -keyout /tmp/oxi-test/entity-hmac.key -out /tmp/oxi-test/entity-hmac.csr 2>/dev/null`;

ok((-s "/tmp/oxi-test/entity-hmac.csr"), 'csr present') || die;

my $pem = `cat /tmp/oxi-test/entity-hmac.csr`;
$pem =~ s/-----(BEGIN|END)[^-]+-----//g;
$pem =~ s/\s//xmsg;
my $hmac = hmac_sha256_hex(decode_base64($pem), 'verysecret');

# do on with hmac attached certificate
my $scep = `$sscep enroll -v -u http://localhost/scep/scep -M hmac=$hmac -r /tmp/oxi-test/entity-hmac.csr -k /tmp/oxi-test/entity-hmac.key -c /tmp/oxi-test/cacert-0 -l /tmp/oxi-test/entity-hmac.crt  -t 1 -n 1 -v |  grep "Read request with transaction id"
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

is($result->{main}->[0]->{content}->{data}->[0]->[3], 'FAILURE');

# load raw context to find certificate id
$result = $client->mock_request({
    'page' => 'workflow!context!wf_id!' . $workflow_id
});

is($client->get_field_from_result('error_code'), 'Policy failed (provided key does not match the requirements)');

}
