package OpenXPKI::Control::Server;
use OpenXPKI -class;

with 'OpenXPKI::Control::Role';

=head1 OpenXPKI::Control::Server

This is a static helper class that collects some common methods
to interact with the OpenXPKI system.

Parameters common to all methods:

=over

=item CONFIG

filesystem path to the config git repository

=item SILENT

set to 1 to surpress any output

=back

All methods are static and return 0 on success, 1 on configuration
errors and 2 on system errors.

All Parameters to methods are optional, if no parameters are given
the OpenXPKI::Config Layer is intanciated and queried for the needed
values.

=cut

# Core modules
use POSIX ":sys_wait_h";
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


sub getopt_params ($self, $command) {
    return qw(
        debug=s@
        keep-temp-files=s
        quiet
        nd|no-detach
        nocensor
    );
}

sub cmd_start ($self) {
    my %params = ();

    $params{restart} = $self->opts->{__restart} ? 1 : 0;
    $params{silent} = $self->opts->{quiet} ? 1 : 0;
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

    exit $self->start( %params );
}

sub cmd_stop ($self) {
    my %params = ();
    $params{silent} = $self->opts->{quiet} ? 1 : 0;
    exit $self->stop( %params );
}

=head2 cmd_reload

Reload some parts of the config (sends a HUP to the server pid)

=cut

sub cmd_reload ($self) {
    my $pid = $self->__get_pid;
    print STDOUT "Sending 'reload' command to OpenXPKI server (PID: $pid)\n" unless $self->opts->{quiet};
    kill HUP => $pid;
    return 0;
}

sub cmd_restart ($self) {
    $self->opts->{__restart} = 1;
    $self->cmd_start;
}

sub cmd_status ($self) {
    my %params = ();
    $params{silent} = $self->opts->{quiet} ? 1 : 0;

    if ($self->status(%params) > 0) {
        exit 3;
    }
    exit 0;
}

=head2 start {CONFIG, SILENT, PID, DEBUG, KEEP_TEMP}

Start the server.

Parameters:

=over

=item PID
Pid to check for a running server

=item RESTART (0|1)
Weather to restart a running server

=item DEBUG_LEVEL
hashref: module => level

=item DEBUG_BITMASK
hashref: module => bitmask

=item DEBUG_NOCENSOR (0|1)
turn of censoring of debug messages

=item KEEP_TEMP (0|1)
Weather to not delete temp files

B<!!THIS MIGHT BE A SECURITY RISK !!> as files might contain private keys
or other confidential data!

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
    my $socketfile = $self->cfg->{socketfile};

    if (not $socketfile) {
        print STDERR "Missing system.server.socket_file in config\n";
        return 1;
    }

    # Test if there is a pid file for the current config
    my $pid;
    $pid = $self->slurp($pidfile) if -e $pidfile;

    # If a pid is given, we just check if the server is there
    if (defined $pid and kill(0, $pid)) {
        if ($self->status(silent => 1) == 0) {
            if ($arg->restart) {
                $self->stop(pid => $pid, silent => $arg->silent);
            } else {
                print STDERR "OpenXPKI Server already running. PID: $pid\n";
                return 0;
            }
        }
    }

    if ($self->cfg->{depend} && (my $core = $self->cfg->{depend}->{core})) {
        my ($Major, $Minor) = ($OpenXPKI::VERSION::VERSION =~ m{\A(\d)\.(\d+)});
        my ($major, $minor) = ($core =~ m{\A(\d)\.(\d+)});
        if ($major != $Major) {
            print STDERR "Major version of code and config differs - unable to proceed\n";
            return 1;
        }
        if ($Minor < $minor) {
            # config is set for the coming up major version while this
            # is a development build (odd numbers are development)
            if (($minor - $Minor) == 1 and $Minor % 2) {
                print STDERR sprintf "Config dependency (%s) matches upcoming release\n",
                    $core;
            } else {
                print STDERR sprintf "Config dependency (%s) not fulfilled by this release (%s)\n",
                    $core, $OpenXPKI::VERSION::VERSION;
                return 1;
            }
        }
    } else {
        print STDERR "Config entry system.version.depend is not set - unable to check required version!\n";
        print STDERR "Hint: Add expected minimum version to 'system.version.depend.core'\n";
    }

    if (not $arg->silent) {
        my $version = $self->get_version;
        print STDOUT "Starting $version\n";
    }
    unlink $pidfile if ($pidfile && -e $pidfile);

    # common start procedure for forking and foreground mode
    my $start_server = sub {
        eval {
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
        if ($EVAL_ERROR) {
            print STDERR $EVAL_ERROR;
            return 2;
        }
        return 0;
    };

    # foreground mode
    if ($arg->foreground) {
        return $start_server->();
    }

    # fork off server launcher
    my $redo_count = 0;
    my $READ_FROM_KID;

    # fork server away to background
    FORK:
    do {
        # this open call efectively does a fork and attaches the child's
        # STDOUT to $READ_FROM_KID, allowing the child to send us data.
        $pid = open($READ_FROM_KID, "-|");
        if (not defined $pid) {
            if ($!{EAGAIN}) {
            # recoverable fork error
                if ($redo_count > 5) {
                            ## the first message is part of the informal daemon startup message
                            ## the second message is a real error message
                    print STDOUT "FAILED.\n" unless $arg->silent;
                    print STDERR "Could not fork process\n";
                    return 2;
                }
                        ## this is only an informal message and not an error - so do not use STDERR
                print STDOUT '.' unless $arg->silent;
                sleep 5;
                $redo_count++;
                redo FORK;
            }

            # other fork error
                ## the first message is part of the informal daemon startup message
                ## the second message is a real error message
            print STDOUT "FAILED.\n" unless $arg->silent;
            print STDERR "Could not fork process: $ERRNO\n";
            return 2;
        }
    } until defined $pid;

    # parent here
    # child process pid is available in $pid
    if ($pid) {

        my $kid;
        do {
            $kid = waitpid(-1, WNOHANG);
        } until $kid > 0;

        # check if child noticed a startup error
        my $msg = $self->slurp($READ_FROM_KID);

        if ($msg && length $msg)
        {
            ## the first message is part of the informal daemon startup message
            ## the second message is a real error message
            print STDOUT "FAILED.\n" unless $arg->silent;
            print STDERR "$msg\n";
            return 2;
        }

        # find out if the server is REALLY running properly
        if ($self->status > 0) {
            print STDERR "Status check failed\n";
            return 2;
        }

        ## this is only an informal message and not an error - so do not use STDERR
        print STDOUT "DONE.\n" unless $arg->silent;
        return 0;

    # child here
    # parent process pid is available with getppid
    } else {
        # everything printed to STDOUT here will be available to the
        # parent on its $READ_FROM_KID file descriptor
        $start_server->();
        close STDOUT;
        close STDERR;
        return 0;
    }
}

=head2 stop

Stop the server

Parameters:

=over

=item PID

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
    my $pid = $arg->pid || $self->__get_pid;
    $self->stop_process(
        name => 'OpenXPKI Server',
        pid => $pid,
        silent => $arg->silent,
    );
}

=head2 status

Check if the server is running

Parameters:

=over

=item SLEEP

Wait I<sleep> seconds before testing

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
        or die "Missing system.server.socket_file in config";

    my $client;
    my $i = 4;
    while ($i-- > 0) {
        $client = __connect_openxpki_daemon($socketfile);
        last if $client;
        sleep 2 if $i > 0;
    }
    if (not $client) {
        print STDERR "OpenXPKI server is not running or does not accept requests.\n" unless $arg->silent;
        return 3;
    }
    print STDOUT "OpenXPKI Server is running and accepting requests.\n" unless $arg->silent;
    return 0;
}

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

Get a list of all process belonging to this instance

Returns a hash with keys:

=over

=item server

Holding the pid of the main server process.

=item watchdog

List of running watchdog process. Usually this is only a single pid but
can also have more than one. If empty, the watchdog was either disabled
or terminated due to too many internal errors.

=item worker

List of pids of running session workers (connected to the socket). This
might also be empty if no process is running.

=item workflow

List of pids of all workers currently handling workflows (contains
watchdog and user initiated requests).

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

Get a list of all running workers with pid, time and info

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

sub __get_pid ($self) {
    die "Missing system.server.pid_file in config\n" unless $self->cfg->{pidfile};

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

__DATA__

=head1 NAME

openxpkictl - start/stop script for OpenXPKI server

=head1 USAGE

openxpkictl [options] COMMAND

 Commands:
   start            Start OpenXPKI daemon
   stop             Stop OpenXPKI daemon
   reload           Reload the configuration
   restart          Restart OpenXPKI daemon
   status           Get OpenXPKI daemon status
   version          Print the OpenXPKI version and license info
   terminal         Control terminal process servers (EE feature)

See below for supported options.

=head1 ARGUMENTS

Available commands:

=over 8

=item B<start>

Start the OpenXPKI daemon.

=item B<stop>

Stop the OpenXPKI daemon.

=item B<reload>

Reload the OpenXPKI daemon, re-reading the config repository.
Note: Some changes need a restart, see the documentation!

=item B<restart>

Restart the OpenXPKI daemon.

=item B<status>

Check the OpenXPKI daemon status.

=item B<version>

Print information on the version and license.

=item B<terminal>

Control the terminal daemons (EE feature).

A subcommand is required. Executing it without subcommand prints a list of
the available commands.

=back

=head1 OPTIONS

=over 8

=item B<--help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--config|cfg PATH>

Use PATH to point to the configuration repository (base of yaml tree).
Defaults to /etc/openxpki/config.d

=item B<--instance|i NAME>

Shortcut to set the config path when running multiple instances using
the proposed config path layout (/etc/openxpki/I<instance>/config.d).

=item B<--version>

Print program version and exit.

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

Do not fork away the control process - useful to run inside containers
or from systemd.

=back

=head1 DESCRIPTION

B<openxpkictl> is the start script for the OpenXPKI server process.

=over 8

The openxpkictl script returns a 0 exit value on success, and >0 if  an
error occurs.

=back

