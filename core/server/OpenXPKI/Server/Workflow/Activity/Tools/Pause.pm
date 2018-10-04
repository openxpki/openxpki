# OpenXPKI::Server::Workflow::Activity::Tools::Pause
# Written by Oliver Welterfor the OpenXPKI Project 2014
# Copyright (c) 2014 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::Pause;

use strict;
use OpenXPKI::Exception;
use base qw( OpenXPKI::Server::Workflow::Activity );
use OpenXPKI::Server::Context qw( CTX );

sub execute {
    my $self     = shift;
    my $workflow = shift;

    ##! 8: 'Start'
    my $cnt = $workflow->count_try();

    if (!$cnt) {
        ##! 8: 'First Call - doing pause'
        my $reason = $self->param('reason');
        my $interval;

        # Wakeup Case
        if ($self->param('wakeup')) {
            my $wakeup_at = OpenXPKI::DateTime::get_validity({
                VALIDITY => $self->param('wakeup'),
                VALIDITYFORMAT => 'detect',
            });

            # Wakeup elapsed, so do nothing
            if ($wakeup_at->epoch() <= time()) {
                ##! 8: 'wakeup with elapsed time, continue'
                CTX('log')->workflow()->info("Requested pause with wakeup but timestamp has already elapsed ($wakeup_at) - continue");

                return 1;
            }
            CTX('log')->workflow()->info("Requested pause with absolute wakeup - retire till $wakeup_at");

            ##! 8: 'wakeup - sleep till ' . $wakeup_at
            $interval = $wakeup_at->epoch();
        } else {
            # Workflow will consume the date as is, so ne need to convert
            $interval = $self->param('sleep');
            CTX('log')->workflow()->info('Requested pause with relative sleep ' .$interval);

        }

        OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_WORKFLOW_ACTIVITY_TOOLS_PAUSE_MISSING_DURATION"
        ) unless($interval);

        $reason = 'I18N_OPENXPKI_WORKFLOW_ACTIVITY_TOOLS_PAUSE_NO_REASON' unless ($reason);

        $self->set_max_allowed_retries(1);
        $self->pause( $reason, $interval );

    }

    ##! 8: 'Resumed'
    CTX('log')->workflow()->info('Resume after explicit pause, workflow id ' . $workflow->id);
    return 1;

}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::Pause;

=head1 Description

Generic pause activity which stops the current workflow for a defined
period of time. Note that this is a non blocking pause and the outer execute
loop will terminate and return. This is basically the same as using the watchdog
with a retry count of 1 and a suitable interval.

The Activity has two modes of operation, which are triggered by the name of
the parameter used. If you specifiy both parameters, wakeup is used first
but sleep is used if wakeup contains a false value.

=head2 Parameters

=over

=item *sleep*

Sleep for a relative time starting from now. The value given to sleep is evaluated
as a relativedate as defined in OpenXPKI::DateTime. Note: the activity will always
detach from the current process and waits for the watchdog to be restarted.
Therefore the given sleep period is a lower bound and not an exact value!

Example - Sleep for a day:

  <action name="I18N_OPENXPKI_WF_ACTION_PAUSE"
      class="OpenXPKI::Server::Workflow::Activity::Tools::Pause"
       reason="I am tired"
       wakeup="+0000001">
  </action>


=item *wakeup*

Wakeup expects an absolute time, either in the OpenXPKI::DateTime absolutedate
format (YYMMDDhhmmss) or epoch. Note: If the date has already elapsed, the
activity will NOT detach but just become a noop and continue.

Example - Sleep until five-to-twelve on new years eve:

  <action name="I18N_OPENXPKI_WF_ACTION_PAUSE"
      class="OpenXPKI::Server::Workflow::Activity::Tools::Pause"
      wakeup="201412312355">
  </action>

Hint - this is very handy in combination with the parameter mapping feature:
  <action name="I18N_OPENXPKI_WF_ACTION_PAUSE"
      class="OpenXPKI::Server::Workflow::Activity::Tools::Pause"
      _map_wakeup="$context_key_with_date">
  </action>

=item *reason*

The reason parameter is optional an takes a string to be logged as reason for the
pause.

=back
