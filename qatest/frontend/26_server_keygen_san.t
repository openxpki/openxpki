#!/usr/bin/perl


use FindBin qw( $Bin );
use lib "$Bin/../lib";
use strict;
use warnings;
use JSON;
use English;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use TestCGI;
use MIME::Base64;

use Test::More tests => 5;

package main;

my $result;
my $client = TestCGI::factory('democa');

# create temp dir
-d "/tmp/oxi-test/" || mkdir "/tmp/oxi-test/";

$result = $client->mock_request({
    'page' => 'workflow!index!wf_type!certificate_signing_request_v2',
});

is $client->has_field('wf_token'), 1, 'field "wf_token" present';

$result = $client->run_action('workflow', {
    'cert_profile' => 'tls_server',
    'cert_subject_style' => '00_basic_style',
});

like($result->{goto}, qr/workflow!load!wf_id!\d+/, 'Got redirect');
my ($wf_id) = $result->{goto} =~ /workflow!load!wf_id!(\d+)/;
note "Workflow Id is $wf_id";

$client->mock_request({
    'page' => $result->{goto},
});

$client->run_action('csr_provide_server_key_params');

$client->run_action('workflow', {
    'key_alg' => 'rsa',
    'enc_alg' => 'aes256',
    'key_gen_params{KEY_LENGTH}' => 2048,
    'password_type' => 'server',
});

$client->run_action('workflow', {
    'cert_subject_parts{hostname}' => 'testbox.openxpki.org',
    'cert_subject_parts{application_name}' => 'pkitest',
    'cert_subject_parts{hostname2}' => [ 'testbox.openxpki.org' ],
});

$client->run_action('workflow');
$client->run_action('csr_enter_policy_violation_comment');

if ($client->has_field('policy_comment')) {
    $client->run_action('workflow', { 'policy_comment' => 'Testing' });
}

my $data = $client->prefill_from_result();
my $password = $data->{'_password'};
note "Password is $password";

$client->run_action('workflow', { '_password' => $password });
my $cert_identifier = $client->approve_csr();

# Download the certificate
$result = $client->mock_request({
     'page' => 'workflow!index!wf_type!show_metadata',
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'cert_identifier' => $cert_identifier,
    'wf_token' => undef,
});

# Download the certificate
$result = $client->mock_request({
     'page' => 'workflow!index!wf_type!certificate_privkey_export',
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'key_format' => 'PKCS12',
    'cert_identifier' => $cert_identifier,
    '_password' => $password,
    'unencrypted' => 1,
    'wf_token' => undef
});

is($result->{main}->[0]->{content}->{data}->[2]->{name}, '_download');
is($result->{main}->[0]->{content}->{data}->[2]->{value}->{mimetype}, 'application/x-pkcs12');

open(CERT, ">/tmp/oxi-test/entity26a.id");
print CERT $cert_identifier;
close CERT;

open(CERT, ">/tmp/oxi-test/entity26a.p12");
print CERT decode_base64($result->{main}->[0]->{content}->{data}->[2]->{value}->{data});
close CERT;

open(CERT, ">/tmp/oxi-test/entity26a.pass");
print CERT $password ;
close CERT;

my $rc = system("openssl pkcs12 -in  /tmp/oxi-test/entity26a.p12 -nodes -passin pass:'' -out /dev/null");
is($rc,0);