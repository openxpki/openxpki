#!/usr/bin/perl
#
# 12_count_try_exceeded.t
#
# Test: workflow  pauses to often
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

$test->plan( tests => 20 );

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

#------------------------  EXCEPTION ------------------------------

$test->execute_nok(
        'I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST', {action=> 'pause',cause => $cause},
        '4th execution should result in exception'
    );
$test->error_is('I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_RETRIES_EXEEDED','need correct error exception');
$test->reset();#enforce fresh wf info, otherwise param-check results in error-msg
$test->param_is( 'wf_exception', 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_RETRIES_EXEEDED',
    'exception code should be saved in wf context' );

$test->param_is( 'test_job_is_done', 0, 'activity has NOT done its job' );
       
$test->state_is( 'STEP2',"State after exception must still be STEP2" ) ;
$test->proc_state_is('retry_exceeded', 'Proc-State should be "retry_exceeded"');


#---------------------------- PROCEED ----------------------------------------#

$test->execute_ok('I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST', {},'resumed execution after exception');

$test->param_is( 'resume_was_called',1,'Action::resume() was called');

$test->proc_state_is('manual', 'Proc-State should be "manual"');    
$test->count_try_is(0, sprintf('count try should be "%d"',0)); 
$test->param_is( 'test_job_is_done', 1, 'activity has done its job' );















