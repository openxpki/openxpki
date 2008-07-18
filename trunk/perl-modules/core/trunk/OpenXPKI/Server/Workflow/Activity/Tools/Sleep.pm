# OpenXPKI::Server::Workflow::Activity::Tools::Sleep
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::Sleep;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;

sub execute
{
    my $self = shift;
    my $workflow = shift;
    my $context = $workflow->context();
    my $time    = $self->param('time');
    ##! 32: 'started sleeping (' . $time . ' seconds)' 
    sleep $time;
    ##! 32: 'stopped sleeping'
    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::Sleep

=head1 Description

This activity just sleeps for a certain amount of time, which is
a useful thing to do while waiting for something to happen, e.g.
a CA key becoming available. The time given is measured in seconds.

Example:
  <action name="I18N_OPENXPKI_WF_ACTION_SLEEP"
	  class="OpenXPKI::Server::Workflow::Activity::Tools::Sleep"
	   time="5">
  </action>

