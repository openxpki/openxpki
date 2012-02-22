#!/usr/bin/perl
#
# 15_workflow_exception.t
#
# Tprovokes a exception while execution in workflow. 
# Correct proc_state should be set,  Exception code should be saved in context
# New execution should trigger "resume". 
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

$test->plan( tests => 15);

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

#------------------------  EXCEPTION ------------------------------

#execute next activity with special param "crash" 
$test->execute_nok(
        'I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST', {action=> 'crash'},
        'execution should provoke exception'
    );


$test->error_is('I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TEST_CRASHED','need correct error exception');
$test->reset();#enforce fresh wf info, otherwise param-check results in error-msg
$test->param_is( 'wf_exception', 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TEST_CRASHED', 'exception code should be saved in wf context' );
$test->param_is( 'test_job_is_done', 0, 'activity has NOT done its job' );

$test->state_is( 'STEP2',"State after exception must still be STEP2" ) ;
$test->proc_state_is('exception', 'Proc-State should be "exception"');


#---------------------------- PROCEED ----------------------------------------#

$test->execute_ok('I18N_OPENXPKI_WF_ACTION_WORKFLOWTEST', {},'resumed execution after exception');

$test->param_is( 'resume_was_called',1,'Action::resume() was called');

$test->proc_state_is('manual', 'Proc-State should be "manual"');    

$test->state_is( 'STEP3',"State after exception should be STEP3" ) ;
$test->param_is( 'wf_exception', '',
    'exception code in wf context should be empty again' );
    
$test->param_is( 'test_job_is_done', 1, 'activity has done its job' );










