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


plan tests => 18;


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

$wf->start_activity('crr_submit');
$wf->state_is('PENDING');

$wf->execute_fails('crr_approve_crr' => {}, qr/no access.*crr_approve_crr/i);


# set current user to: operator
$wf->change_user("raop");

$wf->start_activity('crr_update_crr', { reason_code => 'keyCompromise' });
$wf->state_is('PENDING');

$wf->start_activity('crr_reject_crr');
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
    $wf->refresh;
    $i++;
} while($wf->state ne 'CHECK_FOR_REVOCATION' && $i < 30);
$wf->state_is('CHECK_FOR_REVOCATION');

