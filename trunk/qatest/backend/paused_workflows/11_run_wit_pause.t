#!/usr/bin/perl
#
# 11_run_with_pause.t
#
# Test: workflow runs and pauses
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

$test->plan( tests => 22 );

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

#execute next activity with special param "pause" (3 times)
my $cause = 'xyz';
my $i;
for($i=0;$i<3;$i++){
    
    $test->execute_ok(
        'I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST', {action=> 'pause',cause => $cause}
    ) or die "Error executing I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST (iteration $i) with pause: $@";
    
    $test->state_is( 'STEP2', sprintf("Paused (iteration %d): state should remain STEP2",$i+1) );
    
}

$test->param_is( 'test_job_is_done', 0, 'activity has NOT done its job' );

$test->param_is( 'wf_pause_msg', $cause,
    'cause of pause should be saved in wf context' );

my $iExpectedWakeUps = $i-1;#was not called at first execution of "I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST"
$test->param_is( 'wake_up_was_called', $iExpectedWakeUps,
    sprintf('Action::wake_up() was called %d times',$iExpectedWakeUps) );
    
$test->proc_state_is('pause', 'Proc-State should be "pause"');    

$test->count_try_is($i, sprintf('count try should be "%d"',$i));  




#-------------------------- PROCEED ----------------------------------------#
#and now: head up to the end

$test->execute_ok(
    'I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST', {}
) or die "Error executing 1st I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST: $@";

$test->state_is( 'STEP3' ,"execute again without pause: state should be STEP3") ;
$test->param_is( 'test_job_is_done', 1, 'activity has done its job' );
$test->proc_state_is('manual', 'Proc-State should be "manual"');    
$test->count_try_is(0, sprintf('count try should be "%d"',0)); 

$test->execute_ok(
    'I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST', {}
) or die "Error executing 2nd I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST: $@";

$test->state_is( 'SUCCESS',"final state should be SUCCESS" ) ;
    
 $test->proc_state_is('finished', 'Proc-State should be "finished"');    

    