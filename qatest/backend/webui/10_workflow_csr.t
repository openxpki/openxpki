#!/usr/bin/perl

use FindBin qw( $Bin );
use lib "$Bin/../../lib";

use Cwd 'abs_path';
use File::Basename;

use strict;
use warnings;
use CGI::Session;
use JSON;
use English;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use MockUI;

#Log::Log4perl->easy_init($DEBUG);
Log::Log4perl->easy_init($ERROR);

use Test::More tests => 5;

package main;

BEGIN {
    use_ok( 'OpenXPKI::Client::Service::WebUI' );
}

require_ok( 'OpenXPKI::Client::Service::WebUI' );

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
    'cert_profile' => 'tls_server',
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
my $pkcs10 = `openssl req -new -subj "/DC=org/DC=OpenXPKI/DC=Test Deployment/CN=www.example.com" -config $openssl_conf -nodes -keyout /dev/null 2>/dev/null`;

$result = $client->mock_request({
    'action' => 'workflow!index',
    'pkcs10' => $pkcs10,
    'csr_type' => 'pkcs10',
    'wf_token' => undef
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'cert_subject_parts{hostname}' => 'www.example.de',
    'cert_subject_parts{hostname2}[]' => ['www.example.com'],
    'wf_token' => undef
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'cert_info{requestor_email}' => 'mail@oliwel.de',
    'wf_token' => undef
});

# Use submit or policy violation depending on current status
if ($result->{main}->[0]->{content}->{buttons}->[0]->{action} =~ /csr_submit/) {
    $result = $client->mock_request({
        'action' => 'workflow!select!wf_action!csr_submit!wf_id!' . $wf_id
    });
} else {
    $result = $client->mock_request({
        'action' => 'workflow!select!wf_action!csr_enter_policy_violation_comment!wf_id!' . $wf_id
    });

    $result = $client->mock_request({
        'action' => 'workflow!index',
        'policy_comment' => 'Reason for Exception',
        'wf_token' => undef
    });
}

$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!csr_approve_csr!wf_id!' . $wf_id,
});

is ($result->{status}->{level}, 'success', 'Status is success');

my $cert_identifier = $result->{main}->[0]->{content}->{data}->[0]->{value}->{label};
$cert_identifier =~ s{ <.* \z }{}xms;
open(CERT, ">/tmp/webui.json");
print CERT JSON->new->encode({ cert_identifier => $cert_identifier  });
close CERT;

