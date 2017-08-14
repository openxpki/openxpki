# OpenXPKI::Server::Workflow::Activity::WorkflowTest
# Written by Oliver Welter/Dieter Siebeck for the OpenXPKI Project 2011
# Copyright (c) 2011 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::WorkflowTest;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::DateTime;

use Data::Dumper;

sub execute {

    my $self     = shift;
    my $workflow = shift;

    my $context = $workflow->context();

    ##! 1: 'Workflow Test entered - Workflow Id: ' .$workflow->id();

    # parameter ""action" decides, what should happen:
    my $action = $self->param('perform');

    # optional parameter "cause":
    my $pause_cause = $self->param('cause');
    $pause_cause ||= 'some terrific cause';

    #when execute runs till end, "test_job_is_done" is set to "1"
    $context->param({ 'test_job_is_done' => '0' });

    $context->param('test', time());

    if ($action eq 'crash') {
        ##! 16: 'Crash on request'
        OpenXPKI::Exception->throw(
           message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TEST_CRASHED',
       );

    } elsif ($action eq 'fatal_err') {
        ##! 16: 'fatal error on request'
        OpenXPKI::Server::Workflow::Pause->throw(
           cause => 'a manually triggered pause - this should NEVER happen in real code. throws an exception in OpenXPKI::Server::Workflow::execute_action()',
       );

    } elsif ($action eq 'pause') {
        ##! 16: 'Pause on request '
        $self->pause($pause_cause);

    } elsif ($action eq 'sleep') {
        ##! 16: 'Pause on request '
        sleep(  $self->param('sleep') || 15 );
    }

    #if pause or crash is given, we should never reach this part:
    ##! 1: 'Workflow Test: passed all hurdles ...execute my job';
    $context->param({ 'test_job_is_done' => '1' });
}

sub resume{
    my $self     = shift;
    my ($workflow,$proc_state_resume_from) = @_;

    ##! 1: 'resume from '.$proc_state_resume_from
    my $context = $workflow->context();
    my $i_called = $context->param('resume_was_called');
    $i_called ||=0;
    $i_called++;
    $context->param('resume_was_called' , $i_called);
}

sub wake_up{
    my $self     = shift;
    my ($workflow) = @_;

    ##! 1: 'wake up '
    my $context = $workflow->context();
    my $i_called = $context->param('wake_up_was_called');
    $i_called ||=0;
    $i_called++;
    $context->param('wake_up_was_called' , $i_called);
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::WorkflowTest;

=head1 Description

Test Activity for Workflow Development

=head2 Configuration

Retry 5 times with a 15 minute pause interval and terminate workflow with
FAILURE state if the retries are exceeded.

  <action name="I18N_OPENXPKI_WF_ACTION_TEST_ACTIVITY"
     class="OpenXPKI::Server::Workflow::Activity::WorkflowTest"
     retry_count="5" retry_interval="+0000000015" autofail="yes">
  </action>

Retry Interval is a OpenXPKI::DateTime specification
only relative dates are allowed.

The execution of this job can be controlled throgh a bunch of workflow params:

=head3 wokflow/action params

=over 8

=item action

what should the action do? possible values: "pause", "crash" or "" (run normally)

=item cause

optional cause for pausing, will be passed as argument to $self->pause($msg)

=item reap_at

OpenXPKI relative interval, ie. "+0000000012". is  checked in init phase and passed to $self->set_reap_at_interval($interval).

=item reap_at_dyn

OpenXPKI relative interval, ie. "+0000000012".
is  checked in execution phase and passed to $self->set_reap_at_interval($interval).

=item retry_interval

OpenXPKI relative interval, ie. "+0000000012".
is  checked in execution phase and passed to $self->set_reap_at_interval($interval).

=back

=head2 init

after super::init, the param "reap_at" is evaluated. if given, $self->set_reap_at_interval() is called.

=head2 execute

checks param "action": if action = "pause", $self->pause() will be called.
if action = "crash", an exception I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TEST_CRASHED is thrown.


=head2 resume

hook method, will be called from OpenXPKI::Server::Workflow when activity is resumed after an exception.
This implementation augments the  wf context param "resume_was_called" for testing purposes (see /qatests/backend/paused_workflows)

=head2 wake_up

hook method, will be called from OpenXPKI::Server::Workflow when activity is executed again after pause.
This implementation augments the  wf context param "wake_up_was_called" for testing purposes (see /qatests/backend/paused_workflows)
