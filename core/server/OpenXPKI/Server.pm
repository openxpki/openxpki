package OpenXPKI::Server;
use OpenXPKI -base => 'Net::Server::MultiType';

# Core modules
use Socket;
use Module::Load ();

# CPAN modules
use Net::Server::Daemonize qw( set_uid set_gid );
use Log::Log4perl qw(:levels);

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Init;
use OpenXPKI::Server::Watchdog;
use OpenXPKI::Server::Notification::Handler;
use OpenXPKI::Util;
use OpenXPKI::Control::Server;
use OpenXPKI::Service::CLI;


our $stop_soon = 0;
our $main_pid;

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    bless $self, $class;

    my $keys = { @_ };

    ## get parameters
    $self->{TYPE}   = $keys->{TYPE} // 'Fork';
    $self->{SILENT} = $keys->{SILENT};
    $self->{BACKGROUND} = ($keys->{NODETACH} ? 0 : 1);
    $self->{CONFIG} = $keys->{CONFIG};

    ## group access is allowed
    $self->{umask} = 0007; # octal

    return $self;
}

sub start {
    my $self = shift;

    umask $self->{umask};

    $self->__init_server;

    CTX('log')->system->info(sprintf("Server: %s", OpenXPKI::Control::Server->new->get_version(config => CTX('config'))));
    CTX('log')->system->info(sprintf("Perl: %s", $^V->normal));
    if (CTX('log')->system->is_debug) {
        CTX('log')->system->debug("Environment:");
        CTX('log')->system->debug(sprintf(" - %s = %s", $_, $ENV{$_})) for sort keys %ENV;
    }

    $self->__init_user_interfaces;
    $self->__init_net_server;

    ##! 1: "server is up (type = " . $self->{TYPE} . ")"

    CTX('log')->system()->info("Server is running");

    CTX('log')->audit('system')->info('server was started');

    # Disconnect database before Net::Server forks esp. to fix warnings when
    # using DBD::MariaDB (DBI occasionally warns: "DBI active kids (-1) < 0").
    # DBIx::Handler sets (Auto)InactiveDestroy which should prevent such
    # problems but DBD::MariaDB does not seem to properly handle it.
    # Also see https://github.com/perl5-dbi/DBD-MariaDB/pull/175.
    # This workaround should not cause problems because DBIx::Handler does a
    # reconnect if neccessary.
    # FIXME Remove workaround when https://github.com/perl5-dbi/DBD-MariaDB/pull/175 is resolved
    eval { CTX('dbi')->disconnect if OpenXPKI::Server::Context::hascontext('dbi') };
    eval { CTX('dbi_log')->disconnect if OpenXPKI::Server::Context::hascontext('dbi_log') };

    $self->run(%{$self->{PARAMS}}); # from Net::Server::MultiType
}

sub cleanup {
    eval { CTX('config')->cleanup };
    eval { CTX('dbi')->disconnect };
    eval { CTX('dbi_log')->disconnect };
}

sub pre_server_close_hook {
    ##! 1: 'start'
    my $self = shift;

    # remove pid and socketfile on destruction - they are no longer useful
    # if the server is not running ...
    if ($self->{PARAMS}->{socketfile}) {
        ##! 8: 'unlink socketfile ' . $self->{PARAMS}->{socketfile}
        unlink $self->{PARAMS}->{socketfile};
        ##! 4: 'socketfile removed'
    }
    if ($self->{PARAMS}->{pid_file}) {
        ##! 8: 'unlink pid file ' . $self->{PARAMS}->{pid_file}
        unlink $self->{PARAMS}->{pid_file};
        ##! 4: 'pid_file removed'
    }

    # if this is the main process
    if ($main_pid and $main_pid == $$) {
        # stop metrics server
        if (CTX('metrics')->enabled) {
            try {
                require OpenXPKI::Metrics::Prometheus; # this is EE code
                OpenXPKI::Metrics::Prometheus->terminate;
            }
            catch ($err) { warn $err }
        }

        # stop watchdog
        try {
            ##! 1: 'pre_server_close_hook() in main server - terminate watchdog'
            OpenXPKI::Server::Watchdog->terminate;
        }
        catch ($err) { warn $err }
    }

    try {
        $self->cleanup;
    }
    catch ($err) { warn $err }
}

# Net::Server method
sub write_to_log_hook {
    my $self = shift;
    my $syslog_level = shift; # Net::Server/log_level: 0=>'err', 1=>'warning', 2=>'notice', 3=>'info', 4=>'debug'.
    my $msg = shift;

    my %syslog_to_l4p = ( 0 => $ERROR, 1 => $WARN, 2 => $INFO, 3 => $DEBUG, 4 => $TRACE );

    CTX('log')->system->log($syslog_to_l4p{$syslog_level}, $msg);
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

    $main_pid = $$;
    my $socketfile = $self->{PARAMS}->{socketfile};

    # socket ownership defaults to daemon user/group...
    # ... but can be overwritten in the config file
    # ... empty value means we where started as user already
    my $process_owner = $self->{PARAMS}->{process_owner};
    my $process_group = $self->{PARAMS}->{process_group};
    my $socket_owner = $self->{PARAMS}->{socket_owner} // $process_owner // -1;
    my $socket_group = $self->{PARAMS}->{socket_group} // $process_group // -1;
    my $socket_mode = $self->{PARAMS}->{socket_mode};

    if (($socket_owner != -1) || ($socket_group != -1)) {
        # try to change socket ownership
        ##! 16: 'chown socket: ' .  $socketfile . ' user: ' . $socket_owner . ' group: ' . $socket_group
        CTX('log')->system()->debug("Setting socket file '$socketfile' ownership to "
            . (( $socket_owner != -1) ? $socket_owner : 'unchanged' )
            . '/'
            . (( $socket_group != -1) ? $socket_group : 'unchanged' )
        );


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

    # change mode of socket if requested
    if ($socket_mode) {
        CTX('log')->system()->debug("Setting permission on '$socketfile' to '$socket_mode'");
        chmod (oct($socket_mode), $socketfile) || die "Unable to change mode to '$socket_mode' on socketfile $socketfile";
    }

    # change the owner of the pidfile to the daemon user
    my $pidfile = $self->{PARAMS}->{pid_file};
    ##! 16: 'chown pidfile: ' .  $pidfile . ' user: ' . $process_owner . ' group: ' . $process_group
    if (! chown $process_owner, $process_group, $pidfile) {
        CTX('log')->system()->error("Could not change ownership for pidfile '$pidfile' to '$process_owner:$process_group'");
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

    # 2025-05: As it is possible to have a process running in mutliple groups
    #   it is possible to get rid of all this extra code when we accept that
    #   we can not set the socket_owner to a different user.
    #   As this might something which can not be fixed easily in a customer
    #   environment with the old CGI frontend we keep this solution for now
    #   and add a deprecation warning

    ### drop privileges
    eval{
        # Set verbose process name
        OpenXPKI::Server::__set_process_name("server");

        # can be empty if we are startet as non-root (via systemd)
        my $gid = $self->{PARAMS}->{process_group};
        if ( $gid && $gid ne $EGID ){
            $self->log(2, "Setting GID to '$gid'");
            CTX('log')->system->debug("Setting GID to '$gid'");

            set_gid( $gid );
        }
        my $uid = $self->{PARAMS}->{process_owner};
        if ( $uid && $uid ne $EUID ){
            $self->log(2, "Setting UID to '$uid'");
            CTX('log')->system->debug("Setting UID to '$uid'");

            set_uid( $uid );
        }
    };
    if ($EVAL_ERROR){
        if ($EUID == 0) {
            CTX('log')->system->fatal($EVAL_ERROR);
            die $EVAL_ERROR;
        } elsif($UID == 0) {
            CTX('log')->system->warn("Effective UID changed, but Real UID is 0: $EVAL_ERROR");
        } else {
            CTX('log')->system->error($EVAL_ERROR);
        }
    }

    # For Net::Server::Fork and ::PreFork we don't overwrite the SIGCHLD handler
    # to not interfere with their child tracking.
    # The *child* processes of Fork and PreFork will set SIGCHLD set to 'DEFAULT'
    # so that calls to system() etc. work.
    # For Net::Server::Single we do use our special SIGCHLD handler by setting
    # keep_parent_sigchld => 0 to make subsequent calls to system() work (as
    # they happen in the same process in this case).
    my $is_forking = $self->{TYPE} eq 'Fork' || $self->{TYPE} eq 'PreFork';

    # Start watchdog late in Net::Server startup phase so that Net::Server's
    # SIGCHLD handler has been set.
    OpenXPKI::Server::Watchdog->start_or_reload(keep_parent_sigchld => $is_forking);

    # Start metrics server
    if (CTX('config')->get(['system','metrics','enabled'])) {
        try {
            my $agent = CTX('config')->get_hash(['system','metrics','agent']) // {};
            require OpenXPKI::Metrics::Prometheus; # this is EE code
            OpenXPKI::Metrics::Prometheus->start(
                user  => $agent->{user}  // $EUID,
                group => $agent->{group} // $EGID+0,
                host  => $agent->{host}  // 'localhost',
                port  => $agent->{port}  // 7070,
                keep_parent_sigchld => $is_forking,
            );
        }
        catch ($err) {
            if ($err =~ m{locate OpenXPKI/Metrics/Prometheus\.pm in \@INC}) {
                CTX('log')->system->warn('Cannot start Prometheus agent: EE class OpenXPKI::Metrics::Prometheus not found');
            }
            else {
                die $err;
            }
        }
    }
}

# calles with PreFork when child is forked
sub child_init_hook {

    my $self = shift;
    OpenXPKI::Server::__set_process_name("worker: init");

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
    # This is obsolete for a "global shutdown" using the OpenXPKI::Control::Server->new->stop
    # method but should be kept in case somebody sends a term to the daemon which
    # will stop spawning of new childs but should allow existing ones to finish
    # FIXME - this will cause the watchdog to terminate if you kill a child,
    # so we remove this
    #OpenXPKI::Server::Watchdog->terminate;

    ##! 1: 'end'
}

sub sig_hup {
    ##! 1: 'start'
    my $pids = OpenXPKI::Control::Server->get_pids();

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
        OpenXPKI::Server::Watchdog->start_or_reload(keep_parent_sigchld => 1);
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

    eval { $rc = do_process_request(@_) };

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
    OpenXPKI::Server::__set_process_name("worker: connecting");

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
        eval {
            my $class = "OpenXPKI::Serialization::$msg";
            Module::Load::load($class);
            $serializer = $class->new;
        };

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

    my $check_service_enabled = sub ($service_name) {
        if (CTX('config')->get("system.server.service.$service_name.enabled")) {
            return 1;
        } else {
            $transport->write($serializer->serialize("Service '$service_name' is not enabled.\n"));
            $log->warn("Request to disabled service '$service_name'");
            return;
        }
    };
    ##! 64: "service detector - received type: $data"

    # By the way, if you're adding support for a new service here,
    # You need to add a matching entry in system/server.yaml
    # below the "service" key.
    my $service;

    if ($data eq "Default") {
        $check_service_enabled->($data) or return;
        $service = OpenXPKI::Service::Default->new({
             TRANSPORT     => $transport,
             SERIALIZATION => $serializer,
        });
    }
    elsif ($data eq 'CLI') {
        $check_service_enabled->($data) or return;
        my $idle_timeout = CTX('config')->get('system.server.service.CLI.idle_timeout');
        my $max_execution_time = CTX('config')->get('system.server.service.CLI.max_execution_time');

        # Refactoring ongoing - Moose class - expects array not hash
        $service = OpenXPKI::Service::CLI->new(
            transport => $transport,
            serialization => $serializer,
            $idle_timeout ? (idle_timeout => $idle_timeout) : (),
            $max_execution_time ? (max_execution_time => $max_execution_time) : (),
        );
    }
    else {
        $transport->write($serializer->serialize("OpenXPKI::Server: Unsupported service.\n"));
        $log->fatal("Request to unsupported service '$data'");
        return;
    }

    $transport->write($serializer->serialize ("OK"));

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

    ## use user interface
    ##! 16: 'calling OpenXPKI::Service::*->run()'
    $service->run();

    OpenXPKI::Server::__set_process_name("worker: wfc");

}

###########################################################################
# private methods

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
        my %p = ( SILENT => $self->{SILENT} );
        if (!$self->{BACKGROUND}) {
            $p{SKIP} = [ 'redirect_stderr' ];
        }
        OpenXPKI::Server::Init::init( \%p );
    };
    $self->__log_and_die($EVAL_ERROR, 'server initialization') if $EVAL_ERROR;
}

sub __init_net_server {
    my $self = shift;

    ##! 1: "start"

    eval {
        $self->{PARAMS} = $self->__get_server_config();
        unlink ($self->{PARAMS}->{socketfile});
        CTX('log')->system()->info("Server initialization completed");

        $self->{PARAMS}->{no_client_stdout} = 1;
    };
    $self->__log_and_die($EVAL_ERROR, 'server daemon setup') if $EVAL_ERROR;

    ##! 1: "finished"

}

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
            eval { Module::Load::load($class) };
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
            eval { Module::Load::load($class) };
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

sub __get_server_config {
    my $self = shift;
    my %params = (
        process_owner => $EUID,
        # EGID is a list of ALL groups the user is in
        # adding 0 triggers type conversion which keeps the first integer
        process_group => $EGID+0,
        proto => "unix"
    );

    ##! 1: "start"
    my $config = CTX('config');

    # User and Socket information is set via CONFIG
    # socket_file and pid_file is mandatory
    $params{pid_file}   = $self->{CONFIG}->{pid_file} || die "pid_file is mandatory for OpenXPKI::Server";
    $params{socketfile} = $self->{CONFIG}->{socket_file} || die "socket_file is mandatory for OpenXPKI::Server";
    $params{socket_mode} = $self->{CONFIG}->{socket_mode} if ($self->{CONFIG}->{socket_mode});
    $params{port}       = $params{socketfile} . '|unix';

    # check if socket filename is too long
    die "server socket_file exceeds system limits"
        unless (unpack_sockaddr_un(pack_sockaddr_un($params{socketfile})) eq $params{socketfile});

    $params{alias} = CTX('config')->get(['system','server','name']) || 'main';

    if ($self->{TYPE} eq 'Simple') {
        $params{server_type} = 'Single';
    }
    elsif ($self->{TYPE} eq 'Fork') {
        $params{server_type} = 'Fork';
        $params{background} = $self->{BACKGROUND};
    }
    elsif ($self->{TYPE} eq 'PreFork') {
        $params{server_type} = 'PreFork';
        $params{background} = $self->{BACKGROUND};

        foreach my $key (('min_servers','min_spare_servers','max_spare_servers','max_servers','max_requests')) {
            if (my $val = $config->get(['system','server','prefork',$key])) {
                $params{$key} = $val;
            }
        }
        ##! 32: 'Start prefork with params ' . Dumper \%params

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

    try {
        # resolve process owner, empty is ok as values are preset from EUID/EGID
        my (undef, $process_uid, undef, $process_gid)
          = OpenXPKI::Util->resolve_user_group($self->{CONFIG}->{user}//'', $self->{CONFIG}->{group}//'', 'server process', 1);

        $params{process_owner} = $process_uid if defined $process_uid;
        $params{process_group} = $process_gid if defined $process_gid;

        # resolve socket owner, allow and pass through empty user/group
        my (undef, $socket_uid, undef, $socket_gid)
          = OpenXPKI::Util->resolve_user_group($self->{CONFIG}->{socket_owner}//'', $self->{CONFIG}->{socket_group}//'', 'socket', 1);

        if (defined $socket_uid) {
            warn "using socket_owner is deprecated and will be removed in next relase\n".
                "please use socket_group instead!\n";
            $params{socket_owner} = $socket_uid ;
        }
        $params{socket_group} = $socket_gid if defined $socket_gid;
    }
    catch ($err) {
        OpenXPKI::Exception->throw(
            message => "Error in 'system.server' configuration: $err",
            log => { priority => 'fatal' },
        );
    }

    ##! 1: "finished"

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
    if (blessed $error and $error->isa('OpenXPKI::Exception')) {
        ##! 16: 'error is exception'
        $error->show_trace(0);
        my $msg = $error->full_message();
        $log_message = "Exception during $when: $msg ($error)";
    }
    else {
        ##! 16: 'error is something else'
        $log_message = "Error during $when: $error";
    }
    ##! 16: 'log_message: ' . $log_message

    CTX('log')->system->fatal($log_message);

    # die gracefully
    $ERRNO = 1;
    ##! 1: 'end, dying'
    die $log_message;

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server - central server class (the daemon class).

=head1 Description

This is the main server class of OpenXPKI. It will start the OpenXPKI
trustcenter.

=head1 Functions

=head2 new

Constructor. Parameters to configure the server:

=over

=item * TYPE - (I<Str>) C<Fork> or C<PreFork>, default: C<Fork>

=item * SILENT - (I<Bool>) silent startup with start-stop-daemons during System V init

=item * NODETACH - (I<Bool>) run the parent process in foreground (i.e. no daemon)

=item * CONFIG - (I<HashRef>) user/group and socket related settings

=back

=head2 start

Start the server process. This method never returns.

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
before starting the main server loop. Also starts the Watchdog process.

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

=head2 __set_process_name

Set the process name that is visible via e.g. ps.

Values used inside OpenXPKI (for easy reference):

=over

=item server

Initial value of all childs, remains for the main server process

=item watchdog

The watchdog process

=item worker: init

PreForked child before its first usage

=item worker: connecting

Worker handling a connection (if the worker stays in this state its likely
that the connection attempt failed and the worker is send back to the pool)

=item worker: connected

Connected to a client, waiting for a session to be started

=item worker: <User> (<Role>)

Connected to a client with active session as User/Role

=item workflow: id <id> (<state>)

Worker currently handling a workflow.

=item worker: wfc

Worker after finishing a request, back in the pool

=back
