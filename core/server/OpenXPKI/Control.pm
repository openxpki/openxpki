# OpenXPKI::Control
#
# Written 2012 by Oliver Welter for the OpenXPKI project
# Copyright (C) 2012 by The OpenXPKI Project
#

=head1 OpenXPKI::Control

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

# BIG FAT WARNING! Do not "use" any system packages in the file header,
# as this will prevent the OXI::Debug filter from working

package OpenXPKI::Control;

use strict;
use warnings;
use English;

# Core modules
use POSIX ":sys_wait_h";
use Data::Dumper;
use Digest::SHA qw( sha256_base64 );
use File::Temp;

# CPAN modules
use Proc::ProcessTable;

# Project modules
use OpenXPKI::VERSION;
use OpenXPKI::Debug;


=head2 start {CONFIG, SILENT, PID, FOREGROUND, DEBUG, KEEP_TEMP}

Start the server.

Parameters:

=over

=item PID
Pid to check for a running server

=item FOREGROUND (0|1)
Weather to start the daemon in foreground (implies restart)

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

sub start {

    my $args = shift;
    my $silent = $args->{SILENT};
    my $pid        = $args->{PID};
    my $foreground = $args->{FOREGROUND} || $args->{NODETACH};
    my $restart = $args->{RESTART} || $args->{FOREGROUND};
    my $debug_level = $args->{DEBUG_LEVEL} || 0;
    my $debug_bitmask = $args->{DEBUG_BITMASK} || 0;
    my $debug_nocensor = $args->{DEBUG_NOCENSOR} || 0;


    if ($args->{KEEP_TEMP}) {
        $File::Temp::KEEP_ALL = 1;
    }

    # We must set the debug options before loading any OXI classes
    # Parsing any class before the debug level is set will exlude the class
    # from debugging!
    #
    # DEBUG_LEVEL is a hash with the module name (or regex)
    # as key and the level as value or just an integer for the global level
    if (ref $debug_level eq 'HASH') {
        foreach my $module (keys %{$debug_level}) {
            my $level = $debug_level->{$module};
            $OpenXPKI::Debug::LEVEL{$module} = $level;
        }
    }

    # DEBUG_BITMASK is a hash with the module name (or regex)
    # as key and the bitmask as value or just an integer for the global bitmask
    if (ref $debug_bitmask eq 'HASH') {
        foreach my $module (keys %{$debug_bitmask}) {
            my $bitmask = $debug_bitmask->{$module};
            $OpenXPKI::Debug::BITMASK{$module} = $bitmask;
        }
    }

    if ($debug_nocensor) {
        $OpenXPKI::Debug::NOCENSOR = 1;
    }

    # Load the required locations from the config
    my $config = OpenXPKI::Control::__probe_config( $args );
    my $pidfile  = $config->{PIDFILE};
    my $socketfile = $config->{SOCKETFILE};

    if (!$socketfile) {
        print STDERR "Unable to load configuration\n";
        return 1;
    }

    # Test if there is a pid file for the current config
    if (!defined $pid && -e $pidfile) {
        $pid = OpenXPKI::Control::__slurp($pidfile);
    }

    # If a pid is given, we just check if the server is there
    if (defined $pid && kill(0, $pid)) {
        if (OpenXPKI::Control::status({SOCKETFILE => $socketfile,SILENT => 1}) == 0) {
            if ($restart) {
                OpenXPKI::Control::stop({SOCKETFILE => $socketfile, PID => $pid, SILENT => $silent});
            } else {
                print STDERR "OpenXPKI Server already running. PID: $pid\n";
                return 0;
            }
        }
    }

    if ($config->{depend} && (my $core = $config->{depend}->{core})) {
        my ($Major, $Minor) = ($OpenXPKI::VERSION::VERSION =~ m{\A(\d)\.(\d+)});
        my ($major, $minor) = ($core =~ m{\A(\d)\.(\d+)});
        if ($major != $Major) {
            print STDERR "Major version of code and config differs - unable to proceed\n";
            return 1;
        }
        if ($Minor < $minor) {
            print STDERR sprintf "Config dependency (%s) not fullfilled by this release (%s)\n",
                $core, $OpenXPKI::VERSION::VERSION;
            return 1;
        }
    } else {
        print STDERR "Config depend is not set - unable to check config prereq!\n";
        print STDERR "Hint: Add expected minimum version to 'system.version.depend.core'\n";
    }

    if (not $silent) {
        eval {require OpenXPKI::Enterprise;};
        if ($EVAL_ERROR) {
            print STDOUT "Starting OpenXPKI Community Edition v$OpenXPKI::VERSION::VERSION\n";
        } else {
            print STDOUT "Starting OpenXPKI Enterprise Edition v$OpenXPKI::VERSION::VERSION\n";
            if ($config->{license}) {
                print STDOUT OpenXPKI::Enterprise::get_license_string($config->{license})."\n";
            }
        }
    }
    unlink $pidfile if ($pidfile && -e $pidfile);

    # fork off server launcher
    my $redo_count = 0;
    my $READ_FROM_KID;
    if (! $foreground) {
        # fork server away to background
      FORK:
        do {
            # this open call efectively does a fork and attaches the child's
            # STDOUT to $READ_FROM_KID, allowing the child to send us data.
            $pid = open($READ_FROM_KID, "-|");
            if (! defined $pid) {
                if ($!{EAGAIN}) {
                # recoverable fork error
                    if ($redo_count > 5) {
                                ## the first message is part of the informal daemon startup message
                                ## the second message is a real error message
                        print STDOUT "FAILED.\n" if (not $silent);
                        print STDERR "Could not fork process\n";
                        return 2;
                    }
                            ## this is only an informal message and not an error - so do not use STDERR
                    print STDOUT '.' if (not $silent);
                    sleep 5;
                    $redo_count++;
                    redo FORK;
                }

                # other fork error
                    ## the first message is part of the informal daemon startup message
                    ## the second message is a real error message
                print STDOUT "FAILED.\n" if (not $silent);
                print STDERR "Could not fork process: $ERRNO\n";
                return 2;
            }
        } until defined $pid;

        if ($pid) {
            # parent here
            # child process pid is available in $pid

            my $kid;
            do {
                $kid = waitpid(-1, WNOHANG);
            } until $kid > 0;

            # check if child noticed a startup error
            my $msg = OpenXPKI::Control::__slurp $READ_FROM_KID;

            if ($msg && length $msg)
            {
                ## the first message is part of the informal daemon startup message
                ## the second message is a real error message
                print STDOUT "FAILED.\n" if (not $silent);
                print STDERR "$msg\n";
                return 2;
            }

            # find out if the server is REALLY running properly
            if (OpenXPKI::Control::status({ SOCKETFILE => $socketfile, SLEEP => undef })) {
                print STDERR "Status check failed\n";
                return 2;
            }

            ## this is only an informal message and not an error - so do not use STDERR
            print STDOUT "DONE.\n" if (not $silent);
        } else {
            # child here
            # parent process pid is available with getppid

            # everything printed to STDOUT here will be available to the
            # parent on its $READ_FROM_KID file descriptor
            eval
            {
                ## SILENT is required to work correctly with start-stop-daemons
                ## during a normal System V init
                require OpenXPKI::Server;
                my $server = OpenXPKI::Server->new ( "SILENT" => $silent ? 1 : 0 , TYPE => $config->{TYPE} );
                $server->start;
            };
            if ($EVAL_ERROR)
            {
                print STDERR $EVAL_ERROR;
                return 2;
            }
            close(STDOUT);
            close(STDERR);
            return 0;
        }
    }
    else {
        # foreground requested, do not fork
        eval {
            require OpenXPKI::Server;
            my $server = OpenXPKI::Server->new(
                'SILENT' => $silent ? 1 : 0,
                'TYPE'   => ($args->{FOREGROUND} ? 'Simple' : $config->{TYPE}),
                'NODETACH' => $args->{NODETACH}
            );
            $server->start;
        };
        if ($EVAL_ERROR) {
            print STDERR $EVAL_ERROR;
            return 2;
        }
    }
    return 0;
}


=head2 stop

Stop the server

Parameters:

=over

=item PID or PIDFILE

=back

=cut

sub stop {

    my $args = shift;
    my $silent = $args->{SILENT};

    my $pid;
    if ($args->{PIDFILE}) {
        $pid = OpenXPKI::Control::__slurp($args->{PIDFILE});
        die "Unable to read pidfile ($args->{PIDFILE})\n" unless ($pid);
    } elsif ($args->{PID}) {
        $pid = $args->{PID};
    } else {
        my $config = OpenXPKI::Control::__probe_config( $args );
        if ($config->{PIDFILE}) {
            $pid = OpenXPKI::Control::__slurp($config->{PIDFILE});
            die "Unable to read pidfile ($config->{PIDFILE})\n" unless ($pid);
        } else {
            die "You must specify either a PID or PIDFILE\n";
        }
    }

    if (kill(0, $pid) == 0) {
        print STDERR "OpenXPKI Server is not running at PID $pid.\n";
        return 2;
    }

    my $process_group = getpgrp($pid);

    print STDOUT "Stopping OpenXPKI\n" if (not $silent);

    # get all PIDs which belong to the current process group
    my @pids = OpenXPKI::Control::__get_processgroup_pids($process_group);
    my $attempts = 5;
    my $process_count;

    # try a number of times to send them SIGTERM
    while ($attempts-- > 0) {
        $process_count = scalar @pids;
        last if ($process_count <= 0);
        print STDOUT "Stopping gracefully, $process_count (sub)processes remaining...\n" if (not $silent);
        foreach my $p (@pids) {
            kill(15, $p);
        }
        sleep 2;
        @pids = __still_alive(\@pids);    # find out which ones are still alive
    }

    # still processes left?
    # slaughter them with SIGKILL
    $attempts = 5;
    while ($attempts-- > 0) {
        $process_count = scalar @pids;
        last if ($process_count <= 0);
        print STDOUT "Killing un-cooperative process the hard way, $process_count (sub)processes remaining...\n" if (not $silent);
        foreach my $p (@pids) {
            kill(9, $p);
        }
        sleep 1;
        @pids = __still_alive(\@pids);    # find out which ones are still alive
    }

    @pids = __still_alive(\@pids);    # find out which ones are still alive
    $process_count = scalar @pids;
    if ($process_count <= 0) {
        print STDOUT "DONE.\n" if (not $silent);
        return 0;
    } else {
        print STDOUT "FAILED.\n" if (not $silent);
        print STDERR "Could not terminate OpenXPKI process ".join(" ", @pids).".\n";
        return 2;
    }
}

=head2 status

Check if the server is running

Parameters:

=over

=item SLEEP

Wait I<sleep> seconds before testing

=back

=cut

sub status {

    my $args = shift;
    my $silent = $args->{SILENT};

    if (defined $args->{SLEEP} and $args->{SLEEP} > 0)
    {
        ## this helps to give the server some reaction time
        sleep $args->{SLEEP};
    }

    my $socketfile = $args->{SOCKETFILE};

    if (!$socketfile) {
        my $config = OpenXPKI::Control::__probe_config( $args );
        $socketfile = $config->{SOCKETFILE};
    }

    die "No socketfile and no config given" unless($socketfile);

    my $client = OpenXPKI::Control::__connect_openxpki_daemon($socketfile);
    if (!$client) {
        if (not $args->{SLEEP})
        {
            ## wait for a starting server ...
            return OpenXPKI::Control::status ({SOCKETFILE => $args->{SOCKETFILE}, SLEEP => 5, SILENT => $silent});
        }
        print STDERR "OpenXPKI server is not running or does not accept requests.\n" if (not $silent);
        return 2;

    }
    print STDOUT "OpenXPKI Server is running and accepting requests.\n" unless ($silent);
    return 0;
}

sub version {

    my $args = shift;
    my $config = OpenXPKI::Control::__probe_config( $args );
    eval {require OpenXPKI::Enterprise;};
    if ($EVAL_ERROR) {
        print STDOUT "OpenXPKI Community Edition v$OpenXPKI::VERSION::VERSION\n\n";
    } else {
        print STDOUT "OpenXPKI Enterprise Edition v$OpenXPKI::VERSION::VERSION\n";
        print STDOUT OpenXPKI::Enterprise::get_license_string($config->{license})."\n";
    }
    return 0;

}

=head2 reload

Reload some parts of the config (sends a HUP to the server pid)

Parameters:

=over

=item PID or PIDFILE

=back

=cut

sub reload {

    my $args = shift;
    my $silent = $args->{SILENT};

    my $pid;
    if ($args->{PIDFILE}) {
        $pid = OpenXPKI::Control::__slurp($args->{PIDFILE});
        die "Unable to read pidfile ($args->{PIDFILE})\n" unless ($pid);
    } elsif ($args->{PID}) {
        $pid = $args->{PID};
    } else {
        my $config = OpenXPKI::Control::__probe_config( $args );
        if ($config->{PIDFILE}) {
            $pid = OpenXPKI::Control::__slurp($config->{PIDFILE});
            die "Unable to read pidfile ($config->{PIDFILE})\n" unless ($pid);
        } else {
            die "You must specify either a PID or PIDFILE\n";
        }
    }

    print STDOUT "Sending reload command to OpenXPKI server.\n" unless ($silent);

    kill HUP => $pid;

    return 0;
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
    my $result = { 'server' => 0, 'watchdog' => [], 'worker' => [], 'workflow' => [] };
    my $pgrp = getpgrp($$); # Process Group of myself
    for my $p ( @{$proc->table} ) {
        next unless $pgrp == $p->pgrp;

        my $cmd = $p->cmndline;
        if ($cmd =~ / ^ openxpkid .* server /x) {
            $result->{server} = $p->pid; next;
        }
        if ($cmd =~ / ^ openxpkid .* watchdog /x) {
            push @{$result->{watchdog}}, $p->pid; next;
        }
        if ($cmd =~ / ^ openxpkid .* worker /x) {
            push @{$result->{worker}}, $p->pid; next;
        }
        if ($cmd =~ / ^ openxpkid .* workflow /x) {
            push @{$result->{workflow}}, $p->pid; next;
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

        if ($pgrp != $p->pgrp) {
            next;
        }

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


sub __slurp {
    my $file = shift;
    my $content = do {
        local $INPUT_RECORD_SEPARATOR;
        my $HANDLE;
        open $HANDLE, "<", $file or return;
        <$HANDLE>;
    };
    return $content;
}


sub __get_processgroup_pids {
    # returns a list of PIDs that belong to a given process group
    my $process_group = shift;
    my @result;

    my $pt = Proc::ProcessTable->new;
    foreach my $process (@{$pt->table}) {
        if (getpgrp($process->pid) == $process_group) {
            push @result, $process->pid;
        }
    }
    return @result;
}

# Take an array ref, array containing process IDs
# Check which processes are still alive and return them in an array
sub __still_alive {
  my $pids = shift;
  my @alive;
  my $pid;

  foreach $pid (@{$pids}) {
    unless (kill(0, $pid) == 0) {
      push @alive, $pid;   # process is still there
    }
  }

  return @alive;
}

sub __probe_config {

    my $args = shift;

    $ENV{OPENXPKI_CONF_PATH} = $args->{CONFIG} if($args->{CONFIG});

    require OpenXPKI::Config;
    my $config = OpenXPKI::Config->new();

    return {
        PIDFILE  => $config->get('system.server.pid_file') || '',
        SOCKETFILE => $config->get('system.server.socket_file') || '',
        TYPE => $config->get('system.server.type') || 'Fork',
        depend => $config->get_hash('system.version.depend') || undef,
        license => $config->get('system.license') || '',
    };

}


sub __connect_openxpki_daemon {

    my $socketfile = shift;

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

return 1;
