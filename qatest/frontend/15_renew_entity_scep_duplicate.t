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

use Test::More tests => 7;

package main;

my $result;
my $client = TestCGI::factory('democa');

my $sscep = -e "./sscep" ? './sscep' : 'sscep';

ok((-s "tmp/entity.crt"),'Old cert present') || die;

# Generate new CSR
`openssl req -new -subj "/DC=org/DC=OpenXPKI/DC=Test Deployment/CN=entity.openxpki.org" -nodes -keyout tmp/entity4.key -out tmp/entity4.csr 2>/dev/null`;

ok((-s "tmp/entity4.csr"), 'csr present') || die;

`rm -f tmp/entity4.crt`;

# do on behalf request with old certificate
my $scep = `$sscep enroll -v -u http://localhost/scep/scep -K tmp/entity2.key -O tmp/entity2.crt -r tmp/entity4.csr -k tmp/entity4.key -c tmp/cacert-0 -l tmp/entity4.crt -t 1 -n 1 |  grep "Read request with transaction id"`;

ok(! -s "tmp/entity4.crt", "Renewed cert not exists");

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
    'transaction_id[]' => $sceptid,
});

ok($result->{goto});
like($result->{goto}, "/workflow!result!id/");

$result = $client->mock_request({
    page => $result->{goto},
});

my $workflow_id = $result->{main}->[0]->{content}->{data}->[0]->[0];
diag('Found workflow ' . $workflow_id );

# load raw context to find certificate id
$result = $client->mock_request({
    'page' => 'workflow!context!wf_id!' . $workflow_id
});

like($client->get_field_from_result('error_code'), "/Policy failed/");
ok($client->get_field_from_result('check_policy_subject_duplicate'));

$client->fail_workflow($workflow_id);
