#!/usr/bin/perl

use lib qw(../lib);
use strict;
use warnings;
use JSON;
use English;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use TestCGI;
use MIME::Base64;
use Crypt::X509;

use Test::More tests => 3;

package main;

my $result;
my $client = TestCGI::factory('democa');

# create temp dir
-d "/tmp/oxi-test/" || mkdir "/tmp/oxi-test/";

$result = $client->mock_request({
    'page' => 'workflow!index!wf_type!certificate_signing_request_v2',
});

is($result->{main}->[0]->{content}->{fields}->[2]->{name}, 'wf_token');

$result = $client->mock_request({
    'action' => 'workflow!index',
    'wf_token' => undef,
    'cert_profile' => 'tls_server',
    'cert_subject_style' => '05_advanced_style'
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
my $pkcs10 = `openssl req -new -subj "/CN=testbox.openxpki.org" -nodes -keyout /dev/null 2>/dev/null`;

$result = $client->mock_request({
    'action' => 'workflow!index',
    'pkcs10' => $pkcs10,
    'wf_token' => undef
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'cert_subject_parts{CN}' => 'testbox.openxpki.org',
    'cert_subject_parts{OU}' => ['PKI','OpenXPKI'],
    'cert_subject_parts{C}' => 'DE',
    'wf_token' => undef
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'cert_san_parts{ip}' => [ '127.0.0.1' ],
    'cert_san_parts{dns}' => [ 'testbox.openxpki.com','testbox.openxpki.net' ],
    'wf_token' => undef
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'cert_info{requestor_email}' => 'test@openxpki.local',
    'wf_token' => undef
});

my $cert_identifier = $client->approve_csr($wf_id);

# Download the certificate
$result = $client->mock_request({
     'page' => 'certificate!download!format!pem!identifier!'.$cert_identifier
});

open(CERT, ">/tmp/oxi-test/entity12a.id");
print CERT $cert_identifier;
close CERT;

open(CERT, ">/tmp/oxi-test/entity12a.crt");
print CERT $result ;
close CERT;

if ($result =~ m{-----BEGIN[^-]*CERTIFICATE-----(.+)-----END[^-]*CERTIFICATE-----}xms) {
    my $x509 = new Crypt::X509( cert => decode_base64($1) );
    # ipaddress is a binary value and stringified in the crypt::x509 class so we can not check this easily
    like(join(',', sort @{$x509->SubjectAltName()}),'/dNSName=testbox.openxpki.com,dNSName=testbox.openxpki.net,iPAddress=/');
}
