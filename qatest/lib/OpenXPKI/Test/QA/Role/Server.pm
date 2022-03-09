package OpenXPKI::Test::QA::Role::Server;
use Moose::Role;

=head1 NAME

OpenXPKI::Test::QA::Role::Server - Moose role that extends L<OpenXPKI::Test> to
start a (forking) OpenXPKI test server.

=head1 DESCRIPTION

This role replaces L<OpenXPKI::Test/init_server> with a version that actually
starts a server daemon instead of just setting up the C<CTX> context objects.

Please note that this role requires another role to be applied:
L<OpenXPKI::Test::QA::Role::SampleConfig>, i.e.:

    my $oxitest = OpenXPKI::Test->new(
        with => [ "SampleConfig", "Server" ],
        ...
    );

To start the server watchdog process, specify C<start_watchdog =E<gt> 1> (see
L<OpenXPKI::Test::QA::Role::SampleConfig>):

    my $oxitest = OpenXPKI::Test->new(
        with => [ "SampleConfig", "Server" ],
        start_watchdog => 1,
        ...
    );

=cut

# Core modules
use IPC::SysV qw(IPC_PRIVATE IPC_CREAT IPC_EXCL S_IRWXU IPC_NOWAIT);
use IPC::Semaphore;
use Test::More;

# CPAN modules
use Proc::Daemon;
use Try::Tiny;

# Project modules
use OpenXPKI::Control;
use OpenXPKI::Server;
use OpenXPKI::Test::QA::Role::Server::ClientHelper;


requires "testenv_root";


=head1 METHODS

=cut

has daemon => (
    is => 'rw',
    isa => 'Proc::Daemon',
    init_arg => undef,
);

has parent_pid => (
    is => 'rw',
    isa => 'Int',
    init_arg => undef,
    clearer => 'clear_parent_pid',
);

has server_pid => (
    is => 'rw',
    isa => 'Int',
    init_arg => undef,
    clearer => 'clear_server_pid',
);

has semaphore => (
    is => 'rw',
    isa => 'IPC::Semaphore',
    init_arg => undef,
);


=head2 client

Returns a singleton instance of L<OpenXPKI::Test::QA::Role::Server::ClientHelper>
that can be used to test client commands against the running server.

=cut
has client => (
    is => 'rw',
    isa => 'OpenXPKI::Test::QA::Role::Server::ClientHelper',
    init_arg => undef,
    lazy => 1,
    predicate => 'has_client',
    builder => 'new_client_tester',
);

=head2 init_server

(Replaces L<OpenXPKI::Test/init_server>)

Fork off a child process (via L<Proc::Daemon>) which then starts the OpenXPKI
test server in background mode (i.e. initialization, forking and main loop).

Waits max. 10 seconds for the background forking, 10 seconds for the PID file
to appear and 10 for the socket file to appear.

Returns the PID of the OpenXPKI server.

=cut
around 'init_server' => sub {
    my $orig = shift;
    my $self = shift;

    # prepend to existing array in case a user supplied "also_init" needs our modules
    unshift @{ $self->also_init }, 'crypto_layer';

    # fork server process
    note "Starting test server...";

    # We need Proc::Daemon because Net::Server::Fork's parent process will not
    # go beyond "loop()" (called by "run()") so we could not start our tests
    # otherwise.
    # We use a semaphore to know when the child process has finished the server
    # initialization tasks.

    # create semaphore set with 1 member
    my $sem = IPC::Semaphore->new(IPC_PRIVATE, 1, S_IRWXU | IPC_CREAT | IPC_EXCL)
        or die "Could not create semaphore: $!";
    $self->semaphore($sem);
    # lock semaphore (set semaphore #0 to 1)
    $self->semaphore->setval(0,1)
        or die "Could not set semaphore: $!";

    $self->daemon(
        Proc::Daemon->new(
            work_dir => $self->testenv_root,
            $ENV{TEST_VERBOSE} ? ( dont_close_fh => [ 'STDOUT', 'STDERR' ] ) : (),
        )
    );

    # fork Proc::Daemon child process
    my $parentpid = $self->daemon->Init;
    die "Error forking client process which should start OpenXPKI" unless defined $parentpid;

    # Proc::Daemon child (forked server)...
    unless ($parentpid) {
        # start up server
        try {
            # re-init logging after fork to open files that might have been closed
            $self->init_logging;
            # init_server() must be called after Proc::Daemon->Init() because the latter
            # closes all file handles which would cause problems with Log4perl
            $self->$orig();                  # OpenXPKI::Test->init_server
            $self->init_session_and_context; # this step from OpenXPKI::Test->BUILD would otherwise not be executed as we never return
            $self->_start_openxpki_server;
        }
        catch {
            eval { Log::Log4perl->get_logger()->error($_) };
        };
        exit;
    }
    # Proc::Daemon parent ...
    note "PID of launcher process that starts up OpenXPKI: $parentpid";
    $self->parent_pid($parentpid);

    # wait till child process unlocks semaphore
    # (# semaphore #0, operation 0)
    my $tick = 0;
    while ($tick++ < 10 and not $sem->op(0, 0, IPC_NOWAIT)) { sleep 1 }
    if (not $sem->op(0, 0, IPC_NOWAIT)) { $self->diag_log; $self->stop_server; die "Server init seems to have failed (after $tick seconds)" }

    # wait for Net::Server->run() to initialize (includes forking)
    note "Waiting for OpenXPKI to initialize";
    $tick = 0;
    my $pidfile = $self->path_pid_file;
    while ($tick++ < 10 and not -f $pidfile) { sleep 1 }
    if (not -f $pidfile) { $self->diag_log; $self->stop_server; die "Server forking seems to have failed (after $tick seconds)" }

    # read PID
    my $pid = do { local $/; open my $fh, '<', $pidfile; <$fh> }; # slurp
    chomp $pid;
    $self->server_pid($pid);

    # wait for OpenXPKI to start up
    note "Waiting for OpenXPKI to create socket file";
    $tick = 0;
    my $socket = $self->path_socket_file;
    while ($tick++ < 10 and not -e $socket) { sleep 1 }
    if (not -e $socket) { $self->diag_log; $self->stop_server; die "Server startup seems to have failed (after $tick seconds)" }

    note "Main test process: server startup completed";
    $self->$orig(); # to make context etc. also available to main test process
};

# Imitate OpenXPKI::Server->start()
sub _start_openxpki_server {
    my ($self) = @_;
    # TODO Replace test specific server startup with OpenXPKI::Server->start() once we have a complete test env (so all context objects + watchdog will be initialized)

    OpenXPKI::Server::Watchdog->start_or_reload;

    my $server = OpenXPKI::Server->new(
        'SILENT' => $ENV{TEST_VERBOSE} ? 0 : 1,
        'TYPE'   => 'Fork', # type "Fork" will background (fork) the main server process and also fork off child processes on incoming requests
    );
    $server->__init_user_interfaces;
    $server->__init_net_server;

    # unlock semaphore
    $self->semaphore->op(0, -1, IPC_NOWAIT);

    # run() will fork the server main process because OpenXPKI::Server sets
    # parameter "background => 1". The parent process is exited (this is
    # why we need Proc::Daemon, otherwise the test process would be exited).
    $server->run(%{$server->{PARAMS}}); # Net::Server::MultiType->run()
}

=head2 is_server_alive

Returns TRUE if the OpenXPKI server process is running (i.e. checks the PID).

=cut
sub is_server_alive {
    my $self = shift;
    return (kill(0, $self->server_pid) != 0);
}

=head2 stop_server

Stops the OpenXPKI test server. Waits max. 5 seconds for the shutdown to finish.

=cut
sub stop_server {
    my $self = shift;

    # Try to stop the OpenXPKI process and wait max. 5 seconds for OpenXPKI to finish shutdown
    if ($self->server_pid) {
        OpenXPKI::Control::stop({ PID => $self->server_pid}) if kill(0, $self->server_pid) != 0; # stop server and child processes
#        kill 'INT', $self->server_pid;
#        my $count = 0;
#        while ($count++ < 5 and $self->is_server_alive) { sleep 1 }
#        diag "Could not shutdown test server" if $self->is_server_alive;
        $self->clear_server_pid;
    }

    # Kill the Proc::Daemon child process that started OpenXPKI
    # (although it should be dead by now)
    if ($self->daemon and $self->parent_pid) {
        $self->daemon->Kill_Daemon($self->parent_pid);
        $self->clear_parent_pid;
    }
}

=head2 new_client_tester

Returns a new instance of L<OpenXPKI::Test::QA::Role::Server::ClientHelper>
that is used to test client commands against the running server.

=cut
sub new_client_tester {
    my ($self) = @_;

    return OpenXPKI::Test::QA::Role::Server::ClientHelper->new(
        socket_file => $self->get_conf("system.server.socket_file"),
        password => $self->password,
    );
}

# no-op DEMOLISH in case the consuming class does not have one. If it does have
# one, that will win. Then we modify it (theirs or ours)
# Also see: http://www.perlmonks.org/?node_id=837397
# TODO Convert into exit hook once we migrated to Test2 (see https://metacpan.org/dist/Test2-Suite/source/lib/Test2/Plugin/ExitSummary.pm)
sub DEMOLISH {}
before DEMOLISH => sub {
    my $self = shift;
    $self->stop_server;
};

1;
