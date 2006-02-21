## OpenXPKI::Server.pm 
##
## Written by Michael Bell for the OpenXPKI project 2005
## Copyright (C) 2005 by The OpenXPKI Project
## $Revision$

use strict;
use warnings;
use utf8;

package OpenXPKI::Server;
use base qw(Net::Server::Fork);

## used modules

use English;
use OpenXPKI qw(debug);
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::ACL;
use OpenXPKI::Server::API;

sub new
{
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {DEBUG => 0};

    bless $self, $class;

    my $keys = { @_ };

    ## get parameters

    $self->{"DEBUG"}          = $keys->{DEBUG};
    $self->{"CONFIG"}         = $keys->{CONFIG};

    ## dump out startup configuration

    foreach my $key (keys %{$keys})
    {
        if ($key ne "CONFIG" and $key ne "DEBUG")
        {
            $self->debug ("IGNORED:  $key ::= $keys->{$key}");
        } else {
            $self->debug ("ACCEPTED: $key ::= $keys->{$key}");
        }
    }

    ## initialization
    OpenXPKI::Server::Context::create(
	DEBUG  => $self->{DEBUG},
	CONFIG => $self->{CONFIG}
	);

    $self->__redirect_stderr();

    # attach this server object and the API to the global context
    # FIXME: move api initalization into Context package?
    # FIXME: the context must be initialized in to phase
    # FIXME:   1. minimum init with dbeug and config
    # FIXME:   2. major init with server, api and acl
    OpenXPKI::Server::Context::setcontext(
	server => $self,
        acl    => OpenXPKI::Server::ACL->new(),
	api    => OpenXPKI::Server::API->new(),
	);

    ## group access is allowed
    $self->{umask} = umask 0007;

    ## load the user interfaces
    $self->{ui_list} = $self->__get_user_interfaces();

    ## start the server

    my %params = $self->__get_server_config();
    unlink ($params{port});
    $self->run (%params);
}

sub process_request
{
    my $self = shift;

    my $log = CTX('log');

    ## recover from umask of Net::Server->run
    umask $self->{umask};

    my $line = readline (*STDIN);

    ## initialize user interface module

    my $class = $line;
    $class =~ s/^.* //s; ## filter something like START etc.
    $class =~ s/\n$//s;
    if (not $self->{ui_list}->{$class})
    {
        print STDOUT "OpenXPKI::Server: $class unsupported.\n";
        $log->log (MESSAGE  => "$class unsupported.",
		   PRIORITY => "fatal",
		   FACILITY => "system");
        return;
    }
    OpenXPKI::Server::Context::setcontext(
        'ui' => $self->{ui_list}->{$class});

    ## update pre-initialized variables

    eval { CTX('dbi_backend')->connect() };
    if ($EVAL_ERROR)
    {
        print STDOUT $EVAL_ERROR->message();
        $self->{log}->log (MESSAGE  => "Database connection failed. ".
                                       $EVAL_ERROR->message(),
                           PRIORITY => "fatal",
                           FACILITY => "system");
        return;
        
    }

    # FIXME: do we need to connect to the workflow database as well?

    ## use user interface

    CTX('ui')->init();
    CTX('ui')->run();
}

###########################################################################
# private methods

sub __redirect_stderr
{
    my $self = shift;
    $self->debug ("start");

    my $config = CTX('xml_config');

    my $stderr = $config->get_xpath (XPATH => "common/server/stderr");
    if (not $stderr)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_REDIRECT_STDERR_MISSING_STDERR");
    }
    $self->debug ("switching stderr to $stderr");
    if (not open STDERR, '>>', $stderr)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_REDIRECT_STDERR_FAILED");
    }
    binmode STDERR, ":utf8";
    return 1;
}


sub __get_user_interfaces
{
    my $self = shift;
    
    $self->debug ("start");
    
    my $config = CTX('xml_config');
    
    my $count = $config->get_xpath_count (XPATH => "common/server/interface");
    my %ui    = ();
    for (my $i=0; $i < $count; $i++)
    {
        ## load interface class
        my $class = $config->get_xpath (
	    XPATH   => "common/server/interface",
	    COUNTER => $i);
	$class = "OpenXPKI::UI::".$class;
        eval "use $class;";
        if ($EVAL_ERROR)
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_GET_USER_INTERFACE_USE_FAILED",
                params  => {EVAL_ERROR => $EVAL_ERROR,
                            MODULE     => $class});
        }
	
        ## initialize interface class
	# FIXME: should we pass in the API here?
        $ui{$class} = eval { $class->new () };
	#$ui{$class} = eval { $class->new (API => CTX('api')) };
	$EVAL_ERROR->rethrow() if ($EVAL_ERROR);
    }

    return \%ui;
}

sub __get_server_config
{
    my $self = shift;

    $self->debug ("start");

    my $config = CTX('xml_config');

    my %params = ();
    $params{proto}      = "unix";
    $params{background} = 1;
    $params{user}       = $config->get_xpath (XPATH => "common/server/user");
    $params{group}      = $config->get_xpath (XPATH => "common/server/group");
    $params{port}       = $config->get_xpath (XPATH => "common/server/socket_file")."|unix";
    $params{pid_file}   = $config->get_xpath (XPATH => "common/server/pid_file");

    ## check daemon user

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
        getgrgid ($params{"group"});

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
        $self->{authentication}->login({SESSION => CTX('session')});
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

=item * DEBUG

=back

All parameters are required, except of the DEBUG parameter.

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
