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
use utf8;

#Log::Log4perl->easy_init($DEBUG);
Log::Log4perl->easy_init($ERROR);

use Test::More tests => 6;

package main;

BEGIN {
    use_ok( 'OpenXPKI::Client::Service::WebUI' );
}

require_ok( 'OpenXPKI::Client::Service::WebUI' );

my $log = Log::Log4perl->get_logger();

my $session = CGI::Session->new(undef, undef, {Directory=>'/tmp'});
my $session_id = $session->id;
ok ($session->id, 'Session id ok');


my $result;
my $client = MockUI::factory();

$result = $client->mock_request({
    'page' => 'workflow!index!wf_type!certificate_signing_request_v2',
});

is($result->{main}->[0]->{content}->{fields}->[2]->{name}, 'wf_token');

$result = $client->mock_request({
    'action' => 'workflow!index',
    'wf_token' => undef,
    'cert_profile' => 'user_auth_enc',
    'cert_subject_style' => '00_user_basic_style'
});

like($result->{goto}, qr/workflow!load!wf_id!\d+/, 'Got redirect');

my ($wf_id) = $result->{goto} =~ /workflow!load!wf_id!(\d+)/;

note("Workflow Id is $wf_id");

$result = $client->mock_request({
    'page' => $result->{goto},
});

$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!csr_provide_server_key_params!wf_id!'.$wf_id,
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'key_alg' => 'ec',
    'enc_alg' => 'aes256',
    'key_gen_params{CURVE_NAME}' => 'prime256v1',
    'csr_type' => 'pkcs10',
    'password_type' => 'client',
    'wf_token' => undef
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'cert_subject_parts{username}' => 'openxpki',
    'cert_subject_parts{realname}' => 'Thomas Tester',
    'cert_subject_parts{email}' => 'test@openxpki.org',
    'wf_token' => undef
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'wf_token' => undef
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'cert_info{comment}' => '-',
    'wf_token' => undef
});

$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!csr_submit!wf_id!' . $wf_id,
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    '_password' => 'Rg89T2ekApsV',
    'wf_token' => undef
});

$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!csr_approve_csr!wf_id!' . $wf_id,
});

is ($result->{status}->{level}, 'success', 'Status is success');

