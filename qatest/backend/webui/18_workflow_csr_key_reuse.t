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

#Log::Log4perl->easy_init($DEBUG);
Log::Log4perl->easy_init($ERROR);

use Test::More tests => 14;

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
my $pkcs10 = `openssl req -new -subj "/DC=org/DC=OpenXPKI/DC=Test Deployment/CN=www.example.com" -config $openssl_conf -nodes -keyout /dev/null 2>/dev/null`;

$result = $client->mock_request({
    'action' => 'workflow!index',
    'pkcs10' => $pkcs10,
    'csr_type' => 'pkcs10',
    'wf_token' => undef
});


# try to submit the request again
$result = $client->mock_request({
    'page' => 'workflow!index!wf_type!certificate_signing_request_v2',
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'wf_token' => undef,
    'cert_profile' => 'I18N_OPENXPKI_PROFILE_TLS_SERVER',
    'cert_subject_style' => '00_basic_style'
});

my ($wf_id_resubmit) = $result->{goto} =~ /workflow!load!wf_id!(\d+)/;

note("Workflow Id (Resubmit) is $wf_id_resubmit");

$result = $client->mock_request({
    'page' => $result->{goto},
});

$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!csr_upload_pkcs10!wf_id!'.$wf_id_resubmit,
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'pkcs10' => $pkcs10,
    'csr_type' => 'pkcs10',
    'wf_token' => undef
});

is($result->{right}->[0]->{content}->{data}->[2]->{value}, 'KEY_DUPLICATE_ERROR_WORKFLOW', 'Duplicate key (workflow)');

# load the old workflow
$result = $client->mock_request({
    'page' => 'workflow!load!wf_id!'.$wf_id,
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'cert_subject_parts{hostname}' => 'www.example.de',
    'cert_subject_parts{hostname2}[]' => ['www.example.com'],
    'wf_token' => undef
});


$result = $client->mock_request({
    'action' => 'workflow!index',
    'cert_san_parts{dns}[]' => $result->{main}->[0]->{content}->{fields}->[0]->{value},
    'wf_token' => undef
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'cert_info{requestor_email}' => 'noreply@example.com',
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

# certificate was issued, the duplicate key check should now end with a
# certificate error instead of a workflow error

$result = $client->mock_request({
    'page' => 'workflow!load!wf_id!'.$wf_id_resubmit,
});

$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!global_noop!wf_id!'.$wf_id_resubmit,
});

is($result->{right}->[0]->{content}->{data}->[2]->{value}, 'KEY_DUPLICATE_ERROR_CERTIFICATE', 'Duplicate key (certificate)');

# be ignorant, upload the request again
$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!csr_upload_pkcs10!wf_id!'.$wf_id_resubmit,
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'pkcs10' => $pkcs10,
    'csr_type' => 'pkcs10',
    'wf_token' => undef
});

is($result->{right}->[0]->{content}->{data}->[2]->{value}, 'KEY_DUPLICATE_ERROR_CERTIFICATE');

# Lesson learned, build new CSR
$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!csr_upload_pkcs10!wf_id!'.$wf_id_resubmit,
});

# Create a pkcs10
$pkcs10 = `openssl req -new -subj "/DC=org/DC=OpenXPKI/DC=Test Deployment/CN=www.example.com" -config $openssl_conf -nodes -keyout /dev/null 2>/dev/null`;

$result = $client->mock_request({
    'action' => 'workflow!index',
    'pkcs10' => $pkcs10,
    'csr_type' => 'pkcs10',
    'wf_token' => undef
});

is($result->{page}->{description}, 'I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_EDIT_SUBJECT_DESC');

$result = $client->mock_request({
    'action' => 'workflow!index',
    'cert_subject_parts{hostname}' => 'www.example.de',
    'cert_subject_parts{hostname2}[]' => ['www.example.com'],
    'wf_token' => undef
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'cert_san_parts{dns}[]' => $result->{main}->[0]->{content}->{fields}->[0]->{value},
    'wf_token' => undef
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'cert_info{requestor_email}' => 'noreply@example.com',
    'wf_token' => undef
});

$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!global_cancel!wf_id!'.$wf_id_resubmit,
});

is ($result->{page}->{description}, 'I18N_OPENXPKI_UI_WORKFLOW_STATE_CSR_CANCELED_DESC');

# Second test - try to cancel the first workflow and continue the second
note("Test with cancel first workflow option");

$result = $client->mock_request({
    'page' => 'workflow!index!wf_type!certificate_signing_request_v2',
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'wf_token' => undef,
    'cert_profile' => 'I18N_OPENXPKI_PROFILE_TLS_SERVER',
    'cert_subject_style' => '00_basic_style'
});

like($result->{goto}, qr/workflow!load!wf_id!\d+/, 'Got redirect');

($wf_id) = $result->{goto} =~ /workflow!load!wf_id!(\d+)/;

note("Workflow Id is $wf_id");

$result = $client->mock_request({
    'page' => $result->{goto},
});

$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!csr_upload_pkcs10!wf_id!'.$wf_id,
});

# Create a pkcs10
$pkcs10 = `openssl req -new -subj "/DC=org/DC=OpenXPKI/DC=Test Deployment/CN=www.example.com" -config $openssl_conf -nodes -keyout /dev/null 2>/dev/null`;

$result = $client->mock_request({
    'action' => 'workflow!index',
    'pkcs10' => $pkcs10,
    'csr_type' => 'pkcs10',
    'wf_token' => undef
});


# try to submit the request again
$result = $client->mock_request({
    'page' => 'workflow!index!wf_type!certificate_signing_request_v2',
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'wf_token' => undef,
    'cert_profile' => 'I18N_OPENXPKI_PROFILE_TLS_SERVER',
    'cert_subject_style' => '00_basic_style'
});

($wf_id_resubmit) = $result->{goto} =~ /workflow!load!wf_id!(\d+)/;

note("Workflow Id (Resubmit) is $wf_id_resubmit");

$result = $client->mock_request({
    'page' => $result->{goto},
});

$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!csr_upload_pkcs10!wf_id!'.$wf_id_resubmit,
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'pkcs10' => $pkcs10,
    'csr_type' => 'pkcs10',
    'wf_token' => undef
});

is($result->{right}->[0]->{content}->{data}->[2]->{value}, 'KEY_DUPLICATE_ERROR_WORKFLOW', 'Duplicate key (workflow)');

# load the old workflow
$result = $client->mock_request({
    'page' => 'workflow!load!wf_id!'.$wf_id,
});

# we need to complete the forms to cancel the old one
$result = $client->mock_request({
    'action' => 'workflow!index',
    'cert_subject_parts{hostname}' => 'www.example.de',
    'cert_subject_parts{hostname2}[]' => ['www.example.com'],
    'wf_token' => undef
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'cert_san_parts{dns}[]' => $result->{main}->[0]->{content}->{fields}->[0]->{value},
    'wf_token' => undef
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'cert_info{requestor_email}' => 'noreply@example.com',
    'wf_token' => undef
});

$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!global_cancel!wf_id!'.$wf_id,
});

# switch back to the second workflow

# load the old workflow
$result = $client->mock_request({
    'page' => 'workflow!load!wf_id!'.$wf_id_resubmit,
});

note("Do recheck");
$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!global_noop!wf_id!'.$wf_id_resubmit,
});

is($result->{page}->{description}, 'I18N_OPENXPKI_UI_WORKFLOW_ACTION_CSR_EDIT_SUBJECT_DESC');

$result = $client->mock_request({
    'action' => 'workflow!index',
    'cert_subject_parts{hostname}' => 'www.example.de',
    'cert_subject_parts{hostname2}[]' => ['www.example.com'],
    'wf_token' => undef
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'cert_san_parts{dns}[]' => $result->{main}->[0]->{content}->{fields}->[0]->{value},
    'wf_token' => undef
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'cert_info{requestor_email}' => 'noreply@example.com',
    'wf_token' => undef
});

$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!global_cancel!wf_id!'.$wf_id_resubmit,
});

is ($result->{page}->{description}, 'I18N_OPENXPKI_UI_WORKFLOW_STATE_CSR_CANCELED_DESC');
