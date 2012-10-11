## OpenXPKI::Server::Watchdog.pm
##
## Written 2012 by Dieter Siebeck for the OpenXPKI project
## Copyright (C) 2012-20xx by The OpenXPKI Project

package OpenXPKI::Server::Watchdog;
use strict;
use English;
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Session;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Watchdog::WorkflowInstance;
use OpenXPKI::DateTime;

use Net::Server::Daemonize qw( set_uid set_gid );

use Moose;

use Data::Dumper;


has workflow_table => (
    is => 'ro',
    isa => 'Str',
    default => 'WORKFLOW',
);

has max_fork_redo => (
    is => 'rw',
    isa => 'Int',
    default =>  5
);
has max_exception_threshhold => (
    is => 'rw',
    isa => 'Int',
    default =>  10
);
has max_tries_hanging_workflows => (
    is => 'rw',
    isa => 'Int',
    default =>  3
);
# All timers in seconds    
has interval_wait_initial => (
    is => 'rw',
    isa => 'Int',
    default =>  10
);
    
has interval_loop_idle => (
    is => 'rw',
    isa => 'Int',
    default =>  5
);

has interval_loop_run => (
    is => 'rw',
    isa => 'Int',
    default =>  1
);


has children => (
    is => 'rw',
    isa => 'ArrayRef',
    default  => sub { return []; }
);

has disabled => (
    is => 'ro',
    isa => 'Bool',
    default => 0,    
);
 
around BUILDARGS => sub {
     
    my $orig = shift;
    my $class = shift;

    # Properties from init system - not used 
    my $args = @_;

    my $config = CTX('config')->get_hash('system.watchdog');
    
    $config = {} unless($config); # Moose complains on null
    # This automagically sets all entries from the config 
    # to the corresponding class attributes
    return $class->$orig($config);
    
};
           
sub run {
    my $self = shift;
    my $args = shift;
    
    my $pid;
    my $redo_count = 0;
    
    if ($self->disabled()) {
        CTX('log')->log(
            MESSAGE  => 'Watchdog is disabled - will not start worker.', 
            PRIORITY => "warn",
            FACILITY => "system",
        );
        return 1;
    }
    
    $SIG{CHLD} = 'IGNORE';
    while ( !defined $pid && $redo_count < $self->max_fork_redo() ) {
        ##! 16: 'trying to fork'
        $pid = fork();
        ##! 16: 'pid: ' . $pid
        if ( !defined $pid ) {
            if ( $!{EAGAIN} ) {

                # recoverable fork error
                sleep 2;
                $redo_count++;
            } else {

                # other fork error
                OpenXPKI::Exception->throw( message => 'I18N_OPENXPKI_SERVER_INIT_WATCHDOG_FORK_FAILED', );
            }
        }
        
    }
    if ( !defined $pid ) {
        OpenXPKI::Exception->throw( message => 'I18N_OPENXPKI_SERVER_INIT_WATCHDOG_FORK_FAILED', );
    } elsif ( $pid != 0 ) {
                
        my $children = $self->children();
        push @{ $children }, $pid;       
        $self->children( $children );        
        ##! 16: 'parent here - process group: ' . getpgrp(0)
        # we have forked successfully and have nothing to do any more except for getting a new database handle
        CTX('dbi_log')->new_dbh();
        ##! 16: 'new parent dbi_log dbh'
        CTX('dbi_workflow')->new_dbh();
        ##! 16: 'new parent dbi_workflow dbh'
        CTX('dbi_backend')->new_dbh();
        ##! 16: 'new parent dbi_backend dbh'
        CTX('dbi_log')->connect();
        CTX('dbi_workflow')->connect();
        CTX('dbi_backend')->connect();
        # get new database handles
        ##! 16: 'parent: DB handles reconnected'
    } else {
        
        ##! 16: 'child here'
        CTX('dbi_log')->new_dbh();
        ##! 16: 'new child dbi_log dbh'
        CTX('dbi_workflow')->new_dbh();
        ##! 16: 'new child dbi_workflow dbh'
        CTX('dbi_backend')->new_dbh();
        ##! 16: 'new child dbi_backend dbh'
        CTX('dbi_log')->connect();
        CTX('dbi_workflow')->connect();
        CTX('dbi_backend')->connect();
        ##! 16: 'child: DB handles reconnected'

        $self->{dbi}                      = CTX('dbi_workflow');
        $self->{hanging_workflows}        = {};
        $self->{hanging_workflows_warned} = {};
        $self->{original_pid}             = $PID;
        
        # set process name
                
        $0 = sprintf ('openxpki watchdog ( %s )', CTX('config')->get('system.server.name') || 'main');

        set_gid($args->{group}) if( $args->{group} );
        set_uid($args->{user}) if( $args->{user} );
        
        #wait some time for server startup...
        ##! 16: sprintf('watchdog: original PID %d, initail wait for %d seconds', $self->{original_pid} , $self->interval_wait_initial());
 
        # Force new session as the initialized session is a Mock-Session which we can not use!
        $self->__check_session(1);
 
        CTX('log')->log(
            MESSAGE  => sprintf( 'Watchdog initialized, delays are: initial: %01d, idle: %01d, run: %01d"', 
                $self->interval_wait_initial(), $self->interval_loop_idle(), $self->interval_loop_run() ),
            PRIORITY => "info",
            FACILITY => "system",
        );
        
        sleep($self->interval_wait_initial());
        
        ### TODO: maybe we should measure the count of exception in a certain time interval?
        my $exception_count = 0;
        
        ##! 16: 'watchdog: start looping'
        
        while (1) {
            
            ##! 80: 'watchdog: do loop'
            #ensure that we have a valid session
            $self->__check_session();
            
            eval { $self->_scan_for_paused_workflows(); };
            my $error_msg;
            if ( my $exc = OpenXPKI::Exception->caught() ) {
                $exc->show_trace(1);
                $error_msg = "Watchdog, fatal exception: $exc";
            } elsif ($EVAL_ERROR) {
                $error_msg = "Watchdog, fatal error: " . $EVAL_ERROR;
            }
            if ($error_msg) {
                CTX('log')->log(
                    MESSAGE  => $error_msg,
                    PRIORITY => "fatal",
                    FACILITY => "system"
                );

                print STDERR $error_msg, "\n";
                $exception_count++;
            }
            if ( $exception_count > $self->max_exception_threshhold() ) {
                my $msg = "Watchdog: max exception limit reached: $self->max_exception_threshhold() errors, exit watchdog!";
                CTX('log')->log(
                    MESSAGE  => $msg,
                    PRIORITY => "fatal",
                    FACILITY => "system"
                );

                print STDERR $msg, "\n";
                exit;
            }

            ##! 80: sprintf('watchdog sleeps %d secs',$self->interval_loop_idle())
            sleep($self->interval_loop_idle());

        }

    }
    ##! 4: 'End of run'
}

    
sub reload {
        
    ##! 1: 'reloading'      
    my $self = shift;
    
    return if ($self->disabled());
           
    ##! 4: 'run update head'
    CTX('config')->update_head();    
}
  
sub terminate {
    my $self = shift;
   
    
    #terminate childs:
    my $children = $self->children();
    kill 'TERM', @$children;
        
    return 1;    
}


sub _scan_for_paused_workflows {
    my $self = shift;

    #search ONE paused workflow

    # commit to get a current snapshot of the database in the highest isolation level.
    $self->{dbi}->commit();

    #fetch paused workflows:
    my $db_result = $self->__fetch_paused_workflows();

    if ( !defined $db_result ) {
        #check, if an entry exists, which marked from another watchdog, but not updated since 1 minute
        $db_result = $self->_fetch_and_check_for_orphaned_workflows();
    }

    if ( !defined $db_result ) {
        ##! 80: 'no paused WF found, can be idle again...'
        return;
    }

    ##! 16: 'found paused workflow: '.Dumper($db_result)

    # we need to be VERY sure, that no other process simultaneously takes this workflow and tries to execute it
    # hence we generate a random key to mark this workflow as "mine"
    my $rand_key = $self->__gen_key();

    my $wf_id   = $db_result->{WORKFLOW_SERIAL};
    my $old_key = $db_result->{WATCHDOG_KEY};

    my $update_ok = $self->__flag_wf_with_watchdog_mark( $wf_id, $rand_key, $old_key );
    if ( !$update_ok ) {
        ##! 16: 'watchdog mark could not be set, return '
        return;
    }

    #select again:
    $db_result = $self->__fetch_marked_workflow_again( $wf_id, $rand_key );
    if ( !defined $db_result ) {
        ##! 16: sprintf('some other process took wf %s, return',$wf_id)
        return;
    }

    ##! 16: 'WF now ready to re-instantiate: '.Dumper($db_result)
    CTX('log')->log(
        MESSAGE  => sprintf( 'watchdog, paused wf %d now ready to re-instantiate, start fork process', $wf_id ),
        PRIORITY => "info",
        FACILITY => "workflow",
    );
    $self->{dbi}->commit();
    
    
    
    eval{
        #this command effectively creates an forked child process which "wakes up the workflow" 
        my $Instance = OpenXPKI::Server::Watchdog::WorkflowInstance->new();
        $Instance->run($db_result);
    };
    
    # all exceptions/fatals which occur in the forked child will be handled there
    # if an error/exception occurs here, it must be within the main (watchdog) process, so we log it as "system" error
    my $error_msg;
    if ( my $exc = OpenXPKI::Exception->caught() ) {
        $exc->show_trace(1);
        $error_msg = "Exception caught while forking child instance: $exc";
    } elsif ($EVAL_ERROR) {
        $error_msg = "Fatal error while forking child instance:" . $EVAL_ERROR;
    }
    if ($error_msg) {
        CTX('log')->log(
            MESSAGE  => $error_msg,
            PRIORITY => "fatal",
            FACILITY => "system"
        );
    }
    
    #security measure: for child processes no further than here! (all childprocesses in WorkflowInstance shourl exit properly and handle their exceptions on their own... but just in case...)
    if($self->{original_pid} ne $PID){#$self->{original_pid} == PID of Watchdog process
        ##! 16: sprintf('exit this process: actual pid %s is not original pid %s' , $PID, $self->{original_pid});
        exit;
    }
    
    #if we have found a workflow, we sleep a bit and search another paused wf
    sleep($self->interval_loop_run());
    $self->_scan_for_paused_workflows();
}



sub __fetch_marked_workflow_again {
    my $self = shift;
    my ( $wf_id, $rand_key ) = @_;
    my $db_result = $self->{dbi}->first(
        TABLE   => $self->workflow_table(),
        COLUMNS => ['WORKFLOW_SERIAL'],
        DYNAMIC => {
            'WORKFLOW_PROC_STATE' => { VALUE => 'pause' },
            'WATCHDOG_KEY'        => { VALUE => $rand_key },
            'WORKFLOW_SERIAL'     => { VALUE => $wf_id },
        },
    );

    unless ( defined $db_result ) {
        CTX('log')->log(
            MESSAGE  => sprintf( 'watchdog, refetching wf %d with mark "%s" not succesfull', $wf_id, $rand_key ),
            PRIORITY => "info",
            FACILITY => "workflow",
        );
    }

    return $db_result;
}

sub __flag_wf_with_watchdog_mark {
    my $self = shift;
    my ( $wf_id, $rand_key, $old_key ) = @_;

    return unless $wf_id;    #this is real defensive programming ...;-)

    ##! 16: 'set random key '.$rand_key

    CTX('log')->log(
        MESSAGE  => sprintf( 'watchdog: paused wf %d found, mark with flag "%s"', $wf_id, $rand_key ),
        PRIORITY => "info",
        FACILITY => "workflow",
    );

    # it is necessary to explicitely set WORKFLOW_LAST_UPDATE,
    # because otherwise ON UPDATE CURRENT_TIMESTAMP will set (maybe) a non UTC timestamp
    my $now = DateTime->now->strftime('%Y-%m-%d %H:%M:%S');
    # watchdog key will be reseted automatically, when the workflow is updated from within 
    # the API (via factory::save_workflow()), which happens immediately, when the action is executed
    # (see OpenXPKI::Server::Workflow::Persister::DBI::update_workflow())
    my $update_ok = $self->{dbi}->update(
        TABLE => $self->workflow_table(),
        DATA  => { WATCHDOG_KEY => $rand_key, WATCHDOG_TIME => $now, WORKFLOW_LAST_UPDATE => $now },
        WHERE => {
            WATCHDOG_KEY        => $old_key,
            WORKFLOW_SERIAL     => $wf_id,
            WORKFLOW_PROC_STATE => 'pause'
        }
    );

    if ( !$update_ok ) {
        CTX('log')->log(
            MESSAGE  => sprintf( 'watchdog, paused wf %d: update with mark "%s" not succesfull', $wf_id, $rand_key ),
            PRIORITY => "info",
            FACILITY => "workflow",
        );
    }
    return $update_ok;
}

sub __fetch_paused_workflows {
    my $self = shift;
    my $now  = DateTime->now->strftime('%Y-%m-%d %H:%M:%S');

    return $self->{dbi}->first(
        TABLE   => $self->workflow_table(),
        COLUMNS => ['WORKFLOW_SERIAL'],
        DYNAMIC => {
            'WORKFLOW_PROC_STATE' => { VALUE => 'pause' },
            'WATCHDOG_KEY'        => { VALUE => '' },
            'WORKFLOW_WAKEUP_AT'  => { VALUE => $now, OPERATOR => 'LESS_THAN' },
        },
    );
}

sub _fetch_and_check_for_orphaned_workflows {
    my $self = shift;
    my $now  = DateTime->now->strftime('%Y-%m-%d %H:%M:%S');

    my $time_diff = OpenXPKI::DateTime::get_validity(
        {
            VALIDITY       => '-0000000001',#should be one minute old
            VALIDITYFORMAT => 'relativedate',
        },
    )->datetime();

    my $db_result = $self->{dbi}->first(
        TABLE   => $self->workflow_table(),
        COLUMNS => ['WORKFLOW_SERIAL'],
        DYNAMIC => {
            'WORKFLOW_PROC_STATE' => { VALUE => 'pause' },
            'WATCHDOG_KEY'        => { VALUE => '', OPERATOR => 'NOT_EQUAL' },
            'WATCHDOG_TIME'       => { VALUE => $time_diff, OPERATOR => 'LESS_THAN' },
            'WORKFLOW_WAKEUP_AT'  => { VALUE => $now, OPERATOR => 'LESS_THAN' },
        },
    );

    if ( defined $db_result ) {
        ##! 16: 'found not processed workflow from another watchdog-call: '.Dumper($db_result)
        my $wf_id = $db_result->{WORKFLOW_SERIAL};

        $self->{hanging_workflows}{$wf_id}++;
        if ( $self->{hanging_workflows}{$wf_id} > $self->max_tries_hanging_workflows()) {
            ##! 16: 'hanged to often!'

            $db_result = undef;
            unless ( $self->{hanging_workflows_warned}{$wf_id} ) {
                CTX('log')->log(
                    MESSAGE => sprintf(
                        'watchdog meets hanging wf %d for %dth time, will not try to take over again',
                        $wf_id, $self->{hanging_workflows}{$wf_id}
                    ),
                    PRIORITY => "fatal",
                    FACILITY => "workflow",
                );
                $self->{hanging_workflows_warned}{$wf_id} = 1;
            }

            return;
        } else {
            CTX('log')->log(
                MESSAGE  => sprintf( 'watchdog: hanging wf %d found, try to take over!', $wf_id ),
                PRIORITY => "info",
                FACILITY => "workflow",
            );
        }
    }

    return $db_result;

}

sub __check_session{
    my $self = shift;
    my ($force_new) = @_;
    my $session;
    unless($force_new){
        eval{$session = CTX('session');};
        return if $session;
    }
    
    my $directory = CTX('config')->get("system.server.session.directory");
    my $lifetime  = CTX('config')->get("system.server.session.lifetime");
    
    ##! 4: "create new session dir: $directory, lifetime: $lifetime "
    $session = OpenXPKI::Server::Session->new({
        DIRECTORY => $directory,
        LIFETIME  => $lifetime,
    });
    OpenXPKI::Server::Context::setcontext({'session' => $session,'force'=> $force_new});
    ##! 4: sprintf(" session %s created" , $session->get_id()) 
}


sub __gen_key {

    #my $self = shift;
    return sprintf( '%s_%s_%s', $PID, time(), sprintf( '%02.d', rand(100) ) );
}


no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

The watchdog thread

=head1 DESCRIPTION

The watchdog is forked away on startup and takes care of paused workflows.
The system has a default configuration but you can override it via the system
configuration.

The namespace is I<system.watchdog>. The properties are: 

=over 

=item max_fork_redo
 
default: 5

=item max_exception_threshhold

default: 10

=item max_tries_hanging_workflows

default:  3

=item interval_wait_initial

Seconds to wait after server start before the watchdog starts scanning. 
default: 60;
    
=item interval_loop_idle

Seconds between two scan runs if no result was found on last run.
default: 5

=item interval_loop_run

Seconds between two scan runs if a result was found on last run.
default: 1

=back
