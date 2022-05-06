#!/usr/bin/perl

use lib qw(../lib);
use strict;
use warnings;
use JSON;
use English;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use TestCGI;

use Test::More tests => 6;

package main;

my $result;
my $client = TestCGI::factory('democa');

my $sscep = -e "./sscep" ? './sscep' : 'sscep';

SKIP: { skip 'sscep not available', 6 if (system "$sscep > /dev/null");

`$sscep getca -c tmp/cacert -u http://localhost/scep/scep`;

ok((-s "tmp/cacert-0"),'CA certs present') || die;

`rm -rf tmp/entity-fail.crt`;

# Create the pkcs10
`openssl req -new -subj "/CN=entity.openxpki.org" -nodes -keyout tmp/entity-fail.key -out tmp/entity-fail.csr 2>/dev/null`;

ok((-s "tmp/entity-fail.csr"), 'csr present') || die;

# do on behalf request with revoked pkiclient certificate
`$sscep enroll -u http://localhost/scep/scep -K tmp/pkiclient.key -O tmp/pkiclient.crt -r tmp/entity-fail.csr -k tmp/entity-fail.key -c tmp/cacert-0 -l tmp/entity-fail.crt  -t 1 -n 1`;

ok(! -e "tmp/entity-fail.crt", "Cert not exists");

# Log in and approve request
$result = $client->mock_request({
    'action' => 'workflow!search',
    'wf_creator' => '',
    'wf_proc_state' => '',
    'wf_state' => 'FAILURE',
    'wf_type' => 'certificate_enroll',
    'cert_subject' => 'CN=entity.openxpki.org*'
});

ok($result->{goto});
like($result->{goto}, "/workflow!result!id/");

$result = $client->mock_request({
    page => $result->{goto},
});

my $workflow_id = $result->{main}->[0]->{content}->{data}->[0]->[0];
diag('Found workflow ' . $workflow_id );

$result = $client->mock_request({
    'page' => 'workflow!context!wf_id!' . $workflow_id,
});

# Search for signer_revoked flag

foreach my $line (@{$result->{main}->[0]->{content}->{data}}) {
    ok($line->{value}, 'signer_revoked is set') if ($line->{label} =~ 'signer_revoked');
}

}
