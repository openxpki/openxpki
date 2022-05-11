#!/usr/bin/perl

use lib qw(../lib);
use strict;
use warnings;
use JSON;
use English;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use TestCGI;

use Test::More tests => 2;

package main;

my $result;
my $client = TestCGI::factory('democa', 0);

# create temp dir
-d "tmp/" || mkdir "tmp/";

$result = $client->mock_request({
    'page' => 'workflow!index!wf_type!certificate_signing_request_v2',
});

is $result->{main}->[0]->{content}->{fields}->[2]->{name}, 'wf_token'
    or diag explain $result;

$result = $client->mock_request({
    'action' => 'workflow!index',
    'wf_token' => undef,
    'cert_profile' => 'tls_client',
    'cert_subject_style' => '00_basic_style'
});

like($result->{goto}, qr/workflow!load!wf_id!\d+/, 'Got redirect');

my ($wf_id) = $result->{goto} =~ /workflow!load!wf_id!(\d+)/;

note "Workflow Id is $wf_id";

$result = $client->mock_request({
    'page' => $result->{goto},
});

$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!csr_upload_pkcs10!wf_id!'.$wf_id,
});

# Create the pkcs10
my $pkcs10 = `openssl req -new -newkey rsa:3000 -subj "/CN=testbox.openxpki.org:pkiclient" -nodes -keyout tmp/pkiclient.key 2>/dev/null`;

$client->run_action('workflow' => {
    'pkcs10' => $pkcs10,
    'csr_type' => 'pkcs10',
});

$client->run_action('workflow', {
    'action' => 'workflow!index',
    'cert_subject_parts{hostname}' => 'testbox.openxpki.org',
    'cert_subject_parts{application_name}' => 'pkiclient',
});

$client->run_action('workflow', {
    'cert_info{requestor_email}' => 'test@openxpki.local',
});

$client->approve_csr($wf_id);

$client = TestCGI::factory('democa');

$result = $client->mock_request({
    page => 'workflow!load!wf_id!' . $wf_id
});

my $cert_identifier = $client->approve_csr($wf_id)
  or BAIL_OUT('Could not retrieve certificate ID: '.Dumper($client->last_result));

# Download the certificate
$result = $client->mock_request({
     'page' => 'certificate!download!format!pem!identifier!'.$cert_identifier
});

open(CERT, ">tmp/pkiclient.id");
print CERT $cert_identifier;
close CERT;

open(CERT, ">tmp/pkiclient.crt");
print CERT $result ;
close CERT;

