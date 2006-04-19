## OpenXPKI::Server.pm 
##
## Written 2005 by Michael Bell for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project
## $Revision$

use strict;
use warnings;
use utf8;

package OpenXPKI::Server;
use base qw(Net::Server::Fork);

## used modules

use English;
use OpenXPKI::Debug 'OpenXPKI::Server';
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Init;

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
        if ($key ne "CONFIG")
        {
            ##! 8: "IGNORED:  $key ::= $keys->{$key}"
        } else {
            ##! 8: "ACCEPTED: $key ::= $keys->{$key}"
        }
    }

    ## initialization
    OpenXPKI::Server::Init->new({
        CONFIG => $self->{CONFIG},
        SERVER => $self
    });

    ## group access is allowed
    $self->{umask} = umask 0007;

    ## load the user interfaces
    $self->__get_user_interfaces();

    ## start the server

    my %params = $self->__get_server_config();
    unlink ($params{port});
    $self->run (%params);
}

sub process_request
{
    print STDERR "Do you know what's going on?\n";
    ##! 2: "start"
    my $self = shift;

    my $log = CTX('log');

    ## recover from umask of Net::Server->run
    umask $self->{umask};

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
        if ($line eq "start simple\n")
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
    if ($msg eq "simple")
    {
        $serializer = OpenXPKI::Serialization::Simple->new ();
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
    if ($data eq "default")
    {
        OpenXPKI::Server::Context::setcontext
        ({
            "service" => OpenXPKI::Service::Default->new
                         ({
                             TRANSPORT     => $transport,
                             SERIALIZATION => $serializer
                         })
        });
        $transport->write ($serializer->serialize ("OK"));
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

    eval { CTX('dbi_backend')->connect() };
    if ($EVAL_ERROR)
    {
        $transport->write ($serializer->serialize ($EVAL_ERROR->message()));
        $self->{log}->log (MESSAGE  => "Database connection failed. ".
                                       $EVAL_ERROR->message(),
                           PRIORITY => "fatal",
                           FACILITY => "system");
        return;
        
    }

    # FIXME: do we need to connect to the workflow database as well?

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

    ## init transport protocols

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
                params  => {EVAL_ERROR => $EVAL_ERROR,
                            MODULE     => $class});
        }
    }

    ## init serializers

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

    ## init services

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
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_GET_USER_INTERFACE_SERVICE_FAILED",
                params  => {EVAL_ERROR => $EVAL_ERROR,
                            MODULE     => $class});
        }
    }

    return 1;
}

sub __get_server_config
{
    my $self = shift;

    ##! 1: "start"

    my $config = CTX('xml_config');

    my %params = ();
    $params{proto}      = "unix";
    $params{background} = 1;
    $params{user}       = $config->get_xpath (XPATH => "common/server/user");
    $params{group}      = $config->get_xpath (XPATH => "common/server/group");
    $params{port}       = $config->get_xpath (XPATH => "common/server/socket_file")."|unix";
    $params{pid_file}   = $config->get_xpath (XPATH => "common/server/pid_file");

    ## check daemon user

    foreach my $param (qw( user group port pid_file )) {
	if (! defined $params{$param} || $params{$param} eq "") {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_CONFIG_MISSING_PARAMETER",
		params  => {"PARAMETER" => $param});
	}
    }

    my ($pw_name,$pw_passwd,$pw_uid,$pw_gid,
        $pw_quota,$pw_comment,$pw_gcos,$pw_dir,$pw_shell,$pw_expire) =
        getpwnam ($params{"user"});

    ($pw_name,$pw_passwd,$pw_uid,$pw_gid,
     $pw_quota,$pw_comment,$pw_gcos,$pw_dir,$pw_shell,$pw_expire) =
	 getpwuid ($params{"user"}) if (not $pw_uid);

    if (! defined $pw_name || ($pw_name eq ""))
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_CONFIG_INCORRECT_USER",
            params  => {"USER" => $params{"user"}});
    }

    ## check daemon group

    my ($gr_name,$gr_passwd,$gr_gid,$gr_members) =
        getgrnam ($params{"group"});

    ($gr_name,$gr_passwd,$gr_gid,$gr_members) =
        getgrgid ($params{"group"}) if (! $gr_name);

    if (! defined $gr_name || ($gr_name eq ""))
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_CONFIG_INCORRECT_DAEMON_GROUP",
            params  => {"GROUP" => $params{"group"}});
    }

    return %params;
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
based server with Net::Server::Fork. It returns a hash which can be
directly passed to the module. 
