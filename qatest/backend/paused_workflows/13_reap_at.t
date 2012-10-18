#!/usr/bin/perl
#
# 13_reap_at.t
#
# verifies, that the "reap_at" timestamp is set correctly 
# special case: setting of reap_at must work even from within the execute()-method of an conctere activity
# at this time, the (old) reap_at timestamp is already saved to db and must be immediately replaced
#
#
# Note: these tests are non-destructive. They create their own instance
# of the tools workflow, which is exclusively for such test purposes.

use strict;
use warnings;

use lib qw(
  /usr/lib/perl5/ 
  ../../lib
);

use TestPausedWorkflow;

use Carp;
use English;
use Data::Dumper;
use Config::Std;
use File::Basename;

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);

use OpenXPKI::Test::More;
use OpenXPKI::DateTime;

use TestCfg;

my $dirname = dirname($0);

our @cfgpath = ( $dirname );
our %cfg = ();

my $testcfg = new TestCfg;
$testcfg->read_config_path( 'paused_wf.cfg', \%cfg, @cfgpath );

#------------------------- INIT ----------------------------------

my $test = OpenXPKI::Test::More::Workflow::TestPausedWorkflow->new(
    {
        socketfile => $cfg{instance}{socketfile},
        realm => $cfg{instance}{realm},
    }
) or die "Error creating new test instance: $@";

$test->set_verbose($cfg{instance}{verbose});

$test->plan( tests => 12);

$test->connect_ok(
    user => $cfg{user}{name},
    password => $cfg{user}{role},
) or die "Error - connect failed: $@";


$test->create_ok(
    $test->wftype, { }, "Create test workflow" )
    or die "Error creating workflow instance: " . $@;

#test workflow autoruns till STEP2
$test->state_is( 'STEP2' ) 
    or die "State after create must be STEP2";

#-------------------------  EXECUTE  1 (default interval) ----------------------------------

#execute test activity
$test->execute_ok(
    'I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST', {action=>'pause'} #param "pause" set to have enough executions to play with
) or die "Error executing 1st I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST: $@";

#TODO: Default interval hard coded?
$test->assert_timestamp_diff('REAP_AT','+0000000005','default reap_at intervall should be 5 min');

#-------------------------  EXECUTE  2 (manual set interval during initialisation of action) ----------------------------------

my $interval = '+0000000012';
$test->execute_ok(
    'I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST', {action=>'pause', reap_at => $interval}
) or die "Error executing 1st I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST: $@";
$test->assert_timestamp_diff('REAP_AT',$interval,'manual set reap_at intervall to 12 min');

#-------------------------  EXECUTE  3 (manual set interval during execution of action) ----------------------------------

$interval = '+0000000017';
$test->execute_ok(
    'I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST', {reap_at_dyn => $interval}
) or die "Error executing 1st I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST: $@";
$test->assert_timestamp_diff('REAP_AT',$interval,'dynamically set reap_at intervall to 17 min');

