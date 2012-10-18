#!/usr/bin/perl
#
# 14_test_wakeup_at.t
#
# checks, wether the wakeup_at timestamp are correctly set
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


my $activity_default_diff = '+0000000005';#workflow_activity.xml
my $workflow_defined_diff = '+0000000015';#workflow_def_testing.xml
my $manual_given_diff = '+0000000022';#set via Activity::set_retry_intervall



#------------------------- INIT ----------------------------------

my $test = OpenXPKI::Test::More::Workflow::TestPausedWorkflow->new(
    {
        socketfile => $cfg{instance}{socketfile},
        realm => $cfg{instance}{realm},
    }
) or die "Error creating new test instance: $@";

$test->set_verbose($cfg{instance}{verbose});

$test->plan( tests => 15 );

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

#------------------------  PAUSE ----------------------------

#execute next activity with special param "pause" 

    
$test->execute_ok(
    'I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST', {action=> 'pause'}
) or die "Error executing I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST  with pause: $@";

$test->assert_timestamp_diff('WAKE_UP_AT',$activity_default_diff,sprintf('testing retry intervall %s defined in activity.xml',$activity_default_diff));


#proceed one step

$test->execute_ok(
    'I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST', {}
) or die "Error proceeding I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST : $@";

#new pause, this time (step 3) a different retry interval is defined in workflow.xml
$test->execute_ok(
    'I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST', {action=> 'pause'}
) or die "Error executing I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST  with pause: $@";

$test->assert_timestamp_diff('WAKE_UP_AT',$workflow_defined_diff,sprintf('testing retry intervall %s defined in workflow.xml',$workflow_defined_diff));

#new pause, this time we pass in our own retry intervall
$test->execute_ok(
    'I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST', {action=> 'pause',retry_interval => $manual_given_diff}
) or die "Error executing I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST  with pause: $@";
    
$test->assert_timestamp_diff('WAKE_UP_AT',$manual_given_diff,sprintf('testing retry intervall %s explicit set via Activity::set_retry_intervall' , $manual_given_diff));


#proceed to SUCCESS
$test->execute_ok(
    'I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST', {}
) or die "Error proceeding I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST : $@";

$test->assert_wake_up_is_empty();
