package OpenXPKI::Server::Watchdog;
use Moose;


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

=item interval_sleep_overload

The number of seconds to sleep after the watchdog ran into an exception.
default: 15

=item max_tries_hanging_workflows

Try to restarted stale workflows this often before failing them.
default:  3

=item max_instance_count

Allow multiple watchdogs in parallel. This controls the number of control
process, setting this to more than one is usually not necessary (and also
not wise).

default: 1

=item max_worker_count

Maximum number of workers that the watchdog can run in parallel. No new
workflows are woke up if this limit is reached and the watchdog will
sleep for I<interval_sleep_overload> seconds.

default: 50

=item interval_wait_initial

Seconds to wait after server start before the watchdog starts scanning.
default: 10;

=item interval_loop_idle

Seconds between two scan runs if no result was found on last run.
default: 5

=item interval_loop_run

Seconds between two scan runs if a result was found on last run.
default: 1

=back

=item keep_parent_sigchld

I<Bool> value: set to 1 to prevent installation of special C<SIGCHLD> handler
and keep the current handler instead.
The special C<SIGCHLD> handler allows for execution of C<system()> and the like
in the parent process after starting the watchdog. But it will prevent reaping
zombie processes that are forked via other modules (e.g. L<Net::Server>).
Setting this to 1 should only be neccessary in the process where
L<Net::Server/run> is called.
default: 0

=back

=cut

# Core modules
use English;
use POSIX;

# CPAN modules
use Log::Log4perl::MDC;
use Try::Tiny;

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Control;
use OpenXPKI::Server;
use OpenXPKI::Server::Session;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::DateTime;
use OpenXPKI::Daemonize;


our $TERMINATE = 0;
our $RELOAD = 0;


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

has interval_sleep_overload => (
    is => 'rw',
    isa => 'Int',
    default =>  15
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

has max_worker_count => (
    is => 'rw',
    isa => 'Int',
    default =>  50
);
# All timers in seconds
has interval_wait_initial => (
    is => 'rw',
    isa => 'Int',
    default =>  10
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

has interval_session_purge => (
    is => 'rw',
    isa => 'Int',
    default => 0
);

has interval_auto_archiving => (
    is => 'rw',
    isa => 'Int',
    default => 0,
);

has keep_parent_sigchld => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
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

### TODO: maybe we should measure the count of exception in a certain time interval?
has _exception_count => (
    is => 'rw',
    isa => 'Int',
    init_arg => undef,
    default => 0,
);

has _next_session_cleanup => (
    is => 'rw',
    isa => 'Int',
    init_arg => undef,
);

has _next_auto_archiving => (
    is => 'rw',
    isa => 'Int',
    init_arg => undef,
);

has _session_purge_handler => (
    is => 'rw',
    isa => 'OpenXPKI::Server::Session',
    init_arg => undef,
    predicate => 'do_session_purge',
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

=head1 STATIC METHODS

=head2 _sig_hup

Signal handler for SIGHUP registered with the forked worker process.

Triggered by the master process when a reload happens.

=cut
sub _sig_hup {
    ##! 1: 'Got HUP'
    $RELOAD = 1;
    CTX('log')->system->info("Watchdog worker $$ got HUP signal - reloading config");
}

=head2 _sig_term

Signal handler for SIGTERM registered with the forked worker process.

Trigger by the master process to terminate the worker.

=cut
sub _sig_term {
    ##! 1: 'Got TERM'
    $TERMINATE  = 1;
    CTX('log')->system->info("Watchdog worker $$ got TERM signal - stopping");
}

=head2 start_or_reload

Static method to instantiate and start the watchdog or make it reload it's
config.

=cut
sub start_or_reload {
    my %args = @_;

    ##! 1: 'start_or_reload'
    my $pids = OpenXPKI::Control::get_pids();

    # Start watchdog if not running
    if (not scalar @{$pids->{watchdog}}) {
        my $config = CTX('config');

        return 0 if $config->get('system.watchdog.disabled');

        my $watchdog = OpenXPKI::Server::Watchdog->new( {
            user  => OpenXPKI::Server::__get_numerical_user_id(  $config->get('system.server.user') ),
            group => OpenXPKI::Server::__get_numerical_group_id( $config->get('system.server.group') ),
            keep_parent_sigchld => $args{keep_parent_sigchld} ? 1 : 0,
        } );

        $watchdog->run;
    }
    # Signal reload
    else {
        kill 'HUP', @{$pids->{watchdog}};
    }

    return 1;
}

=head2 terminate

Static method that looks for watchdog instances and sends them a SIGHUP signal.

This will NOT kill the watchdog but tell it to gracefully stop.

=cut
sub terminate {
    ##! 1: 'terminate'
    my $pids = OpenXPKI::Control::get_pids();

    if (scalar $pids->{watchdog}) {
        kill 'TERM', @{$pids->{watchdog}};
        CTX('log')->system()->info('Told watchdog to terminate');
    }
    else {
        CTX('log')->system()->error('No watchdog instances to terminate');
    }

    return 1;
}

=head1 METHODS

=head2 run

Forks away a worker child, returns the pid of the worker

=cut

sub run {
    my $self = shift;
    ##! 1: 'start'

    CTX('log')->system->info('Starting watchdog');

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
            log => { priority => 'error', facility => 'system' }
        );
    }

    my $fork_helper = OpenXPKI::Daemonize->new(
        sighup_handler  => \&OpenXPKI::Server::Watchdog::_sig_hup,
        sigterm_handler => \&OpenXPKI::Server::Watchdog::_sig_term,
        keep_parent_sigchld => $self->keep_parent_sigchld,
    );

    $fork_helper->gid($self->_gid) if $self->_gid;
    $fork_helper->uid($self->_uid) if $self->_uid;

    # FORK
    my $pid = $fork_helper->fork_child; # parent returns PID, child returns 0

    # parent process: return
    if ($pid > 0) { return $pid }

    # child process
    try {
        #
        # init
        #
        # create memory-only session for workflow
        my $session = OpenXPKI::Server::Session->new(type => "Memory")->create;
        OpenXPKI::Server::Context::setcontext({ session => $session, force => 1 });
        Log::Log4perl::MDC->put('sid', substr(CTX('session')->id,0,4));

        $self->{dbi}                      = CTX('dbi');
        $self->{hanging_workflows}        = {};
        $self->{hanging_workflows_warned} = {};
        $self->{original_pid}             = $PID;

        # set process name
        OpenXPKI::Server::__set_process_name("watchdog: init");

        CTX('log')->system()->info(sprintf( 'Watchdog initialized, delays are: initial: %01d, idle: %01d, run: %01d',
                $self->interval_wait_initial(), $self->interval_loop_idle(), $self->interval_loop_run() ));

        # wait some time for server startup...
        ##! 16: sprintf('watchdog: original PID %d, initially waiting for %d seconds', $self->{original_pid} , $self->interval_wait_initial());
        sleep($self->interval_wait_initial());

        $self->_exception_count(0);

        # setup helper object for purging expired sessions
        if ($self->interval_session_purge) {
            $self->_next_session_cleanup( time );
            $self->_session_purge_handler( OpenXPKI::Server::Session->new(load_config => 1) );
            CTX('log')->system->info("Initialize session purge from watchdog with interval " . $self->interval_session_purge);
        }

        if ($self->interval_auto_archiving) {
            $self->_next_auto_archiving( time );
            CTX('log')->system->info("Initialize auto-archiving from watchdog with interval " . $self->interval_auto_archiving);
        }

        #
        # main loop
        #
        $self->__main_loop;
    }
    catch {
        # make OpenXPKI::Exception compatible with Try::Tiny
        local $@ = $_;
        # make sure the cleanup code does not die as this would escape run()
        eval { CTX('log')->system->error($_) };
    };

    eval { $self->{dbi}->disconnect };
    eval { CTX('config')->cleanup() };

    ##! 1: 'End of run()'
    exit;   # child process MUST never leave run()
}

=head2 __main_loop

Watchdog main loop (child process).

Runs until the package scope variable C<$TERMINATE> is set to C<1>.

=cut
sub __main_loop {
    my $self = shift;

    my $slots_avail_count = $self->max_worker_count();
    while (not $TERMINATE) {
        ##! 64: 'watchdog: do loop'
        try {
            $self->__reload if $RELOAD;
            $self->__purge_expired_sessions;
            $self->__auto_archive_workflows;

            # if slots_avail_count is zero, do a recalculation
            if (!$slots_avail_count) {
                ##! 8: 'no slots available - doing recalculation'
                $slots_avail_count = $self->max_worker_count();
                my $pt = Proc::ProcessTable->new;
                foreach my $ps (@{$pt->table}) {
                    if ($ps->ppid == $$) {
                        ##! 32: 'Found watchdog child '.$ps->pid.' - remaining process count: ' . $slots_avail_count
                        last unless ($slots_avail_count--);
                    }
                }
            }

            ##! 32: 'available slots: ' . $slots_avail_count

            # duration of pause depends on whether a workflow was found or not
            my $sec = $self->interval_loop_idle;
            if (!$slots_avail_count) {
                ##! 16: 'watchdog paused - too much load'
                $sec = $self->interval_sleep_overload;
                OpenXPKI::Server::__set_process_name("watchdog (OVERLOAD)");
                CTX('log')->system->warn(sprintf "Watchdog process limit (%01d) reached, will sleep for %01d seconds", $self->max_worker_count(), $sec );
            } elsif (my $wf_id = $self->__scan_for_paused_workflows()) {
                ##! 32: 'watchdog busy - forked child for wf ' . $wf_id
                $sec = $self->interval_loop_run;
                $slots_avail_count--;
                OpenXPKI::Server::__set_process_name("watchdog (busy)");
            } else {
                ##! 32: 'watchdog idle'
                OpenXPKI::Server::__set_process_name("watchdog (idle)");
            }
            ##! 64: sprintf('watchdog sleeps %d secs', $sec)

            sleep($sec);
            # Reset the exception counter after every successfull loop
            $self->_exception_count(0);

        }
        catch {
            $self->_exception_count($self->_exception_count + 1);

            my $error_msg = "Watchdog fatal error: $_";
            my $sleep = $self->interval_sleep_exception();

            print STDERR $error_msg, "\n";

            CTX('log')->system->error("$error_msg (having a nap for $sleep sec; ".$self->_exception_count." exceptions in a row)");

            my $threshold = $self->max_exception_threshhold();
            if ($threshold > 0 and $self->_exception_count > $threshold) {
                my $msg = "Watchdog exception limit ($threshold) reached, exiting!";
                print STDERR $msg, "\n";
                OpenXPKI::Exception->throw(
                    message => $msg,
                    log => { priority => 'fatal', facility => 'system' },
                );
            }

            # sleep to give the system a chance to recover
            sleep($sleep);
        };
    }
}

=head2 __purge_expired_sessions

Purge expired sessions from backend if enough time elapsed.

=cut
sub __purge_expired_sessions {
    my $self = shift;

    return unless $self->do_session_purge and time > $self->_next_session_cleanup;

    CTX('log')->system()->debug("Init session purge from watchdog");
    $self->_session_purge_handler->purge_expired;
    $self->_next_session_cleanup( time + $self->interval_session_purge );
}

# Does the actual reloading during the main loop
sub __reload {
    my $self = shift;

    $RELOAD = 0;

    my $config = CTX('config');

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
        interval_session_purge
        interval_auto_archiving
    )) {
        if ($new_cfg->{$key}) {
            ##! 16: 'Update key ' . $key
            $self->$key( $new_cfg->{$key} )
        }
    }

    # Re-Init the Notification backend
    OpenXPKI::Server::Context::setcontext({
        notification => OpenXPKI::Server::Notification::Handler->new(),
        force => 1,
    });

    CTX('log')->system()->info('Watchdog worker reloaded');
}

=head2 __scan_for_paused_workflows

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
        from  => 'workflow',
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
        ##! 64: 'no paused WF found, can be idle again...'
        return;
    }

    ##! 16: 'found paused workflow: '.Dumper($workflow)

    #select again:
    my $wf_id = $workflow->{workflow_id};
    $self->__flag_for_wakeup( $wf_id ) or return;

    ##! 16: 'WF now ready to re-instantiate '
    CTX('log')->workflow()->info(sprintf( 'watchdog, paused wf %d now ready to re-instantiate, start fork process', $wf_id ));


    $self->__wake_up_workflow({
        workflow_id         => $workflow->{workflow_id},
        workflow_type       => $workflow->{workflow_type},
        workflow_session    => $workflow->{workflow_session},
        pki_realm           => $workflow->{pki_realm},
    });

    return $wf_id;
}

=head2 __flag_for_wakeup( wf_id )

Flag the workflow with the given ID as "being woken up" via database.

To prevent a workflow from being reloaded by two watchdog instances, this
method first writes a random marker to create "row lock" and tries to reload
the row using this marker. If either one fails, returnes undef.

=cut

sub __flag_for_wakeup {
    my ($self, $wf_id) = @_;

    return unless $wf_id;    #this is real defensive programming ...;-)

    #FIXME: Might add some more entropy or the server id for cluster oepration
    my $rand_key = sprintf( '%s_%s_%s', $PID, time(), sprintf( '%02.d', rand(100) ) );

    ##! 16: 'set random key '.$rand_key

    CTX('log')->workflow()->debug(sprintf( 'watchdog: paused wf %d found, mark with flag "%s"', $wf_id, $rand_key ));


    $self->{dbi}->start_txn;

    # it is necessary to explicitely set WORKFLOW_LAST_UPDATE,
    # because otherwise ON UPDATE CURRENT_TIMESTAMP will set (maybe) a non UTC timestamp

    # watchdog key will be reset automatically, when the workflow is updated from within
    # the API (via factory::save_workflow()), which happens immediately, when the action is executed
    # (see OpenXPKI::Server::Workflow::Persister::DBI::update_workflow())
    my $row_count;
    eval {
        $row_count = $self->{dbi}->update(
            table => 'workflow',
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
        $self->{dbi}->commit;
    };
    # We use DB transaction isolation level "READ COMMITTED":
    # So in the meantime another watchdog process might have picked up this
    # workflow and changed the database. Two things can happen:
    # 1. other process committed changes -> our update's where clause misses ($row_count = 0).
    # 2. other process did not commit -> timeout exception because of DB row lock
    if ($@ or $row_count < 1) {
        ##! 16: sprintf('some other process took wf %s, return', $wf_id)
        $self->{dbi}->rollback;
        CTX('log')->system()->warn(sprintf( 'watchdog, paused wf %d: update with mark "%s" failed', $wf_id, $rand_key ));
        return;
    }

    return $wf_id;
}


=head2 __wake_up_workflow

Restore the session environment and execute the action, runs in eval
block and returns the error message in case of error.

=cut

sub __wake_up_workflow {
    my ($self, $args) = @_;

    $self->__restore_session($args->{pki_realm}, $args->{workflow_session});

    $self->{dbi}->start_txn;

    ##! 1: 'call wakeup'
    my $wf_info = CTX('api2')->wakeup_workflow(
        id => $args->{workflow_id},
        async => 1,
        wait => 0,
    );
    ##! 32: 'wakeup returned ' . Dumper $wf_info

    # commit/rollback is done inside workflow engine
}

sub __restore_session {
    my ($self, $realm, $frozen_session) = @_;

    CTX('session')->data->pki_realm($realm);     # set realm
    CTX('session')->data->thaw($frozen_session); # set user and role

    # Set MDC for logging
    Log::Log4perl::MDC->put('user', CTX('session')->data->user);
    Log::Log4perl::MDC->put('role', CTX('session')->data->role);
    Log::Log4perl::MDC->put('sid', substr(CTX('session')->id,0,4));
}

=head2 __auto_archive_workflows

Archive workflows whose "archive_at" date was exceeded.

=cut

sub __auto_archive_workflows {
    my $self = shift;

    return unless ($self->interval_auto_archiving and time > $self->_next_auto_archiving);

    CTX('log')->system->debug("Init workflow auto archiving from watchdog");

    # Search for paused workflows that are ready to be archived.
    my $rows = $self->{dbi}->select_hashes(
        from  => 'workflow',
        columns => [ qw(
            workflow_id
            workflow_type
            workflow_session
            pki_realm
            workflow_archive_at
        ) ],
        where => {
            'workflow_proc_state' => { '!=', 'archived' },
            'workflow_archive_at' => { '<', time() },
        },
    );

    ##! 16: 'Archiving candidates: ' . join(', ', map { $_->{workflow_id} } @$rows)

    my $id;
    # Don't crash Watchdog only if some archiving fails
    try {
        for my $row (@$rows) {
            $id = $row->{workflow_id};
            $self->__flag_for_archiving($row->{workflow_id}, $row->{workflow_archive_at}) or next;
            $self->__restore_session($row->{pki_realm}, $row->{workflow_session});

            my $workflow = CTX('workflow_factory')->get_factory->fetch_workflow($row->{workflow_type}, $row->{workflow_id});
            # Archive workflow: does DB update, might throw exception on wrong proc_state etc.
            # Also sets "archive_at" to undef.
            $workflow->set_archived;
        }
    }
    catch {
        CTX('log')->system->error(sprintf('Error archiving wf %s: %s', $id, $_));
    };

    $self->_next_auto_archiving( time + $self->interval_auto_archiving );
}

=head2 __flag_for_archiving( wf_id )

Flag the workflow with the given ID as "being archived" via database to prevent
a workflow from being archived by two watchdog instances.

Flagging is done by updating DB field C<workflow_archive_at> with an
intermediate value of C<0>. It is updated to C<null> once archiving is
finished, so a permanent value of C<0> indicates a severe error.

Returns C<1> upon success or C<undef> if workflow is/was archived by another
process.

=cut

sub __flag_for_archiving {
    my ($self, $wf_id, $expected_archive_at) = @_;

    return unless ($wf_id and $expected_archive_at);

    CTX('log')->workflow->debug(sprintf('watchdog: auto-archiving wf %d, setting flag', $wf_id));

    $self->{dbi}->start_txn;

    # Flag workflow as "being archived" by setting "workflow_archive_at" to
    # an intermediate value of "0". It is updated to undef once archiving is
    # finished, so when checking workflows later on a "0" indicates a
    # severe error during archiving.
    my $update_count;
    try {
        # "" it to undef later on, so a permanent value of 0 is an indicator
        $update_count = $self->{dbi}->update(
            table => 'workflow',
            set => {
                workflow_archive_at => 0,
            },
            where => {
                workflow_archive_at => $expected_archive_at,
                workflow_id         => $wf_id,
            },
        );
        $self->{dbi}->commit;
    }
    # We use DB transaction isolation level "READ COMMITTED":
    # So in the meantime another watchdog process might have picked up this
    # workflow and changed the database. Two things can happen:
    # 1. other process did not commit -> timeout exception because of DB row lock
    catch {
        $self->{dbi}->rollback;
        CTX('log')->system->warn(sprintf('watchdog: auto-archiving wf %d failed (most probably other process does same job): %s', $wf_id, $_));
        return;
    };
    # 2. other process committed changes -> our update's where clause misses ($update_count = 0).
    if ($update_count < 1) {
        CTX('log')->system->warn(sprintf('watchdog: auto-archiving wf %d failed (already archived by other process)', $wf_id));
        return;
    }

    return 1;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__
