#!/usr/bin/perl

use FindBin qw( $Bin );
use lib "$Bin/../../lib";

use strict;
use warnings;
use CGI::Session;
use JSON;
use English;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use MockUI;

use Cwd 'abs_path';
use File::Basename;

# We expect error messages but hide them unless we're in verbose testing
Log::Log4perl->easy_init($ENV{TEST_VERBOSE} ? $ERROR : $OFF);

use Test::More tests => 6;

package main;

BEGIN {
    use_ok( 'OpenXPKI::Client::UI' );
}

require_ok( 'OpenXPKI::Client::UI' );

my $result;
my $client = MockUI::factory();
my $openssl_conf = dirname(abs_path($0)).'/openssl.cnf';

$result = $client->mock_request({
    'page' => 'workflow!index!wf_type!certificate_signing_request_v2',
});

is($result->{main}->[0]->{content}->{fields}->[2]->{name}, 'wf_token');

$result = $client->mock_request({
    'action' => 'workflow!index',
    'wf_token' => undef,
    'cert_profile' => 'I18N_OPENXPKI_PROFILE_TLS_SERVER',
    'cert_subject_style' => '00_basic_style'
});

like($result->{goto}, qr/workflow!load!wf_id!\d+/, 'Got redirect');

my ($wf_id) = $result->{goto} =~ /workflow!load!wf_id!(\d+)/;

note("Workflow Id is $wf_id");

$result = $client->mock_request({
    'page' => $result->{goto},
});

$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!csr_upload_pkcs10!wf_id!'.$wf_id,
});

# Create a pkcs10
my $pkcs10 = `openssl req -new -subj "/DC=org/DC=OpenXPKI/DC=Test Deployment/CN=www.example.com" -config $openssl_conf -newkey rsa:512 -nodes -keyout /dev/null 2>/dev/null`;

$result = $client->mock_request({
    'action' => 'workflow!index',
    'pkcs10' => $pkcs10,
    'csr_type' => 'pkcs10',
    'wf_token' => undef
});

is ($result->{status}->{level}, 'error', 'Status is error');

is ($result->{status}->{message}, 'I18N_OPENXPKI_UI_VALIDATOR_KEY_PARAM_PARAM_NOT_ALLOWED (key_length)', 'Key Param error');



