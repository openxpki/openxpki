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

use Data::Dumper;

our $stop_soon = 0;

sub new
{
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    bless $self, $class;

    my $keys = { @_ };

    ## get parameters

    $self->{TYPE} = $keys->{TYPE};
    if (! defined $self->{TYPE}) {
        # a forking server is the standard one
        $self->{TYPE} = 'Fork';
    }
    $self->{"CONFIG"} = $keys->{CONFIG};

    ## dump out startup configuration

    foreach my $key (keys %{$keys})
    {
        if ($key ne "CONFIG" and $key ne "SILENT")
        {
            ##! 8: "IGNORED:  $key ::= $keys->{$key}"
        } else {
            ##! 8: "ACCEPTED: $key ::= $keys->{$key}"
        }
    }

    # we need to get a usable logger as soon as possible, hence:
    # initialize configuration, i18n and log
    OpenXPKI::Server::Init::init({
	    CONFIG => $self->{CONFIG},
	    TASKS  => [ 'current_xml_config', 'i18n', 'log' ],
        SILENT => $keys->{SILENT},
	});

    # from now on we can assume that we have CTX('log') available

    # perform the rest of the initialization
    eval
    {
	    OpenXPKI::Server::Init::init(
	    {
		    CONFIG => $self->{CONFIG},
            SILENT => $keys->{SILENT}
	    });
    };
    if ($EVAL_ERROR) {
        $self->__log_and_die($EVAL_ERROR, 'server initialization');
    }

    ## group access is allowed
    $self->{umask} = umask 0007;

    ## load the user interfaces
    eval
    {
	    $self->__get_user_interfaces();
    };
    if ($EVAL_ERROR) {
        $self->__log_and_die($EVAL_ERROR, 'interface initialization');
    }

    ## start the server
    eval
    {
	    $self->{PARAMS} = $self->__get_server_config();
    };
    if ($EVAL_ERROR) {
        $self->__log_and_die($EVAL_ERROR, 'server daemon setup');
    }

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
    CTX('log')->log(
	    MESSAGE  => "Server initialization completed",
	    PRIORITY => "info",
	    FACILITY => "system",
	);
    
    # clean up process list
    $0 = "openxpkid -c $self->{CONFIG}";
    
    CTX('dbi_workflow')->disconnect();
    CTX('dbi_backend')->disconnect();
    CTX('dbi_log')->disconnect();
    
    $self->{PARAMS}->{no_client_stdout} = 1;

    CTX('log')->log(
	    MESSAGE  => "Server is running",
	    PRIORITY => "info",
	    FACILITY => "monitor",
	);
    $self->run(%{$self->{PARAMS}});
}

sub pre_server_close_hook {
    ##! 1: 'start'
    my $self = shift;

    # remove pid and socketfile on destruction - they are no longer useful
    # if the server is not running ...
    unlink ($self->{PARAMS}->{socketfile});
    ##! 4: 'socketfile removed'
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
    my $socket_owner = $self->{PARAMS}->{process_owner};
    my $socket_group = $self->{PARAMS}->{process_group};

    # ... but can be overwritten in the config file
    if (defined $self->{PARAMS}->{socket_owner}) {
        $socket_owner = __get_numerical_user_id($self->{PARAMS}->{socket_owner});
        if (! defined $socket_owner) {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_POST_BIND_HOOK_INCORRECT_SOCKET_OWNER",
                params  => {
                    SOCKET_OWNER => $self->{PARAMS}->{socket_owner},
                },
		log => {
		    logger => CTX('log'),
		    message => "Incorrect socket owner '$self->{PARAMS}->{socket_owner}'",
		    facility => 'system',
		    priority => 'fatal',
		},
            );
        }
    }
    
    if (defined $self->{PARAMS}->{socket_group}) {
        $socket_group = __get_numerical_group_id($self->{PARAMS}->{socket_group});
        if (! defined $socket_group) {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_POST_BIND_HOOK_INCORRECT_SOCKET_GROUP",
                params  => {
                    SOCKET_GROUP => $self->{PARAMS}->{socket_group},
                },
		log => {
		    logger => CTX('log'),
		    message => "Incorrect socket group '$self->{PARAMS}->{socket_group}'",
		    facility => 'system',
		    priority => 'fatal',
		},
            );
        }
    }

    if (($socket_owner != -1) || ($socket_group != -1)) {
        # try to change socket ownership
        CTX('log')->log(
            MESSAGE  => "Setting socket file '$socketfile' ownership to "
            . (( $socket_owner != -1) ? $socket_owner : 'unchanged' )
            . '/'
            . (( $socket_group != -1) ? $socket_group : 'unchanged' ),
            PRIORITY => "debug",
            FACILITY => "system",
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
		    logger => CTX('log'),
		    message => "Could not change ownership for socket '$socketfile' to '$socket_owner:$socket_group'",
		    facility => 'system',
		    priority => 'fatal',
		},
            );
        }
    }

    my $environment_count = 0;
    eval {
        $environment_count = CTX('xml_config')->get_xpath_count(
            XPATH => 'common/server/environment',
        );
    };
    ##! 16: 'environment count: ' . $environment_count
    for (my $i = 0; $i < $environment_count; $i++) {
        my $var = CTX('xml_config')->get_xpath(
            XPATH   => [ 'common', 'server', 'environment', 'variable' ],
            COUNTER => [ 0       , 0       , $i           , 0          ],
        );
        my $value = CTX('xml_config')->get_xpath(
            XPATH   => [ 'common', 'server', 'environment', 'value' ],
            COUNTER => [ 0       , 0       , $i           , 0       ],
        );
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
        if( $self->{PARAMS}->{process_group} ne $) ){
            $self->log(
                2,
                "Setting gid to \"$self->{PARAMS}->{process_group}\""
            );
            CTX('log')->log(
                MESSAGE  => "Setting gid to to " 
                            . $self->{PARAMS}->{process_group},
                PRIORITY => "debug",
                FACILITY => "system",
            );
            set_gid( $self->{PARAMS}->{process_group} );
        }
        if( $self->{PARAMS}->{process_owner} ne $> ){
            $self->log(
                2,
                "Setting uid to \"$self->{PARAMS}->{process_owner}\""
            );
            CTX('log')->log(
                MESSAGE  => "Setting uid to to " 
                    . $self->{PARAMS}->{process_owner},
                PRIORITY => "debug",
                FACILITY => "system",
            );
            set_uid( $self->{PARAMS}->{process_owner} );
        }
    };
    if( $EVAL_ERROR ){
        if ( $> == 0 ) {
            CTX('log')->log(
                MESSAGE  => $EVAL_ERROR,
                PRIORITY => "fatal",
                FACILITY => "system",
            );
        die $EVAL_ERROR;
        } elsif( $< == 0) {
            CTX('log')->log(
                MESSAGE  => "Effective UID changed, but Real UID is 0: $EVAL_ERROR",
                PRIORITY => "warn",
                FACILITY => "system",
            );
        } else {
            CTX('log')->log(
                MESSAGE  => $EVAL_ERROR,
                PRIORITY => "error",
                FACILITY => "system",
            );
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
    ##! 1: 'end'
}

sub process_request {
    my $rc;
    my $msg;

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
        CTX('log')->log(
            MESSAGE  => "Uncaught exception: " . $msg,
            PRIORITY => "fatal",
            FACILITY => "system",
        );
        # die gracefully
        ##! 1: "Uncaught exception: " . Dumper $msg
        $ERRNO = 1;

        return;
    }

    return $rc;
}


sub do_process_request
{
    ##! 2: "start"
    my $self = shift;

    eval { 
        CTX('dbi_log')->new_dbh();
	    CTX('dbi_log')->connect();
    };
    if ($EVAL_ERROR)
    {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_COULD_NOT_RECONNECT_DBI_LOG',
            params  => {
                ERROR => $EVAL_ERROR,
            },
        );
        return;
    }
    ##! 16: 'dbi_log reconnected with new dbh'

    my $log = CTX('log');

    ## recover from umask of Net::Server->run
    umask $self->{umask};

    # masquerade process...
    $0 = 'openxpkid: idle';

    ##! 2: "transport protocol detector"
    my $transport = undef;
    my $line      = "";
    while (not $transport)
    {
        my $char;
        if (! read($self->{server}->{client}, $char, 1))
        {
            print STDOUT "OpenXPKI::Server: Connection closed unexpectly.\n";
            $log->log (MESSAGE  => "Connection closed unexpectly.",
	               PRIORITY => "fatal",
                       FACILITY => "system");
            return;
        }
        $line .= $char;
        ## protocol detection
        if ($line eq "start Simple\n")
        {
            $transport = OpenXPKI::Transport::Simple->new ({
                SOCKET => $self->{server}->{client},
            });
            send($self->{server}->{client}, "OK\n", 0);
        }
        elsif ($char eq "\n")
        {
            print STDOUT "OpenXPKI::Server: Unsupported protocol.\n";
            $log->log (MESSAGE  => "Unsupported protocol.",
	               PRIORITY => "fatal",
                       FACILITY => "system");
            return;
        }
    }

    ##! 2: "serialization protocol detector"
    my $serializer = undef;
    my $msg = $transport->read();

    if ($msg =~ m{ \A (?:Simple|JSON|Fast) \z }xms) {
	eval "\$serializer = OpenXPKI::Serialization::$msg->new();";

	if (! defined $serializer) {
            $transport->write ("OpenXPKI::Server: Serializer failed to initialize.\n");
            $log->log (MESSAGE  => "Serializer '$msg' failed to initialize.",
	               PRIORITY => "fatal",
                       FACILITY => "system");
            return;
	}
        $transport->write ("OK");

    }
    else
    {
            $transport->write ("OpenXPKI::Server: Unsupported serializer.\n");
            $log->log (MESSAGE  => "Unsupported serializer.",
	               PRIORITY => "fatal",
                       FACILITY => "system");
            return;
    }

    ##! 2: "service detector"
    my $data = $serializer->deserialize ($transport->read());
    if ($data eq "Default")
    {
        OpenXPKI::Server::Context::setcontext
        ({
            "service" => OpenXPKI::Service::Default->new
                         ({
                             TRANSPORT     => $transport,
                             SERIALIZATION => $serializer,
                         })
        });
        $transport->write ($serializer->serialize ("OK"));
    }
    elsif ($data eq 'SCEP')
    {
        OpenXPKI::Server::Context::setcontext
        ({
            "service" => OpenXPKI::Service::SCEP->new
                         ({
                            TRANSPORT     => $transport,
                            SERIALIZATION => $serializer,
                         })
        });
        $transport->write($serializer->serialize('OK'));
    }
    else
    {
        $transport->write ($serializer->serialize ("OpenXPKI::Server: Unsupported service.\n"));
        $log->log (MESSAGE  => "Unsupported service.",
                   PRIORITY => "fatal",
                   FACILITY => "system");
        return;
    }

    ##! 2: "update pre-initialized variables"

    eval { 
        CTX('dbi_backend')->new_dbh();
	    CTX('dbi_backend')->connect();
    };
    if ($EVAL_ERROR)
    {
        $transport->write ($serializer->serialize ($EVAL_ERROR->message()));
        $log->log (MESSAGE  => "Database connection failed. ".$EVAL_ERROR,
                   PRIORITY => "fatal",
                   FACILITY => "system");
        return;
        
    }
    ##! 16: 'dbi_backend reconnected with new dbh'

    eval { 
        CTX('dbi_workflow')->new_dbh();
	    CTX('dbi_workflow')->connect();
    };
    if ($EVAL_ERROR)
    {
        $transport->write ($serializer->serialize ($EVAL_ERROR->message()));
        $log->log (MESSAGE  => "Database connection failed. ".
                                       $EVAL_ERROR->message(),
                           PRIORITY => "fatal",
                           FACILITY => "system");
        return;
        
    }
    ##! 16: 'dbi_workflow reconnected with new dbh'

    # this is run until the user has logged in successfully
    CTX('service')->init();

    CTX('crypto_layer')->reload_all_secret_groups_from_cache();

    ##! 16: 'secret groups reloaded from cache'
    
    # masquerade process
    my $user = '';
    my $role = '';
    eval {
	    $user = CTX('session')->get_user();
    };
    eval {
	    $role = '(' . CTX('session')->get_role() . ')';
    };
    $0 = 'openxpkid: ' . $user . $role;

    ## use user interface
    CTX('service')->run();
}

###########################################################################
# private methods

sub __get_user_interfaces
{
    my $self = shift;
    
    ##! 1: "start"
    
    my $config = CTX('xml_config');

    ##! 2: "init transport protocols"

    my $count = $config->get_xpath_count (XPATH => "common/server/transport");
    for (my $i=0; $i < $count; $i++)
    {
        my $class = $config->get_xpath (
	    XPATH   => "common/server/transport",
	    COUNTER => $i);
	$class = "OpenXPKI::Transport::".$class;
        eval "use $class;";
        if ($EVAL_ERROR)
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_GET_USER_INTERFACE_TRANSPORT_FAILED",
                params  => {
		    EVAL_ERROR => $EVAL_ERROR,
		    MODULE     => $class
		},
		log => {
		    logger => CTX('log'),
		    message => "Could not initialize configured transport layer '$class': $EVAL_ERROR",
		    facility => 'system',
		    priority => 'fatal',
		},
		);
        }
    }

    ##! 2: "init services"

    $count = $config->get_xpath_count (XPATH => "common/server/service");
    for (my $i=0; $i < $count; $i++)
    {
        my $class = $config->get_xpath (
	    XPATH   => "common/server/service",
	    COUNTER => $i);
	$class = "OpenXPKI::Service::".$class;
        eval "use $class;";
        if ($EVAL_ERROR)
        {
            ##! 8: "use $class failed"
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_GET_USER_INTERFACE_SERVICE_FAILED",
                params  => {
		    EVAL_ERROR => $EVAL_ERROR,
		    MODULE     => $class
		},
		log => {
		    logger => CTX('log'),
		    message => "Could not initialize configured service layer '$class': $EVAL_ERROR",
		    facility => 'system',
		    priority => 'fatal',
		},
		);
        }
    }

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


sub __get_server_config
{
    my $self = shift;

    ##! 1: "start"

    my $config = CTX('xml_config');

    my $socketfile = $config->get_xpath (XPATH => "common/server/socket_file");

    # check if socket filename is too long
    if (unpack_sockaddr_un(pack_sockaddr_un($socketfile)) ne $socketfile) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVER_CONFIG_SOCKETFILE_TOO_LONG",
	    params  => {
		"SOCKETFILE" => $socketfile
	    },
	    log => {
		logger => CTX('log'),
		message => "Socket file '$socketfile' path length exceeds system limits",
		facility => 'system',
		priority => 'fatal',
	    },
	    );
    }

    my %params = ();
    $params{socketfile} = $socketfile;
    $params{proto}      = "unix";
    if ($self->{TYPE} eq 'Simple') {
        $params{server_type} = 'Simple';
    }
    elsif ($self->{TYPE} eq 'Fork') {
        $params{server_type} = 'Fork'; # TODO - try to make it possible to use PreFork
        $params{background}  = 1;
    }
    else {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER__GET_SERVER_CONFIG_UNKNOWN_SERVER_TYPE',
            params  => {
                TYPE => $self->{TYPE},
            },
	    log => {
		logger => CTX('log'),
		message => "Unknown Net::Server type '$self->{TYPE}'",
		facility => 'system',
		priority => 'fatal',
	    },
        );
    }
    $params{user}       = $config->get_xpath (XPATH => "common/server/user");
    $params{group}      = $config->get_xpath (XPATH => "common/server/group");
    $params{port}       = $socketfile . '|unix';
    $params{pid_file}   = $config->get_xpath (XPATH => "common/server/pid_file");
    
    ## check daemon user

    foreach my $param (qw( user group port pid_file )) {
	if (! defined $params{$param} || $params{$param} eq "") {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_CONFIG_MISSING_PARAMETER",
		params  => {
		    "PARAMETER" => $param,
		},
		log => {
		    logger => CTX('log'),
		    message => "Missing server configuration parameter '$param'",
		    facility => 'system',
		    priority => 'fatal',
		},
		);
	}
    }

    my $user  = __get_numerical_user_id($params{user});
    if (! defined $user || ($user eq ''))
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_CONFIG_INCORRECT_USER",
            params  => {
		"USER" => $params{"user"},
	    },
	    log => {
		logger => CTX('log'),
		message => "Incorrect system user '$params{user}'",
		facility => 'system',
		priority => 'fatal',
	    },
	    );
    }
    # convert user id to numerical
    $params{user} = __get_numerical_user_id($user);


    my $group = __get_numerical_group_id($params{group});
    if (! defined $group || ($group eq ""))
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_CONFIG_INCORRECT_DAEMON_GROUP",
            params  => {
		"GROUP" => $params{"group"},
	    },
	    log => {
		logger => CTX('log'),
		message => "Incorrect system group '$params{group}'",
		facility => 'system',
		priority => 'fatal',
	    },
	    );
    }
    # convert group id to numerical
    $params{group} = __get_numerical_group_id($group);

    # check if we have different ownership settings for the socket

    my $socket_owner;
    my $socket_group;

    eval {
	$socket_owner = $config->get_xpath (XPATH => "common/server/socket_owner");
    };

    if (defined $socket_owner) {
	# convert user id to numerical
	$params{socket_owner} = __get_numerical_user_id($socket_owner);

	if (! defined $params{socket_owner} || ($params{socket_owner} eq ''))
	{
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_CONFIG_INCORRECT_SOCKET_OWNER",
		params  => {
		    "SOCKET_OWNER" => $socket_owner,
		},
		log => {
		    logger => CTX('log'),
		    message => "Incorrect socket owner '$socket_owner'",
		    facility => 'system',
		    priority => 'fatal',
		},
		);
	}
	$params{socket_owner} = $socket_owner;	
    }

    eval {
	$socket_group = $config->get_xpath (XPATH => "common/server/socket_group");
    };

    if (defined $socket_group) {
	# convert group id to numerical
	$params{socket_group} = __get_numerical_group_id($socket_group);

	if (! defined $params{socket_group} || ($params{socket_group} eq ''))
	{
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_CONFIG_INCORRECT_SOCKET_OWNER_GROUP",
		params  => {
		    "SOCKET_GROUP" => $socket_group,
		},
		log => {
		    logger => CTX('log'),
		    message => "Incorrect socket group '$socket_group'",
		    facility => 'system',
		    priority => 'fatal',
		},
		);
	}
	$params{socket_group} = $socket_group;	
    };

    return \%params;
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
        my $msg = $error->full_message();
        $log_message = "Exception during $when: $msg";
    }
    else {
        ##! 16: 'error is something else'
        $log_message = "Eval error during $when: $error";
    }
    ##! 16: 'log_message: ' . $log_message

    CTX('log')->log(
        MESSAGE  => $log_message,
        PRIORITY => "fatal",
        FACILITY => "system",
    );

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

    if (not CTX('session')->is_valid())
    {
        CTX('authentication')->login();
    }
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

does the actual work of process_request: it reconnects dbi_log,
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

=head3 __get_user_interfaces

Returns a hash reference with the supported user interfaces. The value
of each hash element is an instance of the user interface class.

=head3 __get_server_config

Prepares the complete server configuration to startup a socket
based server with Net::Server::Fork. It returns a hashref.
