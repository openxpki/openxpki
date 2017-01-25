## OpenXPKI::Server::Watchdog.pm
##
## Written by Dieter Siebeck and Oliver Welter for the OpenXPKI project
## Copyright (C) 2012-2013 by The OpenXPKI Project


=head1 NAME

The watchdog thread

=head1 DESCRIPTION

The watchdog is forked away on startup and takes care of paused workflows.
The system has a default configuration but you can override it via the system
configuration.

The namespace is I<system.watchdog>. The properties are:

=over

=item max_fork_redo

Retry this often to fork away the initial watchdog process before
failing finally.
default: 5

=item max_exception_threshhold

There are situations (database locks, no free resources) where a watchdog
can not fork away a new worker. After I<max_exception_threshhold> errors
occured, we kill the watchdog. B<This is a fatal error that must be handled!>
default: 10

=item interval_sleep_exception

The number of seconds to sleep after the watchdog ran into an exception.
default: 60

=item max_tries_hanging_workflows

Try to restarted stale workflows this often before failing them.
default:  3

=item max_instance_count

Allow multiple watchdogs in parallel. This controls the number of control
process, setting this to more than one is usually not necessary (and also
not wise).

default: 1

=item interval_wait_initial

Seconds to wait after server start before the watchdog starts scanning.
default: 30;

=item interval_loop_idle

Seconds between two scan runs if no result was found on last run.
default: 5

=item interval_loop_run

Seconds between two scan runs if a result was found on last run.
default: 1

=back

=cut

package OpenXPKI::Server::Watchdog;
use strict;
use English;
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Session;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Watchdog::WorkflowInstance;
use OpenXPKI::DateTime;
use Proc::ProcessTable;

use Net::Server::Daemonize qw( set_uid set_gid );

use Moose;

use Data::Dumper;

our $terminate = 0;

has workflow_table => (
    is => 'ro',
    isa => 'Str',
    default => 'workflow',
);

has max_fork_redo => (
    is => 'rw',
    isa => 'Int',
    default =>  5
);
has max_exception_threshhold => (
    is => 'rw',
    isa => 'Int',
    default =>  10
);

has interval_sleep_exception => (
    is => 'rw',
    isa => 'Int',
    default =>  60
);

has max_tries_hanging_workflows => (
    is => 'rw',
    isa => 'Int',
    default =>  3
);

has max_instance_count => (
    is => 'rw',
    isa => 'Int',
    default =>  1
);

# All timers in seconds
has interval_wait_initial => (
    is => 'rw',
    isa => 'Int',
    default =>  30
);

has interval_loop_idle => (
    is => 'rw',
    isa => 'Int',
    default =>  5
);

has interval_loop_run => (
    is => 'rw',
    isa => 'Int',
    default =>  1
);

has _uid => (
    is => 'ro',
    isa => 'Str',
    default => '0',
);

has _gid => (
    is => 'ro',
    isa => 'Str',
    default => '0',
);

around BUILDARGS => sub {

    my $orig = shift;
    my $class = shift;

    # Holds user and group id
    my $args = shift;

    my $config = CTX('config')->get_hash('system.watchdog');

    $config = {} unless($config); # Moose complains on null

    # Add uid/gid
    $config->{_uid} = $args->{user}  if( $args->{user} );
    $config->{_gid} = $args->{group} if( $args->{group} );

    # This automagically sets all entries from the config
    # to the corresponding class attributes
    return $class->$orig($config);

};

=head1 Methods
=head2 run

Forks away a worker child, returns the pid of the worker

=cut

sub run {
    my $self = shift;

    my $pid;
    my $redo_count = 0;

    # Check if we already have a watchdog running
    my $result = OpenXPKI::Control::get_pids();
    my $instance_count = scalar @{$result->{watchdog}};
    if ($instance_count >= $self->max_instance_count()) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_WATCHDOG_RUN_TOO_MANY_INSTANCES',
            params => {
                'instance_running' => $instance_count,
                'max_instance_count' =>  $self->max_instance_count()
            },
            log => {
                logger => CTX('log'),
                priority => 'error',
                facility => 'system',
        });
    }

    $SIG{CHLD} = 'IGNORE';
    while ( !defined $pid and $redo_count < $self->max_fork_redo ) {
        ##! 16: 'trying to fork'
        $pid = fork();
        ##! 16: 'pid: ' . $pid
        if ( !defined $pid ) {
            if ( $!{EAGAIN} ) {
                # recoverable fork error
                sleep 2;
                $redo_count++;
            } else {
                # other fork error
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_INIT_WATCHDOG_FORK_FAILED_UNRECOVERABLE',
                    log => {
                        logger => CTX('log'),
                        priority => 'fatal',
                        facility => 'system',
                    }
                );
            }
        }
    }

    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_INIT_WATCHDOG_FORK_FAILED_MAX_REDO',
        log => {
            logger => CTX('log'),
            priority => 'fatal',
            facility => 'system',
        }
    ) unless (defined $pid);

    # parent process returns
    return $pid unless $pid == 0;

    #
    # from here on - child process
    #
    $SIG{'HUP'} = \&OpenXPKI::Server::Watchdog::_sig_hup;
    $SIG{'TERM'} = \&OpenXPKI::Server::Watchdog::_sig_term;

    # Reconnect the dbi
    CTX('dbi_log')->new_dbh();
    CTX('dbi_log')->connect();

    # The caller sets the watchdog only in the global context
    # we reuse the context to set a pointer to ourselves for signal handling
    # in the forked process - we need the force if the watchdog is forked
    # during runtime to overwrite the main context
    OpenXPKI::Server::Context::setcontext({
        watchdog => $self, force => 1
    });

    ##! 16: 'child here'

    # Re-seed Perl random number generator
    srand(time ^ $PROCESS_ID);

    $self->{dbi}                      = CTX('dbi');
    $self->{hanging_workflows}        = {};
    $self->{hanging_workflows_warned} = {};
    $self->{original_pid}             = $PID;

    # set process name

    $0 = sprintf ('openxpkid (%s) watchdog', CTX('config')->get('system.server.name') || 'main');

    set_gid($self->_gid()) if( $self->_gid() );
    set_uid($self->_uid()) if( $self->_uid() );

    # wait some time for server startup...
    ##! 16: sprintf('watchdog: original PID %d, initail wait for %d seconds', $self->{original_pid} , $self->interval_wait_initial());

    # Force new session as the initialized session is a Mock-Session which we can not use!
    $self->__check_session(1);

    CTX('log')->log(
        MESSAGE  => sprintf( 'Watchdog initialized, delays are: initial: %01d, idle: %01d, run: %01d"',
            $self->interval_wait_initial(), $self->interval_loop_idle(), $self->interval_loop_run() ),
        PRIORITY => "info",
        FACILITY => "system",
    );

    sleep($self->interval_wait_initial());

    ### TODO: maybe we should measure the count of exception in a certain time interval?
    my $exception_count = 0;

    ##! 16: 'watchdog: start looping'

    while ( ! $OpenXPKI::Server::Watchdog::terminate ) {
        ##! 80: 'watchdog: do loop'
        #ensure that we have a valid session
        $self->__check_session();

        eval {
            my $wf_id = $self->__scan_for_paused_workflows();
            # duration of pause depends on whether a workflow was found or not
            my $sec = $wf_id ? $self->interval_loop_run : $self->interval_loop_idle;
            ##! 80: sprintf('watchdog sleeps %d secs (%s)', $sec, $wf_id ? 'busy' : 'idle')
            sleep($sec);
            # Reset the exception counter after every successfull loop
            $exception_count = 0;
        };
        my $error_msg;
        if ( my $exc = OpenXPKI::Exception->caught() ) {
            ##! 16: 'Got OpenXPKI::Exception in watchdog - count is ' . $exception_count
            ##! 32: 'Exception message is ' . $exc->message_code
            $error_msg = "Watchdog, fatal exception: " . $exc->message_code;
        } elsif ($EVAL_ERROR) {
            $error_msg = "Watchdog, fatal error: " . $EVAL_ERROR;
        }
        if ($error_msg) {
            $exception_count++;
            print STDERR $error_msg, "\n";

            my $sleep = $self->interval_sleep_exception();
            CTX('log')->log(
                MESSAGE  => "Watchdog error, have a nap ($sleep sec, $exception_count cnt, $error_msg)",
                PRIORITY => "error",
                FACILITY => "system"
            );

            my $threshold = $self->max_exception_threshhold();
            if (($threshold > 0) && ($exception_count > $threshold )) {
                my $msg = 'Watchdog exception limit ($threshold) reached, exiting!';
                print STDERR $msg, "\n";
                OpenXPKI::Exception->throw(
                    message => $msg,
                    log => {
                        logger => CTX('log'),
                        priority => 'fatal',
                        facility => 'system',
                });
            }

            # sleep to give the system a chance to recover
            sleep($sleep);
        }
    }
    exit;
    ##! 4: 'End of run'
}

=head2 _sig_hup

signalhandler registered with the forked worker.
Trigger via IPC by the master process when a reload happens.

=cut
sub _sig_hup {
    ##! 1: 'Got HUP'
    my $watchdog = CTX('watchdog');

    ##! 4: 'run update head on watchdog child ' . $$
    my $config = CTX('config');
    $config->update_head();

    ##! 16: 'new head version is ' . $config->get_head_version()
    my $new_cfg = $config->get_hash('system.watchdog');

    # set the config values from new head
    for my $key (qw(
        max_fork_redo
        max_exception_threshhold
        interval_sleep_exception
        max_tries_hanging_workflows
        interval_wait_initial
        interval_loop_idle
        interval_loop_run
    )) {
        if ($new_cfg->{$key}) {
            ##! 16: 'Update key ' . $key
            $watchdog->$key( $new_cfg->{$key} )
        }
    }

    # Re-Init the Notification backend
    OpenXPKI::Server::Context::setcontext({
        notification => OpenXPKI::Server::Notification::Handler->new(),
        force => 1,
    });

    CTX('log')->log(
        MESSAGE  => 'Watchdog worker reloaded',
        PRIORITY => "info",
        FACILITY => "system",
    );
    return;
}

=head2 _sig_term

signalhandler registered with the forked worker.
Trigger via IPC by the master process to terminate the worker.

=cut
sub _sig_term {
    ##! 1: 'Got TERM'
    $OpenXPKI::Server::Watchdog::terminate  = 1;

    CTX('log')->log(
        MESSAGE  => "Watchdog worker $$ got term signal - cleaning up.",
        PRIORITY => "info",
        FACILITY => "system",
    );

    return;
}

=head2 reload

This method is called from the main server to inform the watchdog
to reload the config. You should not call this from inside a watchdog worker.

=cut

sub reload {
    my $self = shift;
    ##! 1: 'reloading'

    my $pids = OpenXPKI::Control::get_pids();

    # Check for enable/disable change
    my $disabled = CTX('config')->get('system.watchdog.disabled') || 0;

    # Terminate if we have a watchdog where we should not have one
    if ($disabled and scalar @{$pids->{watchdog}}) {
        CTX('log')->log(
            MESSAGE  => 'Watchdog should not run - terminating.',
            PRIORITY => "info",
            FACILITY => "system",
        );
        kill 'TERM', @{$pids->{watchdog}};
    }
    # Start watchdog if not running
    elsif (not scalar @{$pids->{watchdog}}) {
        CTX('log')->log(
            MESSAGE  => 'Watchdog missing - starting it.',
            PRIORITY => "info",
            FACILITY => "system",
        );
        CTX('watchdog')->run();
    }
    # Signal reload
    else {
        kill 'HUP', @{$pids->{watchdog}};
    }

    return 1;
}

=head2 terminate

This method uses the process table to look for watchdog instances and workers
and sends them a SIGHUP signal. This will NOT kill the watchdog but tell it
to not start any new workers. Running workers won't be touched.
You should not call this from inside a watchdog worker.

=cut

sub terminate {
    my $self = shift;
    ##! 1: 'terminate'

    my $pids = OpenXPKI::Control::get_pids();

    if (scalar $pids->{watchdog}) {
        kill 'TERM', @{$pids->{watchdog}};
        CTX('log')->log(
            MESSAGE  => 'Told watchdog to terminate',
            PRIORITY => "info",
            FACILITY => "system",
       );
    } else {
        CTX('log')->log(
            MESSAGE  => 'No watchdog pids to terminate',
            PRIORITY => "error",
            FACILITY => "system",
       );
    }

    return 1;
}

=head2

Do a select on the database to check for waiting or stale workflows,
if found, the workflow is marked and reinstantiated, the id of the
workflow is returned. Returns undef, if nothing is found.

=cut
sub __scan_for_paused_workflows {
    my $self = shift;
    ##! 1: 'start'

    # Search table for paused workflows that are ready to wake up
    # There is no ordering here, so we might not get the earliest hit
    # This is useful in distributed environments to prevent locks/races
    my $workflow = $self->{dbi}->select_one(
        from  => $self->workflow_table,
        columns => [ qw(
            workflow_id
            workflow_type
            workflow_session
            pki_realm
        ) ],
        where => {
            'workflow_proc_state' => 'pause',
            'watchdog_key'        => '__CATCHME',
            'workflow_wakeup_at'  => { '<', time() },
        },
    );

    if ( !defined $workflow ) {
        ##! 80: 'no paused WF found, can be idle again...'
        return;
    }

    ##! 16: 'found paused workflow: '.Dumper($workflow)

    #select again:
    my $wf_id = $workflow->{workflow_id};
    $self->__flag_and_fetch_workflow( $wf_id ) or return;

    ##! 16: 'WF now ready to re-instantiate: '.Dumper($db_result)
    CTX('log')->log(
        MESSAGE  => sprintf( 'watchdog, paused wf %d now ready to re-instantiate, start fork process', $wf_id ),
        PRIORITY => "info",
        FACILITY => "workflow",
    );

    eval{
        # create a forked child process which "wakes up the workflow"
        my $instance = OpenXPKI::Server::Watchdog::WorkflowInstance->new(
            workflow_id         => $workflow->{workflow_id},
            workflow_type       => $workflow->{workflow_type},
            workflow_session    => $workflow->{workflow_session},
            pki_realm           => $workflow->{pki_realm},
        );
        $instance->run;
    };
    # all exceptions/fatals which occur in the forked child will be handled there
    # if an error/exception occurs here, it must be within the main (watchdog) process, so we log it as "system" error
    my $error_msg;
    if ( my $exc = OpenXPKI::Exception->caught() ) {
        $exc->show_trace(1);
        $error_msg = "Exception caught while forking child instance: $exc";
    } elsif ($EVAL_ERROR) {
        $error_msg = "Fatal error while forking child instance:" . $EVAL_ERROR;
    }
    if ($error_msg) {
        CTX('log')->log(
            MESSAGE  => $error_msg,
            PRIORITY => "fatal",
            FACILITY => "system"
        );
    }

    # security measure: for child processes no further than here! (all childprocesses in WorkflowInstance should
    # exit properly and handle their exceptions on their own... but just in case...)
    # $self->{original_pid} == PID of Watchdog process
    if( $self->{original_pid} ne $PID ){
        ##! 16: sprintf('exit this process: current pid %s is not the watchdog pid %s' , $PID, $self->{original_pid});
        CTX('log')->log(
            MESSAGE  => "Resumed workflow in child process did not exit properly",
            PRIORITY => "fatal",
            FACILITY => "system"
        );
        exit;
    }

    return $wf_id;
}

=head2 __flag_and_fetch_workflow( wf_id )

Flag the database row for wf_id.

To prevent a workflow from being reloaded by two watchdog instances, this
method first writes a random marker to create "row lock" and tries to reload
the row using this marker. If either one fails, returnes undef.

=cut
sub __flag_and_fetch_workflow {
    my ($self, $wf_id) = @_;

    return unless $wf_id;    #this is real defensive programming ...;-)

    #FIXME: Might add some more entropy or the server id for cluster oepration
    my $rand_key = sprintf( '%s_%s_%s', $PID, time(), sprintf( '%02.d', rand(100) ) );

    ##! 16: 'set random key '.$rand_key

    CTX('log')->log(
        MESSAGE  => sprintf( 'watchdog: paused wf %d found, mark with flag "%s"', $wf_id, $rand_key ),
        PRIORITY => "debug",
        FACILITY => "workflow",
    );

    $self->{dbi}->start_txn;

    # it is necessary to explicitely set WORKFLOW_LAST_UPDATE,
    # because otherwise ON UPDATE CURRENT_TIMESTAMP will set (maybe) a non UTC timestamp

    # watchdog key will be reset automatically, when the workflow is updated from within
    # the API (via factory::save_workflow()), which happens immediately, when the action is executed
    # (see OpenXPKI::Server::Workflow::Persister::DBI::update_workflow())
    my $row_count;
    eval {
        $row_count = $self->{dbi}->update(
            table => $self->workflow_table,
            set => {
                watchdog_key => $rand_key,
                workflow_last_update => DateTime->now->strftime( '%Y-%m-%d %H:%M:%S' ),
            },
            where => {
                workflow_proc_state => 'pause',
                watchdog_key        => '__CATCHME',
                workflow_id         => $wf_id,
            },
        );
    };
    # We use DB transaction isolation level "READ COMMITTED":
    # So in the meantime another watchdog process might have picked up this
    # workflow and changed the database. Two things can happen:
    # 1. other process committed changes -> our update's where clause misses ($row_count = 0).
    # 2. other process did not commit -> timeout exception because of DB row lock
    if ($@ or $row_count < 1) {
        ##! 16: sprintf('some other process took wf %s, return', $wf_id)
        CTX('log')->log(
            MESSAGE  => sprintf( 'watchdog, paused wf %d: update with mark "%s" failed', $wf_id, $rand_key ),
            PRIORITY => "warn",
            FACILITY => ["workflow","system"]
        );
        return;
    }

    # Cancel if committing fails (e.g. because another process committed the same update)
    $self->{dbi}->commit;

    return $wf_id;
}

=head2

Check and, if necessary, create the session context

=cut

sub __check_session {

    my $self = shift;
    my ($force_new) = @_;
    my $session;
    unless($force_new){
        eval{$session = CTX('session');};
        return if $session;
    }

    my $directory = CTX('config')->get("system.server.session.directory");
    my $lifetime  = CTX('config')->get("system.server.session.lifetime");

    ##! 4: "create new session dir: $directory, lifetime: $lifetime "
    $session = OpenXPKI::Server::Session->new({
        DIRECTORY => $directory,
        LIFETIME  => $lifetime,
    });
    OpenXPKI::Server::Context::setcontext({'session' => $session,'force'=> $force_new});
    ##! 4: sprintf(" session %s created" , $session->get_id())
}


no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__
