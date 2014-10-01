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
use OpenXPKI::Debug;
use POSIX ":sys_wait_h";
use Proc::ProcessTable;

use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init($ERROR);

#use OpenXPKI::Server::Context qw( CTX );
use Data::Dumper;

=head2 start {CONFIG, SILENT, PID, FOREGROUND, DEBUG}

Start the server.

Parameters:

=over

=item PID
Pid to check for a running server

=item FOREGROUND (0|1)
Weather to start the daemon in foreground (implies restart)

=item RESTART (0|1)
Weather to restart a running server

=item DEBUG
single scalar as global debug level or hashref of module => level

=back

=cut

sub start {

    my $args = shift;
    my $silent = $args->{SILENT};
    my $pid        = $args->{PID};
    my $foreground = $args->{FOREGROUND};
    my $restart = $args->{RESTART} || $args->{FOREGROUND};
    my $debug      = $args->{DEBUG} || 0;


    # We must set the debug options before loading any OXI classes
    # Parsing any class before the debug level is set, will exlude the class
    # from debugging!
    #
    # Set debug options - DEBUG is hash with the module name (wildcard)
    # as key and the level as value or just an integer for the global level
    if (ref $debug eq '') {
        if ($debug > 0) {
            $OpenXPKI::Debug::LEVEL{'.*'} = $debug;
            $OpenXPKI::Debug::LEVEL{'OpenXPKI::XML::Cache'}  = 0;
        }
    } elsif(ref $debug eq 'HASH') {
        foreach my $module (keys %{$debug}) {
            my $level = $debug->{$module};
            print STDERR "Debug level for module '$module': $level\n";
            $OpenXPKI::Debug::LEVEL{$module} = $level;
        }
        #print Dumper %OpenXPKI::Debug::LEVEL;
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
        if (OpenXPKI::Control::status({SOCKETFILE => $socketfile,SILENT => 1,}) == 0) {
            if ($restart) {
                OpenXPKI::Control::stop({SOCKETFILE => $socketfile, PID => $pid, SILENT => $silent});
            } else {
                print STDERR "OpenXPKI Server already running. PID: $pid\n";
                return 0;
            }
        }
    }

    ## this is only an informal message and not an error - so do not use STDERR
    print STDOUT "Starting OpenXPKI...\n" if (not $silent);
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
            if (OpenXPKI::Control::status({ SOCKETFILE => $socketfile })) {
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
                OpenXPKI::Server->new ( "SILENT" => $silent ? 1 : 0 );
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
            OpenXPKI::Server->new(
                'SILENT' => $silent ? 1 : 0,
                'TYPE'   => 'Simple',
            );
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

    if (exists $args->{SLEEP} and $args->{SLEEP} > 0)
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
        if (not exists $args->{SLEEP})
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


=head2 reload

Reload the server (forwards the config pointer)

Parameters:

=over

=item PID or PIDFILE

=back

=cut

sub reload {

    my $args = shift;

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

List of running watchdog process. Usually this is only a single pid but can
also have more than one. If empty, the watchdog was either disabled or
terminated due to too many internal errors.

=item worker

List of pids of running session workers (connected to the socket). This might
also be empty if no process is running.

=item watchdog

List of pids of all workers executed by the watchdog (not connected to a
socket). Might also be empty.

=back

=cut

sub get_pids {

    my $args = shift;

    my $proc = new Proc::ProcessTable;
    my $result = { 'server' => 0, 'watchdog' => [], 'worker' => [], 'workflow' => [] };
    my $pgrp = getpgrp($$); # Process Group of myself
    foreach my $p ( @{$proc->table} ) {

        if ($pgrp != $p->pgrp) {
            next;
        }

        my $cmd = $p->cmndline;
        if ( $cmd  =~ /server/ ) {
            $result->{server} = $p->pid;
        } elsif( $cmd =~ /watchdog/ ) {
            push @{$result->{watchdog}}, $p->pid;
        } elsif( $cmd =~ /worker/ ) {
            push @{$result->{worker}}, $p->pid;
        } elsif( $cmd =~ /workflow/ ) {
            push @{$result->{workflow}}, $p->pid;
        }
    }

    return $result;
}

=head2 list_process

Get a list of all running workers with pid, time and info

=cut

sub list_process {

    my $proc = new Proc::ProcessTable;
    my @result;
    my $pgrp = getpgrp($$); # Process Group of myself
    foreach my $p ( @{$proc->table} ) {

        if ($pgrp != $p->pgrp) {
            next;
        }

        if ($p->cmndline =~ m{ ((worker|workflow): .*) \z }x) {
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

    my $pt = new Proc::ProcessTable;
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

    $ENV{OPENXPKI_CONF_DB} = $args->{CONFIG} if($args->{CONFIG});

    require OpenXPKI::Config;
    my $config = OpenXPKI::Config->new();

    return {
        PIDFILE  => $config->get('system.server.pid_file'),
        SOCKETFILE => $config->get('system.server.socket_file'),
    };

}


sub __connect_openxpki_daemon {

    my $socketfile = shift;
    my $client;
    eval {
        ## do not make a use statement from this
        ## a use would disturb the server initialization
        require OpenXPKI::Client;
        $client = OpenXPKI::Client->new({
            SOCKETFILE => $socketfile,
        });
    };
    return $client;

}

return 1;
