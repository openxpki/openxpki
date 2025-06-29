package OpenXPKI::Control::Client;
use OpenXPKI -class;

with 'OpenXPKI::Control::Role';

=head1 DESCRIPTION

Control OpenXPKI service handler (web server) processes.

Configuration path: C<system.server>

=head1 OpenXPKI::Control::Client

As the backend of C<openxpkictl COMMAND client> (i.e. the I<client> scope)
this class implements all methods required by L<OpenXPKI::Control::Role>.

=cut

# CPAN modules
use Mojo::Server::Prefork;
use Mojo::Util qw( extract_usage getopt url_escape monkey_patch );
use Mojo::File;

# Project modules
use OpenXPKI::Log4perl;
use OpenXPKI::Client::Service::Config;

has cfg => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    default => sub ($self) {
        return {
            pid_file => $OpenXPKI::Defaults::CLIENT_PID,
            socket_file => $OpenXPKI::Defaults::CLIENT_SOCKET,
            $self->config->get_hash('system.server')->%*,
        };
    }
);

has config => (
    is => 'ro',
    isa => 'Connector',
    lazy => 1,
    default => sub ($self) {
        return OpenXPKI::Client::Service::Config->new(
            config_dir => $self->config_path
        );
    }
);

has '+config_path' => (
    default => $OpenXPKI::Defaults::CLIENT_CONFIG_DIR,
);

has silent => (
    is => 'ro',
    isa => 'Bool',
    init_arg => undef,
    lazy => 1,
    default => sub { $_[0]->opts->{quiet} ? 1 : 0 },
);

has foreground => (
    is => 'ro',
    isa => 'Bool',
    init_arg => undef,
    lazy => 1,
    default => sub { $_[0]->systemd_mode || $_[0]->dev_mode || $_[0]->opts->{nd} ? 1 : 0 },
);

has systemd_mode => (
    is => 'ro',
    isa => 'Bool',
    init_arg => undef,
    lazy => 1,
    default => sub { $_[0]->opts->{systemd} ? 1 : 0 },
);

has dev_mode => (
    is => 'ro',
    isa => 'Bool',
    init_arg => undef,
    lazy => 1,
    default => sub { $_[0]->opts->{dev} ? 1 : 0 },
);

# required by OpenXPKI::Control::Role
sub getopt_params ($self, $command) {
    return qw(
        dev|d
        user|u=s
        group|g=s
        pid_file|pid-file|p=s
        socket_file|socket-file|s=s
        socket_group|socket-group=s
        socket_mode|socket-mode=s
        systemd
        workers=i
        nd|no-detach
        quiet
    );
}

# required by OpenXPKI::Control::Role
sub cmd_start ($self) {
    my $pid = $self->__get_pid;
    if (defined $pid and $self->status(silent => 1) == 0) {

        # Workaround for docker - PID is always 1 and pid_file is not
        # removed on a crash so we will never start again....
        if ($PID == 1 and $pid == $PID) {
            warn "OpenXPKI Client skipping old PID == 1\n";
        } else {
            warn "OpenXPKI Client already running. PID: $pid\n";
            return 0;
        }
    }

    OpenXPKI::Log4perl->set_default_facility('openxpki.client.server');
    my $log = OpenXPKI::Log4perl->get_logger;

    $log->logdie("--dev and --systemd are mutual exclusive options")
        if ($self->dev_mode and $self->systemd_mode);

    $log->logdie("Attempt to run background process with console logging: this leads to hidden log messages.\n".
                 "Please set the log target (system.logger.target) either to 'file' or 'none'")
        if ($self->config->system_logger_target eq 'console' and not $self->foreground);

    my $setup_log4perl = 1;

    # Development mode
    if ($self->dev_mode) {
        $ENV{MOJO_MODE} = 'development';
        $log->warn('Development mode - skip log4perl setup and log to screen');
        $setup_log4perl = 0;

    # Production mode
    } else {
        $ENV{MOJO_MODE} = 'production';

        # Re-Initialize Log4perl with client config
        my $log4perl_conf = $self->config->log4perl_conf(
            current_level => $self->global_opts->{l4p_level},
        );
        if ($log->is_trace) {
            # trace log this BEFORE Log4perl re-init, i.e. if "openxpkictl -vvv ..." was called
            my $indented = $log4perl_conf;
            $indented =~ s/^/    /gm;
            $log->trace("Generated Log4perl configuration:\n$indented");
        }
        if ($self->config->system_logger_target eq 'none') {
            $log->warn('Logging will be disabled according to config (system.logger.target: none)')
        } else {
            $log->info('Set up logging according to config in ' . $self->config_path);
        };

        OpenXPKI::Log4perl->init_or_fallback( \$log4perl_conf );
    }

    $log->trace('ENV = ' . Dumper \%ENV) if $log->is_trace;

    my $user = $self->opts->{user} || $self->cfg->{user};
    my $group = $self->opts->{group} || $self->cfg->{group};

    my %server_params;  # parameters passed to Mojo::Server::Prefork
    my %web_params;     # parameters passed to OpenXPKI::Client::Web

    # systemd provided socket file descriptors
    if ($self->systemd_mode) {
        $log->info('systemd mode: use existing socket (read from LISTEN_FDS); skip PID file creation');
        die "LISTEN_PID is not set but required in systemd mode\n" unless $ENV{LISTEN_PID};
        die "LISTEN_FDS is not set but required in systemd mode\n" unless $ENV{LISTEN_FDS};
        die "LISTEN_PID contains different process ID: $ENV{LISTEN_PID} != $$\n" unless $ENV{LISTEN_PID} eq $$;

        %server_params = (
            listen => [
                map { sprintf 'http+unix://%s?fd=%i', $self->__file_url_from_fd($_), $_ }
                map { $_+2 }
                1..$ENV{LISTEN_FDS}
            ],
        );

    # manually configured sockets
    } else {
        my $pid_file = $self->__get_pid_file
            or die "Missing config entry: system.client.pid_file\n";
        my $socket_file = $self->opts->{socket_file} || $self->cfg->{socket_file}
            or die "Missing config entry: system.client.socket_file\n";

        %server_params = (
            pid_file => $pid_file,
            listen => [ sprintf 'http+unix://%s', $self->__file_url($socket_file) ],
        );

        # each parameter might be undef:
        %web_params = (
            oxi_socket_owner => $user,
            oxi_socket_group => $self->opts->{socket_group} || $self->cfg->{socket_group} || $group,
            oxi_socket_mode => $self->opts->{socket_mode} || $self->cfg->{socket_mode},
        );
    }

    if (my $workers = ($self->opts->{workers} || $self->cfg->{prefork}->{workers})) {
        $server_params{workers} = $workers;
        $log->debug(sprintf('setting worker count to %01d', $workers));
    }

    # prevent the server from creating a PID file
    monkey_patch 'Mojo::Server::Prefork', ensure_pid_file => sub { } if $self->systemd_mode;

    my $daemon = Mojo::Server::Prefork->new(
        %server_params,
        reverse_proxy => 1,
        cleanup => 0, # don't try to delete PID file (would fail for non-root user and PID file e.g. below /run )
    );

    $daemon->check_pid; # delete any old PID file

    $daemon->build_app('OpenXPKI::Client::Web' => {
        %web_params,
        # Mojo attribute: explicitely pass our logger to Mojolicious
        log => $log,
        # daemon owner
        oxi_user => $user, # might be undef
        oxi_group => $group, # might be undef
        # config object
        oxi_config_obj => $self->config(),
    });

    my $start_client = sub {
        $daemon->start;
        $daemon->daemonize unless $self->foreground;
        $daemon->run;
    };

    # foreground mode
    if ($self->foreground) {
        try {
            $start_client->();
        }
        catch ($err) {
            warn $err;
            return 2;
        }
        return 0;

    # background mode
    } else {
        return $self->fork_launcher($start_client);
    }
}

# required by OpenXPKI::Control::Role
sub cmd_stop ($self) {
    my $pid = $self->__get_pid;

    my $code = $self->stop_process(
        name => 'OpenXPKI Client',
        pid => $pid,
        silent => $self->silent,
    );

    eval { unlink $self->__get_pid_file } if $code == 0;

    return $code;
}

# required by OpenXPKI::Control::Role
sub cmd_reload ($self) {
    return $self->cmd_restart;
}

# required by OpenXPKI::Control::Role
sub cmd_restart ($self) {
    $self->cmd_stop;
    return $self->cmd_start;
}

# required by OpenXPKI::Control::Role
sub cmd_status ($self) {
    return $self->status(silent => $self->silent);
}

=head2 status

Check if the client is running

B<Named parameters>

=over

=item * C<silent> I<Bool> - optional: suppress messages. Default: 0

=back

=cut
signature_for status => (
    method => 1,
    named => [
        silent => 'Bool', { default => 0 },
    ],
);
sub status ($self, $arg) {
    my $pid = $self->__get_pid;
    my $alive = defined $pid ? kill(0, $pid) : 0;

    if ($alive) {
        print "OpenXPKI Client is running.\n" unless $arg->silent;
        return 0;
    } else {
        warn "OpenXPKI client is not running.\n" unless $arg->silent;
        return 1;
    }
}

sub __get_pid ($self) {
    my $pid_file = $self->__get_pid_file() ||
        die "Missing config entry: system.client.pid_file\n";
    return $self->slurp_if_exists($pid_file);
}

sub __get_pid_file ($self) {
    return $self->opts->{pid_file} || $self->cfg->{pid_file};
}

sub __file_url ($self, $path) {
    return url_escape(Mojo::File->new($path));
}

sub __file_url_from_fd ($self, $fd) {
    my $path = readlink("/proc/self/fd/$fd") or die "Could not resolve file descriptor '$fd'";

    if (not $path =~ /^\//) {
        if ($path =~ /^socket:\[(\d+)\]$/) {
            $path = $self->__socket_path_from_inode($1) or die "Could not resolve inode '$1' into socket path";
        } else {
            die "Cannot handle file descriptor $fd: $path";
        }
    }

    return $self->__file_url($path);
}

sub __socket_path_from_inode ($self, $inode) {
    open my $fh, '<', '/proc/self/net/unix' or die "Cannot open /proc/self/net/unix: $!";
    <$fh>; # skip header
    while (my $line = <$fh>) {
        chomp $line;
        my @fields = split /\s+/, $line;
        if ($inode == $fields[6]) {
            return $fields[7] // '';
        }
    }
    return '';
}

__PACKAGE__->meta->make_immutable;

=head1 OPTIONS

=over

=item B<--user NAME|UID>

=item B<-u NAME|UID>

Target user for the web server process (default: current user)

=item B<--group NAME|GID>

=item B<-g NAME|GID>

Target group for the web server process (default: current group)

=item B<--systemd>

systemd mode:

=over

=item * use existing AF_UNIX domain socket file (provided as a file descriptor
no. by systemd via ENV variable LISTEN_FDS),

=item * do not create a PID file,

=item * do not fork, i.e. do not send daemon to background (= C<--no-detach>).

=back

In this mode the options C<--pid-file>, C<--socket-file>, C<--socket-owner>,
C<--socket-group> and C<--socket-mode> will be ignored.

=item B<--pid-file PATH>

=item B<-p PATH>

Path of the PID file (required unless C<--systemd> is used)

=item B<--socket-file PATH>

=item B<-s PATH>

Path of the socket file (required unless C<--systemd> is used)

=item B<--socket-owner NAME|UID>

Target user for the socket file (default: same as --user or current user)

=item B<--socket-group NAME|GID>

Target group for the socket file (default: same as --group or current group)

=item B<--socket-mode OCTAL_MODE>

Permissions for the socket file (default: use umask upon creation or keep
current permissions if socket file already exists)

=item B<--no-detach>

=item B<--nd>

Do not fork, i.e. do not send daemon to background.

=item B<--dev>

=item B<-d>

Development mode:

=over

=item * stay in foreground (equals C<--nd>).

=item * treat all requests as if transmitted over HTTPS,

=item * print detailed Mojolicious exceptions.

=item * print all messages to screen (ignores any Log4perl configuration).

=back

=back
