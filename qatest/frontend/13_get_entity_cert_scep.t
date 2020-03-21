#!/usr/bin/perl

use lib qw(../lib);
use strict;
use warnings;
use JSON;
use English;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use TestCGI;

use Test::More tests => 12;

package main;

my $result;
my $client = TestCGI::factory('democa');

my $sscep = -e "./sscep" ? './sscep' : 'sscep';

`$sscep getca -c tmp/cacert -u http://localhost/scep/scep`;

ok((-s "tmp/cacert-0"),'CA certs present') || die;

# Chain for TLS based requests later
`cat tmp/cacert-* > tmp/chain.pem`;
`rm -f tmp/entity.*`;


# Create the pkcs10
`openssl req -new -nodes -keyout tmp/entity.key -out tmp/entity.csr -subj "/O=TestMe" -config openssl.conf 2>/dev/null`;

ok((-s "tmp/entity.csr"), 'csr present') || die;

# do on behalf request with pkiclient certificate
my $scep = `$sscep enroll -v -u http://localhost/scep/scep -M custid=12345 -K tmp/pkiclient.key -O tmp/pkiclient.crt -r tmp/entity.csr -k tmp/entity.key -c tmp/cacert-0 -l tmp/entity.crt  -t 1 -n 1 |  grep "Read request with transaction id"`;

ok((! -e "tmp/entity.crt"), 'No certificate issued');

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

is ($result->{main}->[0]->{content}->{data}->[0]->[3], 'FAILURE', 'FAILED');

$result = $client->mock_request({
    'page' => 'workflow!history!wf_id!' . $workflow_id
});

is($result->{main}->[0]->{content}->{data}->[-1]->[2], 'global_set_error_invalid_subject', 'broken subject');

# Create the pkcs10
`openssl req -new -nodes -keyout tmp/entity.key -out tmp/entity.csr -subj "/CN=entity.openxpki.org" -config openssl.conf -reqexts req_template_v1 2>/dev/null`;

ok((-s "tmp/entity.csr"), 'csr present') || die;

# do on behalf request with pkiclient certificate
$scep = `$sscep enroll -v -u http://localhost/scep/scep -M custid=12345 -K tmp/pkiclient.key -O tmp/pkiclient.crt -r tmp/entity.csr -k tmp/entity.key -c tmp/cacert-0 -l tmp/entity.crt  -t 1 -n 1 |  grep "Read request with transaction id"`;

@t = split(/:\s+/, $scep);
$sceptid = $t[2];

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

$workflow_id = $result->{main}->[0]->{content}->{data}->[0]->[0];
diag('Found workflow ' . $workflow_id );

$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!enroll_approve_csr!wf_id!' . $workflow_id
});

$result = $client->mock_request({
    'page' => 'workflow!context!wf_id!' . $workflow_id
});

my $cert_identifier = $client->get_field_from_result('cert_identifier');

if (ref $cert_identifier) { $cert_identifier = $cert_identifier->{label}; }

ok($cert_identifier,'Cert Identifier found');
diag($cert_identifier);

# fetch cert with sscep
`$sscep enroll -u http://localhost/scep/scep -K tmp/pkiclient.key -O tmp/pkiclient.crt -r tmp/entity.csr -k tmp/entity.key -c tmp/cacert-0 -l tmp/entity.crt  -t 1 -n 1`;

ok(-e "tmp/entity.crt", "Cert exists");

open(CERT, ">tmp/entity.id");
print CERT $cert_identifier;
close CERT;

