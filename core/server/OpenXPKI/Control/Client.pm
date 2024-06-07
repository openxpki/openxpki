package OpenXPKI::Control::Client;
use OpenXPKI -class;

with 'OpenXPKI::Control::Role';

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


sub getopt_params ($self, $command) {
    return qw(
        debug|d
        user|u=s
        group|g=s
        socket_file|socket-file|s=s
        socket_user|socket-user=s
        socket_group|socket-group=s
    );
}

sub cmd_start ($self) {
    my $user = $self->opts->{user} || $self->cfg->{user};
    my $group = $self->opts->{group} || $self->cfg->{group};
    my $pid_file = $self->opts->{pid_file} || $self->cfg->{pid_file}
        or die "Missing config entry: system.client.pid_file\n";
    my $socket_file = $self->opts->{socket_file} || $self->cfg->{socket_file}
        or die "Missing config entry: system.client.socket_file\n";
    my $socket_user = $self->opts->{socket_user} || $self->cfg->{socket_user};
    my $socket_group = $self->opts->{socket_group} || $self->cfg->{socket_group};

    #
    # Setup
    #
    $ENV{MOJO_MODE} = 'production' unless $self->opts->{debug};

    my $enc_path = url_escape(Mojo::File->new($socket_file));

    my $daemon = Mojo::Server::Prefork->new(
        listen => ["http+unix://$enc_path"],
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
        # config object
        #oxi_config_obj => ...,
    });

    #
    # Start daemon
    #
    $daemon->start; # socketfile will be created only after this

    #
    # Modify socket ownership and permissions
    #
    my (undef, $s_uid, undef, $s_gid) = OpenXPKI::Util->resolve_user_group(
        $socket_user, $socket_group, 'socket', 1
    );
    #my $socket_file = $daemon->ioloop->acceptor($daemon->acceptors->[0])->handle->hostpath;
    chmod 0660, $socket_file;
    my @changes = ();
    if (defined $s_uid) {
        chown $s_uid, -1, $socket_file;
        push @changes, "user = $socket_user";
    }
    if (defined $s_gid) {
        chown -1, $s_gid, $socket_file;
        push @changes, "group = $socket_group";
    }
    $log->info('Socket ownership set to: ' . join(', ', @changes)) if @changes;

    #
    # Run event loop, Run!
    #
    $daemon->run;
}

sub cmd_stop ($self) {
    my $pid = $self->__get_pid;
    $self->stop_process(
        name => 'OpenXPKI Client',
        pid => $pid,
    );
}

sub cmd_reload ($self) {
    $self->cmd_restart;
}

sub cmd_restart ($self) {
    $self->cmd_stop;
    $self->cmd_start;
}

sub cmd_status ($self) {
    die 0xDEADBEEF;
}

sub __get_pid ($self) {
    die "Missing config entry: system.client.pid_file\n" unless $self->cfg->{pid_file};

    my $pid = $self->slurp($self->cfg->{pid_file})
        or die "Unable to read PID file (".$self->cfg->{pid_file}.")\n";

    return $pid;
}

__PACKAGE__->meta->make_immutable;
