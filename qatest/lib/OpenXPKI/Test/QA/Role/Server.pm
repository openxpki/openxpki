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

=cut

# Core modules
use File::Temp qw( tempdir );
use IPC::SysV qw(IPC_PRIVATE IPC_CREAT IPC_EXCL S_IRWXU IPC_NOWAIT);
use IPC::Semaphore;
use Test::More;

# CPAN modules
use Proc::Daemon;

# Project modules
use OpenXPKI;
use OpenXPKI::Control;
use OpenXPKI::Server;
use OpenXPKI::Test::QA::Role::Server::ClientHelper;


requires "testenv_root";
requires 'default_realm'; # effectively requires 'OpenXPKI::Test::QA::Role::SampleConfig'
                          # we can't use with '...' because if other roles also said that then it would be applied more than once


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

before 'init_user_config' => sub { # ... so we do not overwrite user supplied configs
    my $self = shift;

    #
    # add authentication handler required by OpenXPKI::Test::QA::Role::Server::ClientHelper
    #
    my $realm = $self->default_realm;
    $self->config_writer->add_user_config(
        "realm.$realm.auth.stack" => {
            Test => {
                description => "OpenXPKI test auth stack",
                handler => "OxiTest",
            },
        },
        "realm.$realm.auth.handler" => {
            OxiTest => {
                label => "OpenXPKI Test Authentication Handler",
                type  => "Password",
                user  => {
                    # password is always "openxpki"
                    caop =>  { digest => $self->password_hash, role => "CA Operator" },
                    raop =>  { digest => $self->password_hash, role => "RA Operator" },
                    raop2 => { digest => $self->password_hash, role => "RA Operator" },
                    user =>  { digest => $self->password_hash, role => "User" },
                    user2 => { digest => $self->password_hash, role => "User" },
                },
            },
        },
    );
};

=head2 init_server

(Replaces L<OpenXPKI::Test/init_server>)

Fork off a child process (via L<Proc::Daemon>) which then starts the OpenXPKI
test server in background mode (i.e. initialization, forking and main loop).

Waits max. 5 seconds for the background forking and another 5 seconds for the
socket file to appear.

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
    # go beyong "loop()" (called by "run()") so we could not start our tests
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
        eval {
            # init_server() must be called after Proc::Daemon->Init() because the latter
            # closes all file handles which would cause problems with Log4perl
            $self->$orig();                  # OpenXPKI::Test->init_server
            $self->init_session_and_context; # this step from OpenXPKI::Test->BUILD would otherwise not be executed as this method never returns
            $self->_start_openxpki_server($orig);
        };
        exit;
    }
    # Proc::Daemon parent ...
    note "PID of launcher process that starts up OpenXPKI: $parentpid";
    $self->parent_pid($parentpid);

    # wait till child process unlocks semaphore
    # (# semaphore #0, operation 0)
    for (my $tick = 0; $tick < 3 and not $sem->op(0, 0, IPC_NOWAIT); $tick++) {
        sleep 1;
    }
    if (not $sem->op(0, 0, IPC_NOWAIT)) { $self->stop_server; die "Server init seems to have failed" }

    # wait for Net::Server->run() to initialize (includes forking)
    note "Waiting for OpenXPKI to initialize";
    my $count = 0;
    my $pidfile = $self->path_pid_file;
    while ($count++ < 5 and not -f $pidfile) { sleep 1 }
    if (not -f $pidfile) { $self->stop_server; die "Server forking seems to have failed" }

    # read PID
    my $pid = do { local $/; open my $fh, '<', $pidfile; <$fh> }; # slurp
    chomp $pid;
    $self->server_pid($pid);

    # wait for OpenXPKI to start up
    note "Waiting for OpenXPKI to create socket file";
    $count = 0;
    my $socket = $self->path_socket_file;
    while ($count++ < 5 and not -e $socket) { sleep 1 }
    if (not -e $socket) { $self->stop_server; die "Server startup seems to have failed" }

    note "Main test process: server startup completed";
    $self->$orig(); # to make context etc. also available to main test process
};

# Imitate OpenXPKI::Server->start()
sub _start_openxpki_server {
    my ($self, $server_init_callback) = @_;
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
        OpenXPKI::Control::stop({ PID => $self->server_pid}); # stop server and child processes
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
        socket_file => $self->get_config("system.server.socket_file"),
        default_realm => $self->default_realm,
        password => $self->password,
    );
}

sub DEMOLISH {
    my $self = shift;
    $self->stop_server;
}

1;
