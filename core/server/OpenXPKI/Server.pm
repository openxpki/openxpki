## OpenXPKI::Server.pm
##
## Written 2005 by Michael Bell for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project
package OpenXPKI::Server;

use strict;
use warnings;
use utf8;

use base qw( Net::Server::MultiType );
use Net::Server::Daemonize qw( set_uid set_gid );

## used modules

use English;
use Socket;
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Init;
use OpenXPKI::Server::Watchdog;
use OpenXPKI::Server::Notification::Handler;
use Data::Dumper;

our $stop_soon = 0;

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    bless $self, $class;

    my $keys = { @_ };

    ## get parameters
    $self->{TYPE}   = $keys->{TYPE} // 'Fork';
    $self->{CONFIG} = $keys->{CONFIG};
    $self->{SILENT} = $keys->{SILENT};

    ## group access is allowed
    $self->{umask} = 0007; # octal

    return $self;
}

sub __init_server {
    my $self = shift;

    eval {
        # we need to get a usable logger as soon as possible, hence:
        # initialize configuration, i18n and log
        OpenXPKI::Server::Init::init({
            TASKS  => [ 'config_versioned', 'i18n', 'log' ],
            SILENT => $self->{SILENT},
        });

        # from now on we can assume that we have CTX('log') available
        # perform the rest of the initialization
        OpenXPKI::Server::Init::init({ SILENT => $self->{SILENT} });
        OpenXPKI::Server::Watchdog->start_or_reload;
    };
    $self->__log_and_die($EVAL_ERROR, 'server initialization') if $EVAL_ERROR;
}

sub __init_net_server {
    my $self = shift;

    eval {
        ## start the server
        $self->{PARAMS} = $self->__get_server_config();

        # Net::Server does not provide a hook that lets us change the
        # ownership of the created socket properly: it chowns the socket
        # file itself just before set_uid/set_gid. hence we make Net::Server
        # believe that it does not have to set_uid/set_gid itself and do this
        # a little later in the pre_loop_hook
        # to make this work, delete the corresponding settings from the
        # Net::Server init params
        if (exists $self->{PARAMS}->{user}) {
            $self->{PARAMS}->{process_owner} = $self->{PARAMS}->{user};
            delete $self->{PARAMS}->{user};
        }
        if (exists $self->{PARAMS}->{group}) {
            $self->{PARAMS}->{process_group} = $self->{PARAMS}->{group};
            delete $self->{PARAMS}->{group};
        }

        unlink ($self->{PARAMS}->{socketfile});
        CTX('log')->system()->info("Server initialization completed");

        $self->{PARAMS}->{no_client_stdout} = 1;
    };
    $self->__log_and_die($EVAL_ERROR, 'server daemon setup') if $EVAL_ERROR;
}

sub start {
    my $self = shift;

    umask $self->{umask};
    $self->__init_server;
    $self->__init_user_interfaces;
    $self->__init_net_server;

    CTX('log')->system()->info("Server is running");

    CTX('log')->audit('system')->info('server was started');

    $self->run(%{$self->{PARAMS}}); # from Net::Server::MultiType
}

sub pre_server_close_hook {
    ##! 1: 'start'
    my $self = shift;

    # remove pid and socketfile on destruction - they are no longer useful
    # if the server is not running ...
    ##! 8: 'unlink socketfile ' . $self->{PARAMS}->{socketfile}
    unlink ($self->{PARAMS}->{socketfile});
    ##! 4: 'socketfile removed'
    ##! 8: 'unlink pid file ' . $self->{PARAMS}->{pid_file}
    unlink ($self->{PARAMS}->{pid_file});
    ##! 4: 'pid_file removed'

    return 1;
}

sub DESTROY {
    ##! 1: 'start'
    my $self = shift;

    if ($self->{TYPE} ne 'Fork') {
        # for servers in the foreground, call the pre_server_close_hook
        # on destruction ...
        $self->pre_server_close_hook();
    }

    return 1;
}

# from Net::Server:
#           This hook occurs just after the bind process and just before any
#           chrooting, change of user, or change of group occurs.  At this
#           point the process will still be running as the user who started the
#           server.
sub post_bind_hook {
    my $self = shift;

    # Net::Server creates the socket file with process owner/group ownership
    # it runs as. The admin may want to make this configurable differently,
    # though.

    my $socketfile = $self->{PARAMS}->{socketfile};

    # socket ownership defaults to daemon user/group...
    # ... but can be overwritten in the config file
    my $socket_owner = $self->{PARAMS}->{socket_owner} // $self->{PARAMS}->{process_owner};
    my $socket_group = $self->{PARAMS}->{socket_group} // $self->{PARAMS}->{process_group};

    if (($socket_owner != -1) || ($socket_group != -1)) {
        # try to change socket ownership
        CTX('log')->system()->debug("Setting socket file '$socketfile' ownership to "
            . (( $socket_owner != -1) ? $socket_owner : 'unchanged' )
            . '/'
            . (( $socket_group != -1) ? $socket_group : 'unchanged' ));


        if (! chown $socket_owner, $socket_group, $socketfile) {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_POST_BIND_HOOK_COULD_NOT_CHANGE_SOCKET_OWNERSHIP",
                params  => {
                    SOCKETFILE => $socketfile,
                    SOCKET_OWNER => $socket_owner,
                    SOCKET_GROUP => $socket_group,
                },
                log => {
                    message => "Could not change ownership for socket '$socketfile' to '$socket_owner:$socket_group'",
                    facility => 'system',
                    priority => 'fatal',
                },
            );
        }
    }

    # change the owner of the pidfile to the daemon user
    my $pidfile = $self->{PARAMS}->{pid_file};
    ##! 16: 'chown pidfile: ' .  $pidfile . ' user: ' . $self->{PARAMS}->{process_owner} . ' group: ' . $self->{PARAMS}->{process_group}
    if (! chown $self->{PARAMS}->{process_owner}, $self->{PARAMS}->{process_group}, $pidfile) {
        CTX('log')->system()->error("Could not change ownership for pidfile '$pidfile' to '$socket_owner:$socket_group'");

    }

    my $env = CTX('config')->get_hash('system.server.environment');
    foreach my $var (keys %{$env}) {
        my $value = $env->{$var};
        ##! 16: "ENV{$var} = $value"
        $ENV{$var} = $value;
    }

    return 1;
}

# from Net::Server:
#           This hook occurs after chroot, change of user, and change of group
#           has occured.  It allows for preparation before looping begins.
sub pre_loop_hook {
    my $self = shift;

    # we are duplicating code from Net::Server::post_bind() here because
    # Net::Server does not provide a hook that is executed BEFORE.
    # we are tricking Net::Server to believe that it should not change
    # owner and group of the process and do it ourselves shortly afterwards

    ### drop privileges
    eval{

        # Set verbose process name
        OpenXPKI::Server::__set_process_name("server");

        if( $self->{PARAMS}->{process_group} ne $) ){
            $self->log(
                2,
                "Setting gid to \"$self->{PARAMS}->{process_group}\""
            );
            CTX('log')->system()->debug("Setting gid to to "
                            . $self->{PARAMS}->{process_group});

            set_gid( $self->{PARAMS}->{process_group} );
        }
        if( $self->{PARAMS}->{process_owner} ne $> ){
            $self->log(
                2,
                "Setting uid to \"$self->{PARAMS}->{process_owner}\""
            );
            CTX('log')->system()->debug("Setting uid to to " . $self->{PARAMS}->{process_owner});

            set_uid( $self->{PARAMS}->{process_owner} );
        }
    };
    if( $EVAL_ERROR ){
        if ( $> == 0 ) {
            CTX('log')->system()->fatal($EVAL_ERROR);

        die $EVAL_ERROR;
        } elsif( $< == 0) {
            CTX('log')->system()->warn("Effective UID changed, but Real UID is 0: $EVAL_ERROR");
        } else {
            CTX('log')->system()->error($EVAL_ERROR);

        }
    }
    if ($self->{TYPE} eq 'Simple') {
        # the Net::Server::Fork forked children have the DEFAULT
        # signal handler for SIGCHLD (instead of the Net::Server
        # sigchld handler).
        # We need it, too, because otherwise
        # $? is -1 after a `$command` backtick call
        # (for example when doing external dynamic authentication) ...
        $SIG{CHLD} = 'DEFAULT';
    }

}

sub sig_term {
    # in the TERM signal handler, just set the global 'stop_soon' variable,
    # which will be checked in the services
    ##! 1: 'start'
    # if an alarm is active, decrease the time to alarm to 1, so that
    # the stopping can take place "pretty soon now"
    my $current_alarm = alarm(0);
    ##! 16: 'current alarm timeout: ' . $current_alarm
    if ($current_alarm > 0) {
        ##! 16: 'current alarm > 0, resetting to 1'
        alarm(1);
    }
    $stop_soon = 1;
    # terminate the watchdog
    # This is obsolete for a "global shutdown" using the OpenXPKI::Control::stop
    # method but should be kept in case somebody sends a term to the daemon which
    # will stop spawning of new childs but should allow existing ones to finish
    # FIXME - this will cause the watchdog to terminate if you kill a child,
    # so we remove this
    #OpenXPKI::Server::Watchdog->terminate;

    ##! 1: 'end'
}

sub sig_hup {
    ##! 1: 'start'
    my $pids = OpenXPKI::Control::get_pids();

    CTX('log')->system()->info(sprintf "SIGHUP received - cleanup childs (%01d found)", scalar @{$pids->{worker}});

    if (@{$pids->{worker}}) {
        kill 15, @{$pids->{worker}};
    }

    # FIXME - should also reinit some of the services

    ##! 8: 'watchdog'
    my $watchdog_disabled = CTX('config')->get('system.watchdog.disabled') || 0;
    if ($watchdog_disabled) {
        OpenXPKI::Server::Watchdog->terminate;
    }
    else {
        OpenXPKI::Server::Watchdog->start_or_reload;
    }
}

sub process_request {
    my $rc;
    my $msg;

    # Re-seed Perl random number generator (only used for temp file name creation, not for actual
    # cryptographic operation), otherwise children inherit common initialization from parent process.
    # Without this line the forked clients will very often generate temp file names clashing with
    # each other.
    srand(time ^ $PROCESS_ID);

    eval
    {
        $rc = do_process_request(@_);
    };
    if (my $exc = OpenXPKI::Exception->caught()) {
        if ($exc->message() =~ m{ (?:
                I18N_OPENXPKI_TRANSPORT.*CLOSED_CONNECTION
                | I18N_OPENXPKI_SERVICE_COLLECT_TIMEOUT
            ) }xms) {
            # exit quietly
            return 1;
        }

        # other OpenXPKI exceptions
        $msg = $exc->full_message();
    } elsif ($EVAL_ERROR) {
        # non-OpenXPKI "exception"
        $msg = $EVAL_ERROR;
    }

    if (defined $msg) {
        CTX('log')->system()->fatal("Uncaught exception: " . $msg);

        # die gracefully
        ##! 1: "Uncaught exception: " . Dumper $msg
        $ERRNO = 1;

        return;
    }

    return $rc;
}


sub do_process_request {
    ##! 2: "start"
    my $self = shift;

    my $log = CTX('log')->system();

    ## recover from umask of Net::Server->run
    umask $self->{umask};

    # masquerade process...
    OpenXPKI::Server::__set_process_name("worker: new");

    ##! 2: "transport protocol detector"
    my $transport = undef;
    my $line = "";
    while (not $transport) {
        my $char;
        if (! read($self->{server}->{client}, $char, 1)) {
            print STDOUT "OpenXPKI::Server: Connection closed unexpectly.\n";
            $log->fatal("Connection closed unexpectly.");
            return;
        }
        $line .= $char;
        ## protocol detection
        if ($line eq "start Simple\n") {
            $transport = OpenXPKI::Transport::Simple->new ({
                SOCKET => $self->{server}->{client},
            });
            send($self->{server}->{client}, "OK\n", 0);
        }
        elsif ($char eq "\n") {
            print STDOUT "OpenXPKI::Server: Unsupported protocol.\n";
            $log->fatal("Unsupported protocol.");
            return;
        }
    }

    ##! 2: "serialization protocol detector"
    my $serializer = undef;
    my $msg = $transport->read();

    if ($msg =~ m{ \A (?:Simple|JSON|Fast) \z }xms) {
        eval "\$serializer = OpenXPKI::Serialization::$msg->new();";

        if (! defined $serializer) {
            $transport->write("OpenXPKI::Server: Serializer failed to initialize.\n");
            $log->fatal("Serializer '$msg' failed to initialize.");
            return;
        }
        $transport->write ("OK");
    }
    else {
        $transport->write("OpenXPKI::Server: Unsupported serializer.\n");
        $log->fatal("Unsupported serializer.");
        return;
    }

    ##! 2: "service detector - deserializing data"
    my $data = $serializer->deserialize ($transport->read());

    ##! 64: "service detector - received type: $data"

    # By the way, if you're adding support for a new service here,
    # You need to add a matching entry in system/server.yaml
    # below the "service" key.
    my $service;

    if ($data eq "Default") {
        $service = OpenXPKI::Service::Default->new({
             TRANSPORT     => $transport,
             SERIALIZATION => $serializer,
        });
        $transport->write($serializer->serialize ("OK"));
    }
    elsif ($data eq 'SCEP') {
        $service = OpenXPKI::Service::SCEP->new({
            TRANSPORT     => $transport,
            SERIALIZATION => $serializer,
        });
        $transport->write($serializer->serialize('OK'));
    }
    else {
        $transport->write($serializer->serialize("OpenXPKI::Server: Unsupported service.\n"));
        $log->fatal("Unsupported service.");
        return;
    }

    ##! 2: "update pre-initialized variables"

    eval {
        CTX('dbi')->dbh;
    };
    if (my $eval_err = $EVAL_ERROR) {
        $transport->write ($serializer->serialize ($eval_err->message()));
        $log->fatal("Database connection failed. ".$eval_err);
        return;
    }
    ##! 16: 'connection to database successful'

    # this is run until the user has logged in successfully
    ##! 16: 'calling OpenXPKI::Service::*->init()'
    $service->init();

    ##! 16: 'reloading secret groups in crypto layer'
    CTX('crypto_layer')->reload_all_secret_groups_from_cache();

    ## use user interface
    ##! 16: 'calling OpenXPKI::Service::*->run()'
    $service->run();
}

###########################################################################
# private methods

sub __init_user_interfaces {
    my $self = shift;

    eval {
        ##! 1: "start"

        my $config = CTX('config');

        ##! 2: "init transport protocols"

        my $transport = $config->get_hash("system.server.transport");
        for my $class (keys %{$transport}) {
            next unless ($transport->{$class});

            $class = "OpenXPKI::Transport::".$class;
            eval "use $class;";
            if ($EVAL_ERROR) {
                OpenXPKI::Exception->throw (
                    message => "I18N_OPENXPKI_SERVER_GET_USER_INTERFACE_TRANSPORT_FAILED",
                    params  => {
                        EVAL_ERROR => $EVAL_ERROR,
                        MODULE     => $class
                    },
                    log => {
                        message => "Could not initialize configured transport layer '$class': $EVAL_ERROR",
                        facility => 'system',
                        priority => 'fatal',
                    },
                );
            }
        }

        ##! 2: "init services"

        my @services = $config->get_keys("system.server.service");
        for my $class (@services) {
            next unless ($config->get("system.server.service.$class.enabled"));

            ##! 4: "init $class"
            $class = "OpenXPKI::Service::".$class;
            eval "use $class;";
            if ($EVAL_ERROR) {
                ##! 8: "use $class failed"
                OpenXPKI::Exception->throw (
                    message => "I18N_OPENXPKI_SERVER_GET_USER_INTERFACE_SERVICE_FAILED",
                    params  => {
                        EVAL_ERROR => $EVAL_ERROR,
                        MODULE     => $class
                    },
                    log => {
                        message => "Could not initialize configured service layer '$class': $EVAL_ERROR",
                        facility => 'system',
                        priority => 'fatal',
                    },
                );
            }
        }
    };
    $self->__log_and_die($EVAL_ERROR, 'interface initialization') if $EVAL_ERROR;

    ##! 1: "finished"
    return 1;
}

# returns numerical user id for specified user (name or id)
# undef if not found
sub __get_numerical_user_id {
    my $arg = shift;

    return unless defined $arg;

    my ($pw_name,$pw_passwd,$pw_uid,$pw_gid,
        $pw_quota,$pw_comment,$pw_gcos,$pw_dir,$pw_shell,$pw_expire) =
        getpwnam ($arg);

    if (! defined $pw_uid && ($arg =~ m{ \A \d+ \z }xms)) {
    ($pw_name,$pw_passwd,$pw_uid,$pw_gid,
     $pw_quota,$pw_comment,$pw_gcos,$pw_dir,$pw_shell,$pw_expire) =
         getpwuid ($arg);
    }

    return $pw_uid;
}

# returns numerical group id for specified group (name or id)
# undef if not found
sub __get_numerical_group_id {
    my $arg = shift;

    return unless defined $arg;

    my ($gr_name,$gr_passwd,$gr_gid,$gr_members) =
        getgrnam ($arg);

    if (! defined $gr_gid && ($arg =~ m{ \A \d+ \z }xms)) {
    ($gr_name,$gr_passwd,$gr_gid,$gr_members) =
        getgrgid ($arg);
    }

    return $gr_gid;
}


sub __get_server_config {
    my $self = shift;
    my %params = ();

    ##! 1: "start"
    my $config = CTX('config');

    my $socketfile = $config->get('system.server.socket_file');

    # check if socket filename is too long
    if (unpack_sockaddr_un(pack_sockaddr_un($socketfile)) ne $socketfile) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_CONFIG_SOCKETFILE_TOO_LONG",
            params  => { SOCKETFILE => $socketfile },
            log => {
                message => "Socket file '$socketfile' path length exceeds system limits",
                facility => 'system',
                priority => 'fatal',
            },
        );
    }

    $params{alias} = $config->get('system.server.name') || 'main';
    $params{socketfile} = $socketfile;
    $params{proto}      = "unix";
    if ($self->{TYPE} eq 'Simple') {
        $params{server_type} = 'Single';
    }
    elsif ($self->{TYPE} eq 'Fork') {
        $params{server_type} = 'Fork'; # TODO - try to make it possible to use PreFork
        $params{background}  = 1;
    }
    else {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER__GET_SERVER_CONFIG_UNKNOWN_SERVER_TYPE',
            params  => { TYPE => $self->{TYPE}, },
            log => {
                message => "Unknown Net::Server type '$self->{TYPE}'",
                facility => 'system',
                priority => 'fatal',
            },
        );
    }
    $params{user}     = $config->get('system.server.user');
    $params{group}    = $config->get('system.server.group');
    $params{port}     = $socketfile . '|unix';
    $params{pid_file} = $config->get('system.server.pid_file');

    ## check daemon user
    for my $param (qw( user group port pid_file )) {
        unless ($params{$param}) {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_CONFIG_MISSING_PARAMETER",
                params  => { "PARAMETER" => $param },
                log => {
                    message => "Missing server configuration parameter '$param'",
                    facility => 'system',
                    priority => 'fatal',
                },
            );
        }
    }

    my $user = __get_numerical_user_id($params{user});
    if (not defined $user or $user eq '') {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_CONFIG_INCORRECT_USER",
            params  => { "USER" => $params{"user"} },
            log => {
                message => "Incorrect system user '$params{user}'",
                facility => 'system',
                priority => 'fatal',
            },
        );
    }
    # convert user id to numerical
    $params{user} = __get_numerical_user_id($user);

    my $group = __get_numerical_group_id($params{group});
    if (not defined $group or $group eq '') {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_CONFIG_INCORRECT_DAEMON_GROUP",
            params  => { "GROUP" => $params{"group"} },
            log => {
                message => "Incorrect system group '$params{group}'",
                facility => 'system',
                priority => 'fatal',
            },
        );
    }
    # convert group id to numerical
    $params{group} = __get_numerical_group_id($group);

    # check if we have different ownership settings for the socket
    my $socket_owner = $config->get('system.server.socket_owner');
    if (defined $socket_owner) {
        # convert user id to numerical
        $params{socket_owner} = __get_numerical_user_id($socket_owner);

        if (not defined $params{socket_owner} or $params{socket_owner} eq '') {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_CONFIG_INCORRECT_SOCKET_OWNER",
                params  => {
                    "SOCKET_OWNER" => $socket_owner,
                },
                log => {
                    message => "Incorrect socket owner '$socket_owner'",
                    facility => 'system',
                    priority => 'fatal',
                },
            );
        }
    }

    my $socket_group = $config->get('system.server.socket_group');
    if (defined $socket_group) {
        # convert group id to numerical
        $params{socket_group} = __get_numerical_group_id($socket_group);

        if (not defined $params{socket_group} or $params{socket_group} eq '') {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_CONFIG_INCORRECT_SOCKET_OWNER_GROUP",
                params  => { "SOCKET_GROUP" => $socket_group },
                log => {
                    message => "Incorrect socket group '$socket_group'",
                    facility => 'system',
                    priority => 'fatal',
                },
            );
        }
    };

    return \%params;
}

sub __set_process_name {

    my $identity = shift;
    my @args = @_;
    if (@args) {
        $identity = sprintf $identity, @args;
    }

    my $alias = CTX('config')->get(['system','server','name']) || 'main';
    $0 = "openxpkid ($alias) $identity";
    return;

}

################################################
##                 WARNING                    ##
################################################
##                                            ##
## Before you change the code please read the ##
## following explanation and be sure that you ##
## understand it.                             ##
##                                            ##
## The basic design idea is that if there is  ##
## an error then it must be impossible that a ##
## deeper layer can be reached. This will be  ##
## guaranteed by the following rules:         ##
##                                            ##
## 1. Never use eval to handle thrown         ##
##    exceptions.                             ##
##                                            ##
## 2. If you use eval to catch an exception   ##
##    then the eval block must include all    ##
##    lower layers.                           ##
##                                            ##
## The result is that if a layer throws an    ##
## exception then it is impossible that a     ##
## lower is reached.                          ##
##                                            ##
################################################

sub __log_and_die {
    ##! 1: 'start'
    my $self  = shift;
    my $error = shift;
    my $when  = shift;

    my $log_message;
    if (ref $error eq 'OpenXPKI::Exception') {
        ##! 16: 'error is exception'
        $error->show_trace(1);
        my $msg = $error->full_message();
        $log_message = "Exception during $when: $msg ($error)";
    }
    else {
        ##! 16: 'error is something else'
        $log_message = "Eval error during $when: $error";
    }
    ##! 16: 'log_message: ' . $log_message

    CTX('log')->system()->fatal($log_message);


    # kill watchdog instances (if running)
    OpenXPKI::Server::Watchdog->terminate;

    # die gracefully
    $ERRNO = 1;
    ##! 1: 'end, dying'
    die $log_message;

    return 1;
}

### obsolete??? (ak, 2007/03/12)
sub command
{
    my $self = shift;

    ## check that there is a session

    if (not CTX('session'))
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_COMMAND_MISSING_SESSION");
    }

    ## try to authenticate the user

    CTX('authentication')->login() unless CTX('session')->is_valid;
}

1;
__END__

=head1 Name

OpenXPKI::Server - central server class (the daemon class).

=head1 Description

This is the main server class of OpenXPKI. If you want to start an
OpenXPKI server then you must instantiate this class. Please always
remember that an instantiation of this module is a startup of a
trustcenter.

=head1 Functions

=head2 new

starts the server. It needs some parameters to configure the server
but if they are correct then an exec will be performed. The parameters
are the following ones:

=over

=item * DAEMON_USER

=item * DAEMON_GROUP

=item * CONFIG

=item * SILENT (for silent startup with start-stop-daemons during System V init)

=back

All parameters are required.

=head2 process_request

is the function which is called by Net::Server to make the
work. The only parameter is the class instance. The
communication is handled via STDIN and STDOUT.

The class selects the user interfaces and checks the
pre-initialized variables. If all of this is fine then
the user interface will be initialized and started.

=head2 do_process_request

does the actual work of process_request:
determines transport, serialization and service from the user
input and calls the init() and run() methods on the corresponding
service. It also does some housekeeping such as setting permissions,
setting the process name, etc.

=head2 post_bind_hook

Is executed (by Net::Server) just after the bind process and just before
any chrooting, change of user, or change of group occurs. Changes
the socket ownership based on the configuration.

=head2 pre_loop_hook

Drops privileges to the user configured in the configuration file just
before starting the main server loop.

=head2 command

is normal layer stack where the user interfaces can execute
commands.

=head2 Server Configuration

=head3 __redirect_stderr

Send all messages to STDERR directly to a file. The file is specified in
the XML configuration.

=head3 __init_user_interfaces

Initialize the supported user interfaces (i.e. load classes).

=head3 __get_server_config

Prepares the complete server configuration to startup a socket
based server with Net::Server::Fork. It returns a hashref.
