package OpenXPKI::Control::Server;
use OpenXPKI -class;

with 'OpenXPKI::Control::Role';

=head1 DESCRIPTION

Control OpenXPKI server processes.

Configuration path: C<system.server>

=head1 OpenXPKI::Control::Server

As the backend of C<openxpkictl COMMAND server> (i.e. the I<server> scope)
this class implements all methods required by L<OpenXPKI::Control::Role>.

Furthermore it provides the following methods for use from within the OpenXPKI
server code:

=cut

# Core modules
use Digest::SHA qw( sha256_base64 );
use File::Temp;

# CPAN modules
use Proc::ProcessTable;

# Project modules
use OpenXPKI::VERSION;


has cfg => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    default => sub ($self) {
        $ENV{OPENXPKI_CONF_PATH} = $self->config_path if $self->has_config_path;

        require OpenXPKI::Config;
        my $config = OpenXPKI::Config->new;

        return {
            pidfile => $config->get('system.server.pid_file') || '',
            socketfile => $config->get('system.server.socket_file') || '',
            type => $config->get('system.server.type') || 'Fork',
            depend => $config->get_hash('system.version.depend') || undef,
            license => $config->get('system.license') || '',
        };
    },
);

has silent => (
    is => 'rw',
    isa => 'Bool',
    lazy => 1,
    default => sub { shift->opts->{quiet} ? 1 : 0 },
);

has __restart => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
);


# required by OpenXPKI::Control::Role
sub getopt_params ($class, $command) {
    return qw(
        debug=s@
        keep-temp-files=s
        quiet
        nd|no-detach
        nocensor
    );
}

# required by OpenXPKI::Control::Role
sub cmd_start ($self) {
    my %params = ();

    $params{restart} = $self->__restart ? 1 : 0;
    $params{silent} = $self->silent;
    $params{foreground} = $self->opts->{nd} ? 1 : 0;

    if (defined $self->opts->{debug}) {
        my @debug = split(m{,}, join(',', $self->opts->{debug}->@*));
        $params{debug_level} = {};
        $params{debug_bitmask} = {};
        $params{debug_nocensor} = 1 if defined $self->opts->{nocensor};

        for my $param (@debug) {
            my ($module, $op, $level) = ($param =~ m{ \A ((?!\d).+?)?([:=])?((0b)?\d+)? \z }xms);

            # default values if not specified
            $level //= 1;
            $op = ':' if (not $module and not $op); # if only number was given: interpret as level
            $module //= '.*';

            # convert binary bitmask/level specifications
            if ($level =~ /^0b(.*)/) {
                $level = unpack("N", pack("B32", substr("0"x32 . $1, -32)));
            }

            # operator ":" - a maximum level
            if ($op and $op eq ":") {
                $params{debug_level}->{$module} = $level;
            }
            # operator "=" - a bitmask
            else {
                # also assume it's a bitmask if no operator and no number were given
                $params{debug_bitmask}->{$module} = $level;
            }
        }
    }

    if ($self->opts->{'keep-temp-files'}) {
        if ($self->opts->{'keep-temp-files'} eq 'yes') {
            $params{keep_temp} = 1;
        } else {
            warn sprintf("You need to set --keep-temp-files to 'yes' ('%s' was given) ", $self->opts->{'keep-temp-files'});
        }
    }

    return $self->start( %params );
}

# required by OpenXPKI::Control::Role
sub cmd_stop ($self) {
    return $self->stop(silent => $self->silent);
}

# required by OpenXPKI::Control::Role
sub cmd_reload ($self) {
    my $pid = $self->__read_pid_file;
    print "Sending 'reload' command to OpenXPKI server (PID: $pid)\n" unless $self->silent;
    kill HUP => $pid;
    return 0;
}

# required by OpenXPKI::Control::Role
sub cmd_restart ($self) {
    $self->__restart(1);
    $self->cmd_start;
}

# required by OpenXPKI::Control::Role
sub cmd_status ($self) {
    return $self->status(silent => $self->silent);
}

=head2 start

Start the server process.

B<Named parameters>

=over

=item * C<silent> I<Bool> - optional: suppress messages. Default: 0

=item * C<foreground> I<Bool> - optional: do not fork away the control process. Default: 0

=item * C<restart> I<Bool> - optional: restart a running server. Default: 0

=item * C<debug_level> I<HashRef> - optional: C<{ module =E<gt> level }>

=item * C<debug_bitmask> I<HashRef> - optional: C<{ module =E<gt> bitmask }>

=item * C<debug_nocensor> I<Bool> - optional: turn of censoring of debug messages. Default: 0

=item * C<keep_temp> I<Bool> - optional: do not delete temporary files. Default: 0
B<THIS MIGHT BE A SECURITY RISK> as files may contain private keys or other
confidential data!

=back

=cut
signature_for start => (
    method => 1,
    named => [
        silent => 'Bool', { default => 0 },
        foreground => 'Bool', { default => 0 },
        restart => 'Bool', { default => 0 },
        debug_level => 'HashRef', { default => {} },
        debug_bitmask => 'HashRef', { default => {} },
        debug_nocensor => 'Bool', { default => 0 },
        keep_temp => 'Bool', { default => 0 },
    ],
);
sub start ($self, $arg) {

    $File::Temp::KEEP_ALL = 1 if $arg->keep_temp;

    # We must set the debug options before loading any OXI classes
    # Parsing any class before the debug level is set will exlude the class
    # from debugging!
    #
    # DEBUG_LEVEL is a hash with the module name (or regex)
    # as key and the level as value
    foreach my $module (keys $arg->debug_level->%*) {
        my $level = $arg->debug_level->{$module};
        $OpenXPKI::Debug::LEVEL{$module} = $level;
    }

    # DEBUG_BITMASK is a hash with the module name (or regex)
    # as key and the bitmask as value
    foreach my $module (keys $arg->debug_bitmask->%*) {
        my $bitmask = $arg->debug_bitmask->{$module};
        $OpenXPKI::Debug::BITMASK{$module} = $bitmask;
    }

    $OpenXPKI::Debug::NOCENSOR = 1 if $arg->debug_nocensor;

    # Load the required locations from the config
    my $pidfile  = $self->cfg->{pidfile};
    my $socketfile = $self->cfg->{socketfile}
        or do {
            warn "Missing config entry: system.server.socket_file\n";
            return 1;
        };

    # Test if there is a pid file for the current config
    my $pid;
    $pid = $self->slurp($pidfile) if -e $pidfile;

    # If a pid is given, we just check if the server is there
    if (defined $pid and kill(0, $pid)) {
        if ($self->status(silent => 1) == 0) {
            if ($arg->restart) {
                $self->stop(pid => $pid, silent => $arg->silent);
            } else {
                warn "OpenXPKI Server already running. PID: $pid\n";
                return 0;
            }
        }
    }

    if ($self->cfg->{depend} && (my $core = $self->cfg->{depend}->{core})) {
        my ($Major, $Minor) = ($OpenXPKI::VERSION::VERSION =~ m{\A(\d)\.(\d+)});
        my ($major, $minor) = ($core =~ m{\A(\d)\.(\d+)});
        if ($major != $Major) {
            warn "Major version of code and config differs - unable to proceed\n";
            return 1;
        }
        if ($Minor < $minor) {
            # config is set for the coming up major version while this
            # is a development build (odd numbers are development)
            if (($minor - $Minor) == 1 and $Minor % 2) {
                warn "Config dependency ($core) matches upcoming release\n";
            } else {
                warn sprintf "Config dependency (%s) not fulfilled by this release (%s)\n",
                    $core, $OpenXPKI::VERSION::VERSION;
                return 1;
            }
        }
    } else {
        warn "Config entry system.version.depend is not set - unable to check required version!\n";
        warn "Hint: Add expected minimum version to 'system.version.depend.core'\n";
    }

    if (not $arg->silent) {
        my $version = $self->get_version;
        print "Starting $version\n";
    }
    unlink $pidfile if ($pidfile && -e $pidfile);

    # common start procedure for forking and foreground mode
    my $start_server = sub {
        # SILENT is required to work correctly with start-stop-daemons
        # during a normal System V init
        require OpenXPKI::Server;
        my $server = OpenXPKI::Server->new(
            SILENT => $arg->silent,
            TYPE => $self->cfg->{type},
            NODETACH => $arg->foreground,
        );
        $server->start;
    };

    # foreground mode
    if ($arg->foreground) {
        eval {
            $start_server->();
        };
        if ($EVAL_ERROR) {
            warn $EVAL_ERROR;
            return 2;
        }
        return 0;

    # background mode
    } else {
        my $code = $self->fork_launcher($start_server);
        if ($code == 0) {
            # find out if the server is REALLY running properly
            if ($self->status != 0) {
                warn "Status check failed\n";
                $code = 2;
            }
        }
        print ($code == 0 ? "DONE.\n" : "FAILED.\n") unless $arg->silent;
        return $code;
    }
}

=head2 stop

Stop the server process.

B<Named parameters>

=over

=item * C<pid> I<Int> - optional: process ID. Default: read ID from PID file

=item * C<silent> I<Bool> - optional: suppress messages. Default: 0

=back

=cut
signature_for stop => (
    method => 1,
    named => [
        pid => 'Int', { optional => 1 },
        silent => 'Bool', { default => 0 },
    ],
);
sub stop ($self, $arg) {
    my $pid = $arg->pid || $self->__read_pid_file;
    return $self->stop_process(
        name => 'OpenXPKI Server',
        pid => $pid,
        silent => $arg->silent,
    );
}

=head2 status

Check if the server is running

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
    my $socketfile = $self->cfg->{socketfile}
        or die "Missing config entry: system.server.socket_file\n";

    my $client;
    my $i = 4;
    while ($i-- > 0) {
        $client = __connect_openxpki_daemon($socketfile);
        last if $client;
        sleep 2 if $i > 0;
    }
    if (not $client) {
        warn "OpenXPKI server is not running or does not accept requests.\n" unless $arg->silent;
        return 3;
    } else {
        print "OpenXPKI Server is running and accepting requests.\n" unless $arg->silent;
        return 0;
    }
}

=head2 get_version

Return the OpenXPKI version string (incl. EE license if any).

B<Named parameters>

=over

=item * C<config> I<OpenXPKI::Config> - optional: configuration. Default: read
configuration from disk.

=back

=cut
signature_for get_version => (
    method => 1,
    named => [
        config => 'OpenXPKI::Config', { optional => 1 },
    ],
);
sub get_version ($self, $arg) {
    my $is_enterprise = 0;
    try {
        require OpenXPKI::Enterprise;
        $is_enterprise = 1;
    }
    catch ($err) {
        # suppress "module not found" but fail loudly on any other error
        die $err unless $err =~ m{locate OpenXPKI/Enterprise\.pm in \@INC};
    }

    if ($is_enterprise) {
        my $license = $arg->config
            ? $arg->config->get('system.license')
            : $self->cfg->{license};
        my $version = "OpenXPKI Enterprise Edition v$OpenXPKI::VERSION::VERSION";
        $version .= "\n" . OpenXPKI::Enterprise::get_license_string($license) if $license;
        return $version;
    } else {
        return "OpenXPKI Community Edition v$OpenXPKI::VERSION::VERSION";
    }

}

=head2 get_pids

Static method that lists OpenXPKI server process IDs belonging to the current
process group.

Returns a I<HashRef> with the following keys (values are single PID):

=over

=item C<server> =E<gt> I<Scalar>

PID of the main server process.

=item C<watchdog> =E<gt> I<ArrayRef>

Watchdog processes. Usually this is only a single PID but can also have more than
one. If empty, the watchdog was either disabled or terminated due to too many
internal errors.

=item C<worker> =E<gt> I<ArrayRef>

Session workers (connected to the socket). This might also be empty if no
process is running.

=item C<workflow> =E<gt> I<ArrayRef>

All workers currently handling workflows (contains both: requests initiated by
watchdog and by a user).

=item C<prometheus> =E<gt> I<Scalar>

PID of the Prometheus agent.

=back

=cut

sub get_pids {
    my $proc = Proc::ProcessTable->new;
    my $result = { 'server' => 0, 'watchdog' => [], 'worker' => [], 'workflow' => [], 'prometheus' => 0 };
    my $pgrp = getpgrp($$); # Process Group of myself
    for my $p ($proc->table->@*) {
        next unless $pgrp == $p->pgrp;

        my $cmd = $p->cmndline;
        if ($cmd =~ / ^ openxpkid .* server /xi) {
            $result->{server} = $p->pid; next;
        }
        if ($cmd =~ / ^ openxpkid .* watchdog /xi) {
            push @{$result->{watchdog}}, $p->pid; next;
        }
        if ($cmd =~ / ^ openxpkid .* worker /xi) {
            push @{$result->{worker}}, $p->pid; next;
        }
        if ($cmd =~ / ^ openxpkid .* workflow /xi) {
            push @{$result->{workflow}}, $p->pid; next;
        }
        if ($cmd =~ / ^ openxpkid .* Prometheus /xi) {
            $result->{prometheus} = $p->pid; next;
        }
    }
    return $result;
}

=head2 list_process

Static method that returns an I<ArrayRef> with information about all child
processes of the server process:

    [
        {
            pid => 123, time => 1718098183, info => 'openxpkid (main) server',
            ...
        }
    ]

=cut

sub list_process {
    my $proc = Proc::ProcessTable->new;
    my @result;
    my $pgrp = getpgrp($$); # Process Group of myself

    foreach my $p ( @{$proc->table} ) {
        next unless $pgrp == $p->pgrp;

        if (!$p->cmndline) {
            push @result, { 'pid' => $p->pid, 'time' => $p->start, 'info' => '' };
        } elsif ($p->cmndline =~ m{ ((worker|workflow): .*) \z }x) {
            push @result, { 'pid' => $p->pid, 'time' => $p->start, 'info' => $1 };
        } else {
            push @result, { 'pid' => $p->pid, 'time' => $p->start, 'info' => $p->cmndline };
        }
    }

    return \@result;
}

sub __read_pid_file ($self) {
    die "Missing config entry: system.server.pid_file\n" unless $self->cfg->{pidfile};

    my $pid = $self->slurp($self->cfg->{pidfile})
        or die "Unable to read PID file (".$self->cfg->{pidfile}.")\n";

    return $pid;
}

sub __connect_openxpki_daemon ($socketfile) {
    # if there is no socket it does not make sense to test the client
    return unless (-e $socketfile);

    my $client;
    eval {
        ## do not make a use statement from this
        ## a use would disturb the server initialization
        require OpenXPKI::Client;
        # this only creates the class but does not fire up the socket!
        my $cc= OpenXPKI::Client->new({
            SOCKETFILE => $socketfile,
        });

        # try to talk to the daemon
        my $reply = $cc->send_receive_service_msg('PING');
        if ($reply && $reply->{SERVICE_MSG} eq 'START_SESSION') {
            $client = $cc;
        }
    };
    return $client;

}

__PACKAGE__->meta->make_immutable;

=head1 COMMAND DETAILS

Unless stated otherwise, commands return C<0> on success, C<1> on configuration
errors and C<2> on system errors.

=head2 status

The exit code of C<status> is C<0> if the server is running, C<3> otherwise.

=head2 reload

The C<reload> command sends a HUP signal to the server. The server then re-reads
some configuration items and restarts the worker processes.

Note: Some changes need a C<restart>, see the documentation.

=head1 OPTIONS

=over

=item B<--debug MODULE:LEVEL>

Set specific module debug level to LEVEL (must be a positive integer).
Higher values mean more debug output. MODULE must be a module
specification (e. g. OpenXPKI::Server) and may contain Perl Regular
expressions.

LEVEL can be specified as a decadic or binary number (e.g. 5 or 0b101).
LEVEL defaults to 1 if not specified.

If MODULE is omitted the given LEVEL will be set for all modules.

You can add multiple --debug options on one command line.

Examples:

  --debug
  (equivalent to --debug .*:1)

  --debug OpenXPKI::Server
  (equivalent to --debug OpenXPKI::Server:1)

  --debug OpenXPKI::Server:100
  (equivalent to --debug OpenXPKI::Server:100)

  --debug OpenXPKI::Server:10 --debug OpenXPKI::Crypto::.*:20

=item B<--debug MODULE[=BITMASK]>

Show debug messages of MODULE whose level fits into the given BITMASK
(i.e. "level AND BITMASK == level").
BITMASK can be specified as a decadic or binary number (e.g. 5 or
0b101). If not given BITMASK defaults to 1.

=item B<--nocensor>

Turn off censoring in the Debug module.

=item B<--keep-temp-files yes>

Do not delete temporary files.
B<WARNING>: Files might contain confidential data!

=item B<--no-detach|nd>

Do not fork away the control process - useful to run the server process inside
containers or from systemd.

=back
