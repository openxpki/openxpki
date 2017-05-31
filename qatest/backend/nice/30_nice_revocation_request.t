#!/usr/bin/perl
#
# 045_activity_tools.t
#
# Tests misc workflow tools like WFObject, etc.
#
# Note: these tests are non-destructive. They create their own instance
# of the tools workflow, which is exclusively for such test purposes.

use strict;
use warnings;

use FindBin qw( $Bin );
use lib "$Bin/../../lib";

use Carp;
use English;
use Data::Dumper;
use Config::Std;
use File::Basename;

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);

use OpenXPKI::Test::More;
use Test::More;
use TestCfg;

my $dirname = dirname($0);

our @cfgpath = ( $dirname );
our %cfg = ();

my $testcfg = new TestCfg;
$testcfg->read_config_path( '9x_nice.cfg', \%cfg, @cfgpath );

my $test = OpenXPKI::Test::More->new(
    {
        socketfile => $cfg{instance}{socketfile},
        realm => $cfg{instance}{realm},
    }
) or die "Error creating new test instance: $@";

$test->set_verbose($cfg{instance}{verbose});

$test->plan( tests => 19 );

my $buffer = do { # slurp
	local $INPUT_RECORD_SEPARATOR;
    open my $HANDLE, '<', $cfg{instance}{buffer};
    <$HANDLE>;
};

my $serializer = OpenXPKI::Serialization::Simple->new();
my $input_data = $serializer->deserialize( $buffer );

my $cert_identifier = $input_data->{'cert_identifier'};

$test->like( $cert_identifier , "/^[0-9a-zA-Z-_]{27}/", 'Certificate Identifier')
 || die "Unable to proceed without Certificate Identifier: $@";


# Login to use socket
$test->connect_ok(
    user => $cfg{user}{name},
    password => $cfg{user}{password},
) or die "Error - connect failed: $@";

# First try an autoapproval request

my %wfparam = (
    cert_identifier => $cert_identifier,
    reason_code => 'unspecified',
    comment => 'Automated Test',
    flag_auto_approval => 0,
    flag_batch_mode => 0
);

$test->create_ok( 'certificate_revocation_request_v2' , \%wfparam, 'Create Revoke Workflow')
 or die "Workflow Create failed: $@";

$test->state_is('PENDING_USER');

$test->execute_ok( 'crr_submit' );

$test->state_is('PENDING');

$test->execute_nok( 'crr_approve_crr' );

$test->disconnect();

# Re-login with Operator for approval
$test->connect_ok(
    user => $cfg{operator}{name},
    password => $cfg{operator}{password},
) or die "Error - connect failed: $@";

$test->execute_ok( 'crr_update_crr', { reason_code => 'keyCompromise' } );

$test->state_is('PENDING');

$test->execute_ok( 'crr_reject_crr' );

$test->state_is('REJECTED');


# Test delayed revoke
$wfparam{flag_auto_approval} = 1;
$wfparam{delay_revocation_time} = time() + 5;
$wfparam{flag_batch_mode} = 1;
$test->create_ok( 'certificate_revocation_request_v2' , \%wfparam, 'Create delayed Revoke Workflow')
   or die "Workflow Create failed: $@";

$test->state_is('CHECK_FOR_DELAYED_REVOKE');
my $delayed_revoke_id =  $test->get_wfid();

# Test auto revoke
delete $wfparam{delay_revocation_time};
$wfparam{flag_auto_approval} = 1;
$wfparam{flag_batch_mode} = 1;
$wfparam{invalidity_time} = time();

$test->create_ok( 'certificate_revocation_request_v2' , \%wfparam, 'Create Auto-Revoke Workflow')
 or die "Workflow Create failed: $@";

# Go to pending
$test->state_is('CHECK_FOR_REVOCATION');

# Do a second test - should go to success as already approved
$wfparam{flag_auto_approval} = 0;

$test->create_ok( 'certificate_revocation_request_v2' , \%wfparam, 'Create Auto-Revoke Workflow')
 or die "Workflow Create failed: $@";

$test->state_is('CHECK_FOR_REVOCATION');

# Finally, check if the delayed workflow has finished
$test->set_wfid( $delayed_revoke_id );

note('Switch back to delayed workflow #'.$delayed_revoke_id);
my $i = 0;
do {
    sleep 5;
    $test->reset();
    $i++;
} while($test->state() ne 'CHECK_FOR_REVOCATION' && $i < 6);
$test->state_is('CHECK_FOR_REVOCATION');

open(CERT, ">$cfg{instance}{buffer}");
print CERT $serializer->serialize({ cert_identifier => $test->param( 'cert_identifier' ), wf_id => $test->get_wfid() });
close CERT;

$test->disconnect();

