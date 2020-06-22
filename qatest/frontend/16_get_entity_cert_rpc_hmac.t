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
use LWP::UserAgent;

use Test::More tests => 10;

package main;

my $result;
my $client = TestCGI::factory('democa');

my $sscep = -e "./sscep" ? './sscep' : 'sscep';

`$sscep getca -c tmp/cacert -u http://localhost/scep/scep`;

ok((-s "tmp/cacert-0"),'CA certs present') || die;

# Chain for TLS based requests later
`cat tmp/cacert-* > tmp/chain.pem`;

# Create the pkcs10
`openssl req -new -subj "/CN=entity-hmac-test.openxpki.org" -nodes -keyout tmp/entity-hmac.key -out tmp/entity-hmac.csr 2>/dev/null`;

ok((-s "tmp/entity-hmac.csr"), 'csr present') || die;

my $pkcs10 = `cat tmp/entity-hmac.csr`;
my $pem = $pkcs10;
$pem =~ s/-----(BEGIN|END)[^-]+-----//g;
$pem =~ s/\s//xmsg;
my $hmac = hmac_sha256_hex(decode_base64($pem), 'verysecret');

my $ua = LWP::UserAgent->new();
$ua->ssl_opts( verify_hostname => 0,
SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE );

my $req = HTTP::Request->new('POST', 'https://localhost/rpc/request/RequestCertificate',
    HTTP::Headers->new( Content_Type => 'application/json'),
    encode_json({ pkcs10 => $pkcs10, hmac => $hmac })
);

my $response = $ua->request( $req );

ok($response->is_success);
my $json = JSON->new->decode($response->decoded_content);

is ($json->{result}->{data}->{error_code}, 'I18N_OPENXPKI_UI_ENROLLMENT_ERROR_NOT_APPROVED');

# Log in and approve request
$result = $client->mock_request({
    'action' => 'workflow!search',
    'wf_creator' => '',
    'wf_proc_state' => '',
    'wf_state' => '',
    'wf_type' => 'certificate_enroll',
    'transaction_id[]' =>  $json->{result}->{transaction_id},
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

is($client->get_field_from_result('hmac'), $hmac);
ok($client->get_field_from_result('is_valid_hmac'));

$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!enroll_reject_request!wf_id!' . $workflow_id,
});

is ($result->{right}->[0]->{content}->{data}->[3]->{value}, 'FAILURE', 'Status is FAILURE');
