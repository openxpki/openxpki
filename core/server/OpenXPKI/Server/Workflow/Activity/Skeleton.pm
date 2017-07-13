# OpenXPKI::Server::Workflow::Activity::Skeleton
# Written by Oliver Welter for the OpenXPKI project 2013
# Copyright (c) 2005 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Skeleton;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;


sub execute {
    my $self = shift;
    my $workflow = shift;

    my $context = $workflow->context();

    my $need_to_wait;
      # do some work
      if ($need_to_wait) {
          # The text is written to the logs and is optional
          $self->pause('I18N_OPENXPKI_UI_PAUSED_WAITING');
      }

      CTX('log')->application()->debug("Please use the application facility to log your stuff, and please be verbose!");



}

sub resume{

    my $self = shift;
    my ($workflow, $resume_from) = @_;

    if ($resume_from eq "retry_exceeded") {
        # This code gets executed if you restart the workflow after
        # the configured number of retries was exceeded

    }

    # Put any code here you need to run after you resumed this
    # activity after it crashed with an exception



}

sub wake_up{
    my $self     = shift;
    my ($workflow) = @_;

    # This code gets executed when the watchdog reruns the activity
    # while the set retry_count is not reached.

}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Skeleton

=head1 Description

Implements the FIXME workflow action.

=head1 Configuration

=head2 Activity parameters

=over

=item my_control_param

Explain values and effects of my_control_param.

=back

=head2 Context parameters

Expects the following context parameters:

=over

=item ...

Description...

=item ...

Description...

=back

After completion the following context parameters will be set:

=over 12

=item ...

Description...

=back

=head1 Functions

=head2 execute

Executes the action.

=head2 wake_up

Method to prepare after returning from pause

=head2 resume

Method to prepare after returning from an exception.
Reason for laying down passed as second parameter (exception or retry_exceeded).





