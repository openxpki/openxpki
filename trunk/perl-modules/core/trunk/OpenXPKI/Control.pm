# OpenXPKI::Control
#
# Written 2012 by Oliver Welter for the OpenXPKI project
# Copyright (C) 2012 by The OpenXPKI Project
#

=head1 OpenXPKI::Control

This is a static helper class that collects some common methods
to interact with the OpenXPKI system.

=cut
package OpenXPKI::Control;

use strict;
use warnings;
use English;
use OpenXPKI::Server;
use OpenXPKI::Debug;
use POSIX ":sys_wait_h";
use Proc::ProcessTable;

#use OpenXPKI::Server::Context qw( CTX );
use Data::Dumper;

my $MAX_TERMINATE_ATTEMPTS = 300;

=head2 start 

Start the server

=cut

sub start {
        
    my $args = shift;
    my $silent = $args->{SILENT};
    my $pid        = $args->{PID};    
    my $foreground = $args->{FOREGROUND};
    my $debug      = $args->{DEBUG} || 0;
    
        
    # Load the required locations from the config
    $ENV{OPENXPKI_CONF_DB} = $args->{CONFIG} if($args->{CONFIG});
    use OpenXPKI::Config;
    my $config = OpenXPKI::Config->new(); 
    my $pidfile  = $config->get('system.server.pid_file');
    my $socketfile = $config->get('system.server.socket_file');

    if (!$socketfile) {    
        print STDERR "Unable to load configuration\n";
        return 0;
    }
    
    # If a pid is given, we just check if the server is there
    if (defined $pid && kill(0, $pid)) {
        if (!OpenXPKI::Control::status({
            SOCKETFILE => $socketfile,
            })) {
           return;
        }    
        print STDERR "OpenXPKI Server already running. PID: $pid\n";
        return 1;
    }
    
    ## this is only an informal message and not an error - so do not use STDERR
    print STDOUT "Starting OpenXPKI...\n" if (not $silent);    
    unlink $pidfile if ($pidfile && -e $pidfile);
    
    
    # Set debug options - DEBUG is hash with the module name (wildcard) 
    # as key and the level as value or just an integer for the global level
    if (ref $debug eq '') {
        if ($debug > 0) {
            $OpenXPKI::Debug::LEVEL{'.*'} = $debug;
            $OpenXPKI::Debug::LEVEL{'OpenXPKI::XML::Cache'}  = 0;
            $OpenXPKI::Debug::LEVEL{'OpenXPKI::XML::Config'} = 0;
        }        
    } elsif(ref $debug eq 'HASH') {                
        foreach my $module (keys %{$debug}) {        
            my $level = $debug->{$module};
            print STDERR "Debug level for module '$module': $level\n";
            $OpenXPKI::Debug::LEVEL{$module} = $level;
        }
    }
    
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
                        return;
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
                return;
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

            if (length $msg)
            {
                    ## the first message is part of the informal daemon startup message
                    ## the second message is a real error message
                print STDOUT "FAILED.\n" if (not $silent);
                print STDERR "$msg\n";
                return;
            }

            # find out if the server is REALLY running properly
            if (! OpenXPKI::Control::status(
                  {
                      SOCKETFILE => $socketfile,
                  })) {
                print STDERR "Status check failed\n";
                return;
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
                my $silent = 0;
                $silent = 1 if ($silent);
                OpenXPKI::Server->new ( "SILENT" => $silent );                
            };
            if ($EVAL_ERROR)
            {
                print STDERR $EVAL_ERROR;                
            }
            close(STDOUT);
            close(STDERR);
            return;
        }
    }
    else {
        # foreground requested, do not fork
        eval {
            my $silent = 0;
            $silent = 1 if ($silent);
            OpenXPKI::Server->new(
                'SILENT' => $silent,
                'TYPE'   => 'Simple',
            );
        };
        if ($EVAL_ERROR) {
            print STDERR $EVAL_ERROR;
            return;
        }
    }
    return 1;
}    


=head2 stop

Stop the server

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
        die "You must specify either a PID or PIDFILE\n";
    }
        
    if (kill(0, $pid) == 0) {
        print STDERR "OpenXPKI Server is not running at PID $pid.\n";
        return 1;
    }
    
    my $process_group = getpgrp($pid);

    print STDOUT "Stopping OpenXPKI\n" if (not $silent);

    # get all PIDs which belong to the current process group
    my @pids = OpenXPKI::Control::__get_processgroup_pids($process_group);
    foreach my $p (@pids) {
        print STDOUT "[$p] " if (not $silent);
        my $attempts = 0;

        # wait for the process to terminate for a good amount of time
        # by sending it SIGTERM
        TERMINATE:
        while ($attempts < $MAX_TERMINATE_ATTEMPTS) {
            print STDOUT '.' if (not $silent);
            kill(15, $p);
            sleep 2;
            last TERMINATE if (kill(0, $p) == 0);
            $attempts++;
        }

        if (kill(0, $p) != 0) {
            # if that did not help, kill it hard
            $attempts = 0;
            KILL:
            while ($attempts < 5) {
                print STDOUT '+' if (not $silent);
                kill(9, $p);
                sleep 1;
                last KILL if (kill(0, $p) == 0);
                $attempts++;
            }
        }
        print STDOUT "\n" if (not $silent);

        if (kill(0, $p)) {
            print STDOUT "FAILED.\n" if (not $silent);
            print STDERR "Could not terminate OpenXPKI process $p.\n";
            return;
        }
    }
    print STDOUT "DONE.\n" if (not $silent);
    return 1;    
}

=head2 status

Check if the server is running

=cut

sub status {
    my $arg = shift;

    if (exists $arg->{SLEEP} and $arg->{SLEEP} > 0)
    {
        ## this helps to give the server some reaction time
        sleep $arg->{SLEEP};
    }

    my $socketfile = $arg->{SOCKETFILE};
    
    if (! OpenXPKI::Control::__connect_openxpki_daemon($socketfile)) {
        if (not exists $arg->{SLEEP})
        {
            ## wait for a starting server ...
            return OpenXPKI::Control::status ({SOCKETFILE => $arg->{SOCKETFILE}, SLEEP => 5});
        }
        return;
    }
    return 1;
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
    
    print $@;
    return unless defined $client;

    return 1;
}