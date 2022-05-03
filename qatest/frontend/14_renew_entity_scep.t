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

use Test::More tests => 9;

package main;

my $result;
my $client = TestCGI::factory('democa');

my $sscep = -e "./sscep" ? './sscep' : 'sscep';

SKIP: { skip 'sscep not available', 9 unless -e $sscep;

ok((-s "tmp/entity.crt"),'Old cert present') || die;

# Generate new CSR
`openssl req -new -subj "/DC=org/DC=OpenXPKI/DC=Test Deployment/CN=entity.openxpki.org" -nodes -keyout tmp/entity2.key -out tmp/entity2.csr 2>/dev/null`;

ok((-s "tmp/entity.csr"), 'csr present') || die;

`rm -f tmp/entity2.crt`;

# do on behalf request with old certificate
my $scep = `$sscep enroll -v -u http://localhost/scep/scep -K tmp/entity.key -O tmp/entity.crt -r tmp/entity2.csr -k tmp/entity2.key -c tmp/cacert-0 -l tmp/entity2.crt -t 1 -n 1 |  grep "Read request with transaction id"`;

ok(-s "tmp/entity2.crt", "Renewed cert exists");

my $data = `openssl  x509 -in tmp/entity2.crt -outform der`;
my $cert_identifier = sha1_base64($data);
$cert_identifier =~ tr/+\//-_/;

diag('Cert Identifier '  . $cert_identifier);

open(CERT, ">tmp/entity2.id");
print CERT $cert_identifier;
close CERT;

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

$result = $client->mock_request({
    page => $result->{goto},
});

# load raw context to find certificate id
$result = $client->mock_request({
    'page' => 'workflow!context!wf_id!' . $workflow_id
});

is($client->get_field_from_result('is_replace'), 1);
ok($client->get_field_from_result('notafter'));
ok($client->get_field_from_result('revocation_workflow_id'));

is(`openssl  x509 -noout -enddate -in tmp/entity.crt`, `openssl  x509 -noout -enddate -in tmp/entity2.crt`, 'Notafter matches');

}
