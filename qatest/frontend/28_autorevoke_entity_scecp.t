#!/usr/bin/perl

use lib qw(../lib);
use strict;
use warnings;
use JSON;
use English;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use TestCGI;
use Digest::SHA qw(sha1_base64);

use Test::More tests => 8;

package main;

my $result;
my $client = TestCGI::factory('democa');

my $sscep = -e "./sscep" ? './sscep' : 'sscep';

SKIP: { skip 'sscep not available', 8 unless -e $sscep;

# Generate new CSR
`openssl req -new -subj "/DC=org/DC=OpenXPKI/DC=Test Deployment/CN=entity.openxpki.org" -nodes -keyout tmp/entity3.key -out tmp/entity3.csr 2>/dev/null`;

ok((-s "tmp/entity3.csr"), 'csr present') || die;

`rm -f tmp/entity3.crt`;

# initial request
my $scep = `$sscep enroll -v -u http://localhost/scep/scep  -r tmp/entity3.csr -k tmp/entity3.key -c tmp/cacert-0 -l tmp/entity3.crt -t 1 -n 1 |  grep "Read request with transaction id"`;

my @t = split(/:\s+/, $scep);
my $sceptid = $t[2];

diag("Transaction Id: $sceptid");

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

is($result->{main}->[0]->{content}->{data}->[0]->[3], 'MANUAL_AUTHORIZATION');

$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!enroll_accept_request!wf_id!' . $workflow_id,
    'wf_token' => undef,
});

is($result->{right}->[0]->{content}->{data}->[3]->{value},'PENDING');

$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!enroll_approve_csr!wf_id!' . $workflow_id,
    'wf_token' => undef,
});

# load raw context to find certificate id
$result = $client->mock_request({
    'page' => 'workflow!context!wf_id!' . $workflow_id
});

ok($client->get_field_from_result('check_policy_subject_duplicate'));
ok($client->get_field_from_result('revocation_workflow_id'));

`$sscep enroll -u http://localhost/scep/scep  -r tmp/entity3.csr -k tmp/entity3.key -c tmp/cacert-0 -l tmp/entity3.crt -t 1 -n 1`;

ok(-s "tmp/entity3.crt", "new cert exists");

my $data = `openssl  x509 -in tmp/entity3.crt -outform der`;
my $cert_identifier = sha1_base64($data);
$cert_identifier =~ tr/+\//-_/;

diag('Cert Identifier '  . $cert_identifier);

open(CERT, ">tmp/entity3.id");
print CERT $cert_identifier;
close CERT;

}
