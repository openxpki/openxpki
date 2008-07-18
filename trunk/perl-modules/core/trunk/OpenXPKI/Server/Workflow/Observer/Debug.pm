# OpenXPKI::Server::Workflow::Observer::Debug
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Observer::Debug;

use strict;

use OpenXPKI::Debug;

sub update {
    my ($class, $workflow, $action, $old_state, $action_name) = @_;

    ##! 1: 'Workflow observer triggered'
    ##! 1: 'action: ' . $action
    ##! 1: 'workflow id: ' . $workflow->id()
    ##! 1: 'workflow type: ' . $workflow->type()
    ##! 1: 'workflow state: ' . $workflow->state()
    ##! 1: 'old_state: ' . $old_state
    ##! 1: 'action_name: ' . $action_name

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Observer::Debug

=head1 Description

This class implements a workflow observer that just dumps anything
that happens to stderr.log (via OpenXPKI::Debug).
