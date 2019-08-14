#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;

# Project modules
use lib $Bin, "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;


plan tests => 25;


#
# Init helpers
#
my $oxitest = OpenXPKI::Test->new(
    with => [qw( SampleConfig Workflows WorkflowCreateCert )],
    #log_level => 'debug',
);
my $cert = $oxitest->create_cert(
    profile => "I18N_OPENXPKI_PROFILE_TLS_SERVER",
    hostname => "fun",
    requestor_gname => 'Sarah',
    requestor_name => 'Dessert',
    requestor_email => 'sahar@d-sert.d',
);
my $cert_id = $cert->{identifier};

#
# Test auto-approval request
#
my $wfparam = {
    cert_identifier => $cert_id,
    reason_code => 'unspecified',
    comment => 'Automated Test',
    flag_auto_approval => 0,
    flag_batch_mode => 0
};

my $wf;
lives_ok {
    $wf = $oxitest->create_workflow('certificate_revocation_request_v2' => $wfparam, 1);
} "Create CRR workflow";

$wf->state_is('PENDING_USER');

$wf->execute('crr_submit');
$wf->state_is('PENDING');

$wf->execute_fails('crr_approve_crr' => {}, qr/no access.*crr_approve_crr/i);


# set current user to: operator
$oxitest->set_user('democa' => 'raop');

$wf->execute('crr_update_crr', { reason_code => 'keyCompromise' });
$wf->state_is('PENDING');

$wf->execute('crr_reject_crr');
$wf->state_is('REJECTED');

#
# Test delayed revocation
#
$wfparam->{flag_auto_approval} = 1;
$wfparam->{delay_revocation_time} = time() + 5;
$wfparam->{flag_batch_mode} = 1;

lives_ok {
    $wf = $oxitest->create_workflow('certificate_revocation_request_v2' => $wfparam, 1);
} "Create delayed CRR workflow";

$wf->state_is('CHECK_FOR_DELAYED_REVOKE');
my $delayed_revoke_id = $wf->id;

#
# Test auto revocation
#
delete $wfparam->{delay_revocation_time};
$wfparam->{flag_auto_approval} = 1;
$wfparam->{flag_batch_mode} = 1;
$wfparam->{invalidity_time} = time();

lives_ok {
    $wf = $oxitest->create_workflow('certificate_revocation_request_v2' => $wfparam, 1);
} "Create auto-revoke CRR workflow";

# Go to pending
$wf->state_is('CHECK_FOR_REVOCATION');

# Do a second test - should go to success as already approved
$wf->{flag_auto_approval} = 0;

lives_ok {
    $wf = $oxitest->create_workflow('certificate_revocation_request_v2' => $wfparam, 1);
} "Create auto-revoke CRR workflow";

$wf->state_is('CHECK_FOR_REVOCATION');

#
# Finally, check if the delayed workflow has finished
#
lives_ok {
    $wf = $oxitest->fetch_workflow($delayed_revoke_id, 1);
} "Switch back to existing delayed workflow";

my $i = 0;
do {
    sleep 1;
    $wf->metadata;
    $i++;
} while($wf->state ne 'CHECK_FOR_REVOCATION' && $i < 30);
$wf->state_is('CHECK_FOR_REVOCATION');

#
# CRL
#
lives_ok {
    $wf = $oxitest->create_workflow('crl_issuance' => { force_issue => 1 }, 1);
} "Create CRL workflow";
$wf->state_is('SUCCESS');

# Fetch the most recent crl, pem
my $crl_pem = $oxitest->api_command('get_crl' => { FORMAT => 'PEM' });
like $crl_pem, qr/----BEGIN X509 CRL-----/, 'Fetch CRL (PEM)';

# test crl der format
my $crl_der = $oxitest->api_command('get_crl' => { FORMAT => 'DER' });
like $crl_der, qr/.+/, 'Fetch CRL (DER)';

my $tempdir = $oxitest->testenv_root;
open my $fh, ">", "$tempdir/crl.pem" or BAIL_OUT "Error creating temporary file $tempdir/crl.pem";
print $fh $crl_der and close $fh;

$ENV{OPENSSL_CONF} = "/dev/null"; # prevents "WARNING: can't open config file: ..."
my $crl_info = `openssl crl -in "$tempdir/crl.pem" -inform DER -noout 2>&1`;
is $crl_info, "", "No complaints about DER by OpenSSL";

#
# Waking up workflow in state CHECK_FOR_REVOCATION
#
lives_ok {
    $wf = $oxitest->fetch_workflow($delayed_revoke_id, 1);
} "Switch back to existing delayed workflow";

if ($wf->state eq 'CHECK_FOR_REVOCATION') {
    $oxitest->api_command('wakeup_workflow' => { ID => $delayed_revoke_id });
    $i = 0;
    do { sleep 1; $wf->metadata; } while ($wf->state ne 'SUCCESS' && $i++ < 10);
    is $wf->state, 'SUCCESS', "Wake up and finish CRR workflow";
}
else {
    is $wf->state, 'SUCCESS', "Finish CRR workflow";
}
