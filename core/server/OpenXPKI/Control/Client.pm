package OpenXPKI::Control::Client;
use OpenXPKI -class;

with 'OpenXPKI::Control::Role';

=head1 DESCRIPTION

Control OpenXPKI service handler (web server) processes.

Configuration path: C<system.client>

=head1 OpenXPKI::Control::Client

As the backend of C<openxpkictl COMMAND client> (i.e. the I<client> scope)
this class implements all methods required by L<OpenXPKI::Control::Role>.

=cut

# CPAN modules
use Mojo::Server::Prefork;
use Mojo::Util qw( extract_usage getopt url_escape monkey_patch );
use Mojo::File;

# Project modules
use OpenXPKI::Util;
use OpenXPKI::Log4perl;


has cfg => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    default => sub ($self) {
        # $ENV{OPENXPKI_CONF_PATH} = $self->config_path if $self->has_config_path;
        # require OpenXPKI::Config;
        # my $config = OpenXPKI::Config->new;
        return {
            pid_file => '/run/openxpki-clientd.pid',
            socket_file => '/var/openxpki/openxpki-clientd.socket',
            #stderr => '/var/log/openxpki/client-stderr.log',
        };
    },
);

has silent => (
    is => 'rw',
    isa => 'Bool',
    init_arg => undef,
    lazy => 1,
    default => sub { $_[0]->opts->{quiet} ? 1 : 0 },
);

has foreground => (
    is => 'rw',
    isa => 'Bool',
    init_arg => undef,
    lazy => 1,
    default => sub { $_[0]->systemd_mode || $_[0]->opts->{nd} ? 1 : 0 },
);

has systemd_mode => (
    is => 'rw',
    isa => 'Bool',
    init_arg => undef,
    lazy => 1,
    default => sub { $_[0]->opts->{systemd} ? 1 : 0 },
);

# required by OpenXPKI::Control::Role
sub getopt_params ($self, $command) {
    return qw(
        dev|d
        user|u=s
        group|g=s
        pid_file|pid-file|p=s
        socket_file|socket-file|s=s
        socket_user|socket-user=s
        socket_group|socket-group=s
        socket_mode|socket-mode=s
        systemd
        nd|no-detach
        quiet
    );
}

# required by OpenXPKI::Control::Role
sub cmd_start ($self) {
    my $pid = $self->__get_pid;
    if (defined $pid and $self->status(silent => 1) == 0) {
        warn "OpenXPKI Client already running. PID: $pid\n";
        return 0;
    }

    my $force_screen_logging = 0;
    if ($self->opts->{dev}) {
        $ENV{MOJO_MODE} = 'development';
        $force_screen_logging = 1 if $self->foreground;
    } else {
        $ENV{MOJO_MODE} = 'production';
    }

    my $log = OpenXPKI::Log4perl->get_logger('openxpki.client');

    $log->info('Foreground development mode: logging to console (Log4perl config will be ignored)') if $force_screen_logging;
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
        my $pid_file = $self->opts->{pid_file} || $self->cfg->{pid_file}
            or die "Missing config entry: system.client.pid_file\n";
        my $socket_file = $self->opts->{socket_file} || $self->cfg->{socket_file}
            or die "Missing config entry: system.client.socket_file\n";

        %server_params = (
            pid_file => $pid_file,
            listen => [ sprintf 'http+unix://%s', $self->__file_url($socket_file) ],
        );

        # each parameter might be undef:
        %web_params = (
            oxi_socket_user => $self->opts->{socket_user} || $self->cfg->{socket_user} || $user,
            oxi_socket_group => $self->opts->{socket_group} || $self->cfg->{socket_group} || $group,
            oxi_socket_mode => $self->opts->{socket_mode} || $self->cfg->{socket_mode},
        );
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
        # Mojo attribute: pass the client root logger
        log => $log,
        # daemon owner
        oxi_user => $user, # might be undef
        oxi_group => $group, # might be undef
        oxi_skip_log_init => $force_screen_logging,
        # config object
        #oxi_config_obj => ...,
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

    eval { unlink $self->cfg->{pid_file} } if $code == 0;

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

    # my $socketfile = $self->cfg->{socketfile}
    #     or die "Missing config entry: system.server.socket_file\n";

    # my $client;
    # my $i = 4;
    # while ($i-- > 0) {
    #     $client = __connect_openxpki_daemon($socketfile);
    #     last if $client;
    #     sleep 2 if $i > 0;
    # }

    if ($alive) {
        print "OpenXPKI Client is running.\n" unless $arg->silent;
        return 0;
    } else {
        warn "OpenXPKI client is not running.\n" unless $arg->silent;
        return 1;
    }
}

sub __get_pid ($self) {
    die "Missing config entry: system.client.pid_file\n" unless $self->cfg->{pid_file};
    return $self->slurp_if_exists($self->cfg->{pid_file});
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

In this mode the options C<--pid-file>, C<--socket-file>, C<--socket-user>,
C<--socket-group> and C<--socket-mode> will be ignored.

=item B<--pid-file PATH>

=item B<-p PATH>

Path of the PID file (required unless C<--systemd> is used)

=item B<--socket-file PATH>

=item B<-s PATH>

Path of the socket file (required unless C<--systemd> is used)

=item B<--socket-user NAME|UID>

Target user for the socket file (default: same as --user or current user)

=item B<--socket-group NAME|GID>

Target group for the socket file (default: same as --group or current group)

=item B<--socket-mode OCTAL_MODE>

Permissions for the socket file (default: use umask upon creation or keep
current permissions if socket file already exists)

=item B<--dev>

=item B<-d>

Development mode:

=over

=item * treat all requests as if transmitted over HTTPS,

=item * log to screen (ignore Log4perl configuration),

=item * print detailed Mojolicious exceptions.

=back

=item B<--no-detach>

=item B<--nd>

Do not fork, i.e. do not send daemon to background. Together with --dev this
will show all messages in the console.

=back
