# OpenXPKI::Server::Workflow::Activity::Tools::Disconnect
# Written by Oliver Welterfor the OpenXPKI Project 2011
# Copyright (c) 2012 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::Disconnect;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );
use OpenXPKI::Server::Context qw( CTX );


sub init {
    my ( $self, $workflow, $params ) = @_;
    $self->SUPER::init($workflow, $params);
    $self->set_max_allowed_retries(1);
    $self->set_retry_interval('+000000000001');
    return;
}


sub wake_up {

    my $self     = shift;
    my $workflow = shift;
    ##! 1: 'wake up!'

    if (my $role = $self->param('change_role')) {
        CTX('log')->workflow()->info('Change session role to '. $role );
        CTX('session')->data->role( $role );
    }

}
sub execute {
    my $self     = shift;
    my $workflow = shift;

    ##! 8: 'Start'
    my $cnt = $workflow->count_try();

    if (!$cnt) {
        ##! 8: 'First Call - doing pause'
        CTX('log')->workflow()->info('Prepate fork of inline workflow, id ' . $workflow->id);

        my $reason = $self->param('pause_info') || '';
        $self->pause( $reason );
    }
    ##! 8: 'Resumed'
    CTX('log')->workflow()->info('resumed inline workflow, id ' . $workflow->id);

    return 1;

}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::Disconnect;

=head1 Description

This is a sort of "Fake Fork" to make a workflow disconnect
from the current process and continue in the background.
If invoked the first time, it just calls pause, the workflow
gets picked up by the watchdog and is resumed.

=head2 Activity parameters

=over

=item pause_info

A string that is set as initial "pause reason". This is visible to the user
until the watchdog picks up the process and continues.

=item change_role

Usually the workflow is continued with the permissions of the role that was
active when it was put to sleep. Setting this to a role name will change the
session role to this value when the workflow is woke up.

B<SECURITY RISK> Changing the role in a workflow affects the access privileges
of all all activities until the next interactive step!

=back
