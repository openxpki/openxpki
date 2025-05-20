package OpenXPKI::Server::Workflow::Observer::Log;
use OpenXPKI;

use OpenXPKI::Server::Context qw( CTX );


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
    elsif ( $event eq 'pause' ) {
        my (  $action_name, $cause ) = @_;
        $prio = 'info';
        $msg = "Workflow $id/$type/$state paused at action $action_name, cause: $cause";
    } elsif ( $event eq 'autofail' ) {
        my (  $last_state, $action_name, $exception ) = @_;
        $prio = 'error';
        $msg = "Workflow $id/$type/$state failed on $action_name from $last_state, error: $exception";
    } elsif ( $event eq 'retry_exceeded' ) {
        $prio = 'error';
        $msg = "Workflow $id/$type/$state retry_exceeded";
    } elsif ( $event eq 'exception' ) {
        $prio = 'error';
        $msg = "Workflow $id/$type/$state uncaught exception";
    }


    # in case more events are ever added to Workflow
    if ( $msg eq '' ) {
        $msg = join( '; ',
            "Workflow ID=" . $workflow->id(),
            "Type=" . $workflow->type(),
            "Event=" . $event,
            "Params=" . join( ', ', @_ ) );
    }

    CTX('log')->workflow()->$prio($msg);

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Observer::Log

=head1 Description

This class implements a workflow observer that just logs anything
that happens to our log system.
