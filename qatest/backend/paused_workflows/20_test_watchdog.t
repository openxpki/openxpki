#!/usr/bin/perl
#
# 20_watchdog_reset
#
# this test triggers an paused workflow with wakeup-time 1 minute, waits 70 seconds and finally verifies that 
# watchdog has done its job
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
use OpenXPKI::Server::Watchdog;
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

$test->plan( tests => 10);

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

#execute test activity with pause (one minute retry interval as lowest possibility)
$test->execute_ok(
    'I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST', {action=> 'pause',retry_interval=>'+0000000000'}
) or die "Error executing 1st I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST: $@";

$test->proc_state_is('pause', 'Proc-State should be "pause"');  
$test->state_is( 'STEP2', "Paused : state should remain STEP2, sleep now 30 secs..." );

sleep(30);
$test->reset();#enforce fresh wf info
$test->state_is( 'STEP3','watchdog should have executet paused WF');
$test->param_is( 'test_job_is_done', 1, 'activity has done its job' );
$test->proc_state_is('manual', 'Proc-State should be "manual"');    
$test->count_try_is(0, sprintf('count try should be "%d"',0)); 

      