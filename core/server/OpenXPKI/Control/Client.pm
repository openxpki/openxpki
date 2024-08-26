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
use Mojo::Util qw( extract_usage getopt url_escape );
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
            user => 'openxpki',
            group => 'openxpki',
            pid_file => '/run/openxpki-client.pid',
            socket_file => '/var/openxpki/openxpki-client.socket',
            #stderr => '/var/log/openxpki/client-stderr.log',
            #socket_owner => 'apache',
        };
    },
);

has silent => (
    is => 'rw',
    isa => 'Bool',
    lazy => 1,
    default => sub { shift->opts->{quiet} ? 1 : 0 },
);


# required by OpenXPKI::Control::Role
sub getopt_params ($self, $command) {
    return qw(
        debug|d
        user|u=s
        group|g=s
        socket_file|socket-file|s=s
        socket_user|socket-user=s
        socket_group|socket-group=s
        nd|no-detach
        quiet
    );
}

# required by OpenXPKI::Control::Role
sub cmd_start ($self) {
    my $user = $self->opts->{user} || $self->cfg->{user};
    my $group = $self->opts->{group} || $self->cfg->{group};
    my $pid_file = $self->cfg->{pid_file}
        or die "Missing config entry: system.client.pid_file\n";
    my $socket_file = $self->opts->{socket_file} || $self->cfg->{socket_file}
        or die "Missing config entry: system.client.socket_file\n";
    my $enc_socket_file = url_escape(Mojo::File->new($socket_file));
    my $socket_user = $self->opts->{socket_user} || $self->cfg->{socket_user} || $user;
    my $socket_group = $self->opts->{socket_group} || $self->cfg->{socket_group} || $group;

    my $pid = $self->__get_pid;
    if (defined $pid and $self->status(silent => 1) == 0) {
        warn "OpenXPKI Client already running. PID: $pid\n";
        return 0;
    }

    $ENV{MOJO_MODE} = 'production' unless $self->opts->{debug};

    my $daemon = Mojo::Server::Prefork->new(
        listen => ["http+unix://$enc_socket_file"],
        reverse_proxy => 1,
        pid_file => $pid_file,
        cleanup => 0, # don't try to delete PID file (would fail for non-root user and PID file e.g. below /run )
    );

    $daemon->check_pid; # delete any old PID file

    my $log = OpenXPKI::Log4perl->get_logger('openxpki.client');

    $daemon->build_app('OpenXPKI::Client::Web' => {
        # "root" client logger
        log => $log,
        # daemon owner
        oxi_user => $user,
        oxi_group => $group,
        oxi_socket_user => $socket_user,
        oxi_socket_group => $socket_group,
        # config object
        #oxi_config_obj => ...,
    });

    my $start_client = sub {
        $daemon->start;
        $daemon->daemonize unless $self->opts->{nd};
        $daemon->run;
    };

    # foreground mode
    if ($self->opts->{nd}) {
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

    return unless -e $self->cfg->{pid_file};

    my $pid = $self->slurp($self->cfg->{pid_file})
        or die "Unable to read PID file (".$self->cfg->{pid_file}.")\n";

    return $pid;
}

__PACKAGE__->meta->make_immutable;

=head1 OPTIONS

=over

=item B<--user NAME|UID>

=item B<-u NAME|UID>

Target user for the web server (default: current user)

=item B<--group NAME|GID>

=item B<-g NAME|GID>

Target group for the web server (default: current group)

=item B<--socket-file PATH>

=item B<-s PATH>

Path of the socket file (required)

=item B<--socket-user NAME|UID>

Target user for the socket file (default: process user)

=item B<--socket-group NAME|GID>

Target group for the socket file (default: process group)

=item B<--debug>

=item B<-d>

Debug mode, also enables Mojolicious development mode:

=over

=item * treat all requests as if transmitted over HTTPS,

=item * log to screen (ignore Log4perl configuration),

=item * print detailed Mojolicious exceptions.

=back

=back
