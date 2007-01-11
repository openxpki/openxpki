## OpenXPKI::Server.pm 
##
## Written 2005 by Michael Bell for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project
## $Revision$
package OpenXPKI::Server;

use strict;
use warnings;
use utf8;

use base qw(Net::Server::Fork);

## used modules

use English;
use Socket;
use OpenXPKI::Debug 'OpenXPKI::Server';
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Init;

use Data::Dumper;

sub new
{
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    bless $self, $class;

    my $keys = { @_ };

    ## get parameters

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
    OpenXPKI::Server::Init::init(
	{
	    CONFIG => $self->{CONFIG},
	    TASKS  => [ 'xml_config', 'i18n', 'log' ],
            SILENT => $keys->{SILENT}
	});

    # from now on we can assume that we have CTX('log') available

    # perform the rest of the initialization
    eval
    {
	OpenXPKI::Server::Init::init(
	    {
		CONFIG => $self->{CONFIG},
		# FIXME: not needed?
#		SERVER => $self,
                SILENT => $keys->{SILENT}
	    });
    };
    if ($EVAL_ERROR) {
 	my $msg = exception_as_string($EVAL_ERROR);
 	CTX('log')->log(
 	    MESSAGE  => "Exception during server initialization: " . $msg,
 	    PRIORITY => "fatal",
 	    FACILITY => "system",
 	    );
 	# die gracefully
 	$ERRNO = 1;
        die $msg;
    }

    ## group access is allowed
    $self->{umask} = umask 0007;

    ## load the user interfaces
    eval
    {
	$self->__get_user_interfaces();
    };
    if ($EVAL_ERROR) {
 	my $msg = exception_as_string($EVAL_ERROR);
        ## FIXME: this error message does not reach the startup script and the log!
 	CTX('log')->log(
 	    MESSAGE  => "Exception during interface initialization: " . $msg,
 	    PRIORITY => "fatal",
 	    FACILITY => "system",
 	    );
 	# die gracefully
 	$ERRNO = 1;
        die $msg;
    }

    ## start the server
    eval
    {
	$self->{PARAMS} = $self->__get_server_config();
    };
    if ($EVAL_ERROR) {
 	my $msg = exception_as_string($EVAL_ERROR);
 	CTX('log')->log(
 	    MESSAGE  => "Exception during server daemon setup: " . $msg,
 	    PRIORITY => "fatal",
 	    FACILITY => "system",
 	    );
 	# die gracefully
 	$ERRNO = 1;
        die $msg;
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
    
    $self->run (%{$self->{PARAMS}});
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

    my $socket_owner = -1; # default: unchanged
    my $socket_group = -1; # default: unchanged

    if (defined $self->{PARAMS}->{socket_owner}) {
	$socket_owner = __get_numerical_user_id($self->{PARAMS}->{socket_owner});
	if (! defined $socket_owner) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_POST_BIND_HOOK_INCORRECT_SOCKET_OWNER",
		params  => {
		    SOCKET_OWNER => $self->{PARAMS}->{socket_owner},
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
		);
	}
    }

    if (($socket_owner != -1) || ($socket_group != -1)) {
	# try to change socket ownership
	if (! chown $socket_owner, $socket_group, $socketfile) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_POST_BIND_HOOK_COULD_NOT_CHANGE_SOCKET_OWNERSHIP",
		params  => {
		    SOCKETFILE => $socketfile,
		    SOCKET_OWNER => $socket_owner,
		    SOCKET_GROUP => $socket_group,
		},
		);
	}
    }
 
    return 1;
}


# called statically
sub exception_as_string {
    my $exc = shift;

    my $msg = "";
    ##! 8: ref $exc
    if (ref $exc eq '') {
        ##! 16: "no ref"
	$msg = $exc;
    } elsif (ref $exc eq 'OpenXPKI::Exception') {
        ##! 16: "OpenXPKI::Exception detected"
	$msg = $exc->full_message() || '<no message>';
        ##! 16: "do there be any children?"
	if ($exc->children()) {
            ##! 32: "has children"
            foreach my $child (@{$exc->children()})
            {
                ##! 64: "call exception_as_string"
	        $msg .= '; CHILD: [' . exception_as_string($child) . ']';
            }
	}
        ##! 16: "children finished"
    } elsif (ref $exc) {
        ##! 16: "other exception detected"
	$msg = $EVAL_ERROR->message();
    } else {
        ##! 16: "no exception detected"
	$msg = "<not an exception>";
    }
    ##! 4: "final message: $msg"
    return $msg;
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
	$msg = exception_as_string($EVAL_ERROR);
    } elsif ($EVAL_ERROR) {
	# non-OpenXPKI exception
 	$msg = exception_as_string($EVAL_ERROR);
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
        if (not read STDIN, $char, 1)
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
            $transport = OpenXPKI::Transport::Simple->new ();
            print STDOUT "OK\n";
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

    if ($msg =~ m{ \A (?:Simple|JSON) \z }xms) {
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
    CTX('service')->init();

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
        ## we have to force the reload of the modules to enable debugging
        ## openxpkictl already loads some transport stuff via OpenXPKI::Client
        ## whilst openxpkictl is not in debug mode
        ## do not use the module Symbol with the function delete_package here
        ## delete_package works too radical for reloading and results in a crash
        delete $INC{"OpenXPKI/Transport/$class.pm"} if (exists $INC{"OpenXPKI/Transport/$class.pm"});
	$class = "OpenXPKI::Transport::".$class;
        eval "use $class;";
        if ($EVAL_ERROR)
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_GET_USER_INTERFACE_TRANSPORT_FAILED",
                params  => {EVAL_ERROR => $EVAL_ERROR,
                            MODULE     => $class});
        }
    }

    ##! 2: "init serializers"

    $count = $config->get_xpath_count (XPATH => "common/server/serialization");
    for (my $i=0; $i < $count; $i++)
    {
        my $class = $config->get_xpath (
	    XPATH   => "common/server/serialization",
	    COUNTER => $i);
	$class = "OpenXPKI::Serialization::".$class;
        eval "use $class;";
        if ($EVAL_ERROR)
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_GET_USER_INTERFACE_SERIALIZATION_FAILED",
                params  => {EVAL_ERROR => $EVAL_ERROR,
                            MODULE     => $class});
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
                params  => {EVAL_ERROR => $EVAL_ERROR,
                            MODULE     => $class});
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
	    params  => {"SOCKETFILE" => $socketfile});
    }

    my %params = ();
    $params{socketfile} = $socketfile;
    $params{proto}      = "unix";
    $params{background} = 1;
    $params{user}       = $config->get_xpath (XPATH => "common/server/user");
    $params{group}      = $config->get_xpath (XPATH => "common/server/group");
    $params{port}       = $socketfile . '|unix';
    $params{pid_file}   = $config->get_xpath (XPATH => "common/server/pid_file");
    
    ## check daemon user

    foreach my $param (qw( user group port pid_file )) {
	if (! defined $params{$param} || $params{$param} eq "") {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_CONFIG_MISSING_PARAMETER",
		params  => {"PARAMETER" => $param});
	}
    }

    my $user  = __get_numerical_user_id($params{user});
    if (! defined $user || ($user eq ''))
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_CONFIG_INCORRECT_USER",
            params  => {"USER" => $params{"user"}});
    }
    # convert user id to numerical
    $params{user} = __get_numerical_user_id($user);


    my $group = __get_numerical_group_id($params{group});
    if (! defined $group || ($group eq ""))
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_CONFIG_INCORRECT_DAEMON_GROUP",
            params  => {"GROUP" => $params{"group"}});
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
		params  => {"SOCKET_OWNER" => $socket_owner});
	}
	$params{socket_owner} = $socket_owner;	
    }

    eval {
	# convert group id to numerical
	$params{socket_group} = __get_numerical_user_id($socket_group);

	if (! defined $params{socket_group} || ($params{socket_group} eq ''))
	{
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_CONFIG_INCORRECT_SOCKET_OWNER_GROUP",
		params  => {"SOCKET_GROUP" => $socket_group});
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
