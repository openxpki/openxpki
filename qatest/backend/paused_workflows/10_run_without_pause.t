#!/usr/bin/perl
#
# 10_run_wiothout_pause.t
#
# Test: workflow runs till end without pauses
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

$test->plan( tests => 14);

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


#-------------------------  EXECUTE  ----------------------------------

#execute test activity 2 times
$test->execute_ok(
    'I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST', {}
) or die "Error executing 1st I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST: $@";

$test->state_is( 'STEP3' ) 
    or die "State after 1st I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST must be STEP3";

$test->proc_state_is('manual', 'Proc-State should be "manual"');    

$test->count_try_is(0, sprintf('count try should be "%d"',0)); 

$test->param_is( 'test_job_is_done', 1, 'activity has done its job' );

$test->execute_ok(
    'I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST', {}
) or die "Error executing 2nd I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST: $@";

$test->param_is( 'test_job_is_done', 1, 'activity has done its job' );

$test->state_is( 'SUCCESS' ) 
    or die "State after 2nd I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST must be SUCCESS";   
    
 $test->proc_state_is('finished', 'Proc-State should be "finished"');    

$test->count_try_is(0, sprintf('count try should be "%d"',0)); 
$test->assert_wake_up_is_empty();       