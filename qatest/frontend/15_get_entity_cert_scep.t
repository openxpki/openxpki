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
my $client = TestCGI::factory();

my $sscep = -e "./sscep" ? './sscep' : 'sscep';

`$sscep getca -c tmp/cacert -u http://localhost/scep/scep`;

ok((-s "tmp/cacert-0"),'CA certs present') || die;

# Chain for TLS based requests later
`cat tmp/cacert-* > tmp/chain.pem`;
`rm -f tmp/entity.*`;

# Create the pkcs10
`openssl req -new -nodes -keyout tmp/entity.key -out tmp/entity.csr  -config openssl.conf -reqexts req_template_v1 2>/dev/null`;

ok((-s "tmp/entity.csr"), 'csr present') || die;

# do on behalf request with pkiclient certificate
my $scep = `$sscep enroll -v -u http://localhost/scep/scep -K tmp/pkiclient.key -O tmp/pkiclient.crt -r tmp/entity.csr -k tmp/entity.key -c tmp/cacert-0 -l tmp/entity.crt  -t 1 -n 1 |  grep "Read request with transaction id"`;

my @t = split(/:\s+/, $scep);
my $sceptid = $t[2];

diag("Transaction Id: $sceptid");

# Log in and approve request
$result = $client->mock_request({
    'action' => 'workflow!search',
    'wf_type' => 'certificate_enroll',
    'wf_token' => undef,
    'transaction_id[]' => $sceptid,
});

ok($result->{goto});
like($result->{goto}, "/workflow!result!id/");

$result = $client->mock_request({
    page => $result->{goto},
});

my $workflow_id = $result->{main}->[0]->{content}->{data}->[0]->[0];
diag('Found workflow ' . $workflow_id );

$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!enroll_approve_csr!wf_id!' . $workflow_id
});

# load raw context to find certificate id
my $cert_identifier;
$result = $client->mock_request({
    'page' => 'workflow!context!wf_id!' . $workflow_id
});

foreach my $item (@{$result->{main}->[0]->{content}->{data}}) {
    $cert_identifier = $item->{value}->{label} if ($item->{label} eq 'cert_identifier');
}

ok($cert_identifier,'Cert Identifier found');
diag($cert_identifier);

# fetch cert with sscep
`$sscep enroll -u http://localhost/scep/scep -K tmp/pkiclient.key -O tmp/pkiclient.crt -r tmp/entity.csr -k tmp/entity.key -c tmp/cacert-0 -l tmp/entity.crt  -t 1 -n 1`;

ok(-e "tmp/entity.crt", "Cert exists");

open(CERT, ">tmp/entity.id");
print CERT $cert_identifier;
close CERT;

