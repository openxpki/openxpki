#!/usr/bin/perl

use lib qw(../lib);
use strict;
use warnings;
use JSON;
use English;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use TestCGI;

use Test::More tests => 19;

package main;

my $result;
my $client = TestCGI::factory();

# create temp dir
-d "tmp/" || mkdir "tmp/";

$result = $client->mock_request({
    'page' => 'workflow!index!wf_type!certificate_signing_request_v2',
});

is($result->{main}->[0]->{content}->{fields}->[2]->{name}, 'wf_token');

$result = $client->mock_request({
    'action' => 'workflow!index',
    'wf_token' => undef,
    'cert_profile' => 'I18N_OPENXPKI_PROFILE_TLS_CLIENT',
    'cert_subject_style' => '00_basic_style'
});

like($result->{goto}, qr/workflow!load!wf_id!\d+/, 'Got redirect');

my ($wf_id) = $result->{goto} =~ /workflow!load!wf_id!(\d+)/;

diag("Workflow Id is $wf_id");

$result = $client->mock_request({
    'page' => $result->{goto},
});

$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!csr_upload_pkcs10!wf_id!'.$wf_id,
});

# Create the pkcs10 - rsa 512
my $pkcs10 = `openssl req -new -subj "/CN=testbox.openxpki.org" -nodes -keyout /dev/null -newkey rsa:512 2>/dev/null`;

$result = $client->mock_request({
    'action' => 'workflow!index',
    'pkcs10' => $pkcs10,
    'csr_type' => 'pkcs10',
    'wf_token' => undef
});

is($result->{status}->{level}, 'error');
is($result->{status}->{message}, 'Used key parameter is not allowed by policy (key_length)');

# ECC Key with bad curves
for my $curve (qw(secp192r1 secp256k1 prime192v1)) {

    -e "tmp/ecckey.pem" && unlink "tmp/ecckey.pem";
    `openssl ecparam -name $curve -genkey -noout -out tmp/ecckey.pem`;
    ok(-e "tmp/ecckey.pem");

    $pkcs10 = `openssl req -new -subj "/CN=testbox.openxpki.org" -nodes -key tmp/ecckey.pem 2>/dev/null`;

    $result = $client->mock_request({
        'action' => 'workflow!index',
        'pkcs10' => $pkcs10,
        'csr_type' => 'pkcs10',
        'wf_token' => undef
    });

    is($result->{status}->{level}, 'error');
    is($result->{status}->{message}, 'Used key parameter is not allowed by policy (curve_name)');

}

# force failure
$result = $client->mock_request({
    'action' => $result->{right}->[0]->{buttons}->[0]->{action},
    'wf_token' => undef
});

# ECC with supported curve
for my $curve (qw(secp256r1 prime256v1)) {

    -e "tmp/ecckey.pem" && unlink "tmp/ecckey.pem";
    `openssl ecparam -name $curve -genkey -noout -out tmp/ecckey.pem`;
    ok(-e "tmp/ecckey.pem");

    $pkcs10 = `openssl req -new -subj "/CN=testbox.openxpki.org" -nodes -key tmp/ecckey.pem 2>/dev/null`;

    $result = $client->mock_request({
        'page' => 'workflow!index!wf_type!certificate_signing_request_v2',
    });

    is($result->{main}->[0]->{content}->{fields}->[2]->{name}, 'wf_token');

    $result = $client->mock_request({
        'action' => 'workflow!index',
        'wf_token' => undef,
        'cert_profile' => 'I18N_OPENXPKI_PROFILE_TLS_CLIENT',
        'cert_subject_style' => '00_basic_style'
    });

    ($wf_id) = $result->{goto} =~ /workflow!load!wf_id!(\d+)/;

    $result = $client->mock_request({
        'page' => $result->{goto},
    });

    $result = $client->mock_request({
        'action' => 'workflow!select!wf_action!csr_upload_pkcs10!wf_id!'.$wf_id,
    });

    $result = $client->mock_request({
        'action' => 'workflow!index',
        'pkcs10' => $pkcs10,
        'csr_type' => 'pkcs10',
        'wf_token' => undef
    });

    is($result->{page}->{label}, 'Edit Subject / Certificate Signing Request (CSR)');

    # force failure
    $result = $client->mock_request({
        'action' => $result->{main}->[0]->{buttons}->[0]->{action},
        'wf_token' => undef
    });

}

