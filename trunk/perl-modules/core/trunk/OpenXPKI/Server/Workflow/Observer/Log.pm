# OpenXPKI::Server::Workflow::Observer::Log
# Written by Alexander Klink and Martin Bartosch for the OpenXPKI project 2007
# Copyright (c) 2007 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Observer::Log;

use strict;

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;

sub update {

    #    my ($class, $workflow, $action, $old_state, $action_name) = @_;
    #    Note: the above params seem to no longer be valid
    my ( $class, $workflow, $event, $new_state ) = @_;
    my $prio = 'debug';
    my $msg = '';

    if ( $event eq 'create' ) {
        $prio = 'info';
#        $msg = "Workflow " . $workflow->id() . " created";
    } elsif ( $event eq 'execute' ) {
        $prio = 'info';
    } elsif ( $event eq 'state change' ) {
        $prio = 'info';
#    } elsif ( $event eq 'fetch' ) {
#    } elsif ( $event eq 'save' ) {
#    } elsif ( $event eq 'add history' ) {
    }

    if ( $msg eq '' ) {
        $msg = join('; ',
            "Workflow ID=" . $workflow->id(),
            "Type=" . $workflow->type(),
            "Event=" . $event,
            "New State: " . $new_state);
    }

    CTX('log')->log(
        MESSAGE => $msg,
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
