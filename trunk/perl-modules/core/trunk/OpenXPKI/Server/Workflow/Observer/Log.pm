# OpenXPKI::Server::Workflow::Observer::Log
# Written by Alexander Klink and Martin Bartosch for the OpenXPKI project 2007
# Copyright (c) 2007 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Observer::Log;

use strict;

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;

sub update {

    # NOTE: The documentation for Workflow.pm does not reflect the actual
    #       parameters used!
    #

    my $class    = shift;
    my $workflow = shift;
    my $event    = shift;
    my $type     = $workflow->type();
    my $id       = $workflow->id();
    my $state    = $workflow->state();
    my $prio     = 'debug';
    my $msg      = '';

    if ( $event eq 'create' ) {
        $prio = 'info';
        $msg  = "Workflow $id/$type/$state created";
    }
    elsif ( $event eq 'execute' ) {
        $prio = 'info';
        my ( $old_state, $action_name, $autorun ) = @_;
        $msg
            = "Workflow $id/$type/$state executed '$action_name'" . ($autorun
            ? ' (autorun)'
            : '') . " in state '$old_state'";
    }
    elsif ( $event eq 'state change' ) {
        $prio = 'info';
        my ( $old_state, $action_name, $autorun ) = @_;
        $msg = "Workflow $id/$type/$state changed from state '$old_state'";
    }
    elsif ( $event eq 'fetch' ) {
        $msg = "Workflow $id/$type/$state fetched";
    }
    elsif ( $event eq 'save' ) {
        $msg = "Workflow $id/$type/$state saved";
    }
    elsif ( $event eq 'add history' ) {
        $msg = "Workflow $id/$type/$state added history";
    }

    # in case more events are ever added to Workflow
    if ( $msg eq '' ) {
        $msg = join( '; ',
            "Workflow ID=" . $workflow->id(),
            "Type=" . $workflow->type(),
            "Event=" . $event,
            "Params=" . join( ', ', @_ ) );
    }

    CTX('log')->log(
        MESSAGE  => $msg,
        PRIORITY => $prio,
        FACILITY => 'workflow',
    );

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Observer::Log

=head1 Description

This class implements a workflow observer that just logs anything
that happens to our log system.
