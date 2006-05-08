# OpenXPKI::Client::CLI
# Written 2006 by Michael Bell for the OpenXPKI project
# (C) Copyright 2006 by The OpenXPKI Project
# $Revision$

use strict;
use warnings;

package OpenXPKI::Client::CLI;

use English;
$OUTPUT_AUTOFLUSH = 1;

our $VERSION =  '$Revision: 1 $';
    $VERSION =~ s/\$Revision.*\s([0-9]+)$/$1/;

use OpenXPKI::Debug 'OpenXPKI::Client::CLI';

use Socket;
use OpenXPKI qw( read_file i18nGettext );
use OpenXPKI::Exception;
use OpenXPKI::Transport::Simple;
use OpenXPKI::Serialization::Simple;

sub new
{
    ##! 1: "start"
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    bless $self, $class;

    my $keys = shift;

    if (exists $keys->{SOCKETFILE}) {
	$self->{SOCKETFILE} = $keys->{SOCKETFILE};
    } else {
	##! 2: "check CONFIG parameter"
	if (not exists $keys->{CONFIG})
	{
	    OpenXPKI::Exception->throw
		(
		 message => "I18N_OPENXPKI_CLIENT_CLI_NEW_MISSING_CONFIG"
		);
	}
	
	##! 2: "load configuration"
	my $config = $self->read_file($keys->{CONFIG});
	
	##! 2: "parse configuration"
	$config =~ s/^.*<server_socket>(.*)<\/server_socket>.*$/$1/s;
	
	##! 2: "set socket filename to $config"
	$self->{SOCKETFILE} = $config;
    }

    ##! 1: "end"
    return $self;
}

#####################################
##     BEGIN OF INITIALIZATION     ##
#####################################

sub init
{
    ##! 1: "start"
    my $self = shift;

    ##! 2: "init protocol stack"
    $self->__init_connection();
    $self->__init_transport_protocol();
    $self->__init_serialization_protocol();
    $self->__init_service_protocol();

    ##! 2: "authentication"
    $self->__init_session();
    $self->{MESSAGE} = $self->{SERIALIZATION}->deserialize ($self->{TRANSPORT}->read());
    if ($self->{MESSAGE}->{SERVICE_MSG} eq "GET_PKI_REALM")
    {
        $self->__init_pki_realm();
        $self->{MESSAGE} = $self->{SERIALIZATION}->deserialize ($self->{TRANSPORT}->read());
    }
    if ($self->{MESSAGE}->{SERVICE_MSG} eq "GET_AUTHENTICATION_STACK")
    {
        $self->__init_user();
    }
    if ($self->{MESSAGE}->{SERVICE_MSG} ne "SERVICE_READY")
    {
        OpenXPKI::Exception->throw
        (
            message => "I18N_OPENXPKI_CLIENT_CLI_INIT_SERVICE_NOT_READY"
        );
    }

    ##! 1: "ready for run"
    return 1;
}

sub __init_connection
{
    ##! 4: "connect to socket"
    my $self = shift;

    if (not socket($self->{SOCKET}, PF_UNIX, SOCK_STREAM, 0))
    {
        OpenXPKI::Exception->throw
        (
            message => "I18N_OPENXPKI_CLIENT_CLI_INIT_CONNECTION_NO_SOCKET"
        );
    }
    if (not connect($self->{SOCKET}, sockaddr_un($self->{SOCKETFILE})))
    {
        OpenXPKI::Exception->throw
        (
            message => "I18N_OPENXPKI_CLIENT_CLI_INIT_CONNECTION_FAILED",
            params  => {SOCKETFILE => $self->{SOCKETFILE}}
        );
    }
    ##! 4: "end"
    return 1;
}

sub __init_transport_protocol
{
    ##! 4: "request simple transport protocol"
    my $self = shift;

    my $msg = "start Simple\n";
    ##! 8: "send requested protocol to server"
    ## print does not work perhaps because of connect?
    ## print {$self->{SOCKET}} $msg; ## send simple
    send ($self->{SOCKET},$msg,0); ## send simple
    ##! 8: "receive answer from server"
    read ($self->{SOCKET},$msg,3); ## read OK
    ##! 8: "evaluate answer"
    if ($msg ne "OK\n")
    {
        ##! 16: "transport protocol was not accepted by server - $msg"
        OpenXPKI::Exception->throw
        (
            message => "I18N_OPENXPKI_CLIENT_CLI_INIT_TRANSPORT_PROTOCOL_REJECTED",
        );
    }
    ##! 8: "intializing transport protocol"
    $self->{TRANSPORT} = OpenXPKI::Transport::Simple->new({SOCKET => $self->{SOCKET}});

    ##! 4: "end"
    return 1;
}

sub __init_serialization_protocol
{
    ##! 4: "request simple serialization protocol"
    my $self = shift;

    ##! 8: "send requested protocol to server"
    $self->{TRANSPORT}->write ("Simple"); ## send simple
    ##! 8: "receive answer from server"
    my $msg = $self->{TRANSPORT}->read ();   ## read OK
    ##! 8: "evaluate answer"
    if ($msg ne "OK")
    {
        OpenXPKI::Exception->throw
        (
            message => "I18N_OPENXPKI_CLIENT_CLI_INIT_SERIALIZATION_PROTOCOL_REJECTED",
        );
    }
    ##! 8: "intializing serialization protocol"
    $self->{SERIALIZATION} = OpenXPKI::Serialization::Simple->new();

    ##! 4: "end"
    return 1;
}

sub __init_service_protocol
{
    ##! 4: "request default service protocol"
    my $self = shift;
    
    $self->{TRANSPORT}->write ($self->{SERIALIZATION}->serialize("default"));
    my $msg = $self->{SERIALIZATION}->deserialize ($self->{TRANSPORT}->read());
    if ($msg ne "OK")
    {
        OpenXPKI::Exception->throw
        (
            message => "I18N_OPENXPKI_CLIENT_CLI_INIT_SERVICE_PROTOCOL_REJECTED",
        );
    }

    ##! 4: "end"
    return 1;
}

sub __init_session
{
    ##! 4: "create new session"
    my $self = shift;

    print STDOUT i18nGettext("I18N_OPENXPKI_CLIENT_CLI_ASK_FOR_NEW_SESSION")."\n";
    ##! 8: "here you must enter yes or a session ID"
    my $answer = readline (*STDIN);
    if ($answer =~ /yes/i)
    {
        ##! 8: "FIXME: we should send the preferred language here"
        $self->{TRANSPORT}->write ($self->{SERIALIZATION}->serialize({SERVICE_MSG => "NEW_SESSION"}));
    } else {
        $self->{TRANSPORT}->write ($self->{SERIALIZATION}->serialize({SERVICE_MSG => "CONTINUE_SESSION",
                                                                      SESSION_ID  => $answer}));
    }
    $self->{MESSAGE} = $self->{SERIALIZATION}->deserialize ($self->{TRANSPORT}->read());
    if (not exists $self->{MESSAGE}->{SESSION_ID})
    {
        OpenXPKI::Exception->throw
        (
            message => "I18N_OPENXPKI_CLIENT_CLI_INIT_SESSION_FAILED",
            params  => {ERROR => $self->{MESSAGE}->{ERROR}}
        );
    }
    $self->{SESSION_ID} = $self->{MESSAGE}->{SESSION_ID};
    print STDOUT i18nGettext("I18N_OPENXPKI_CLIENT_CLI_INIT_SESSION_NEW_ID")." ".$self->{SESSION_ID}."\n";
    ##! 8: "commit session ID"
    $self->{TRANSPORT}->write ($self->{SERIALIZATION}->serialize(
    {
        SERVICE_MSG => "SESSION_ID_ACCEPTED"
    }));

    ##! 4: "end"
    return 1;
}

sub __init_pki_realm
{
    ##! 4: "init pki realm"
    my $self = shift;

    ##! 8: "get_pki_realms"
    if (not exists $self->{MESSAGE}->{PKI_REALMS})
    {
        OpenXPKI::Exception->throw
        (
            message => "I18N_OPENXPKI_CLIENT_CLI_INIT_PKI_REALM_LIST_FAILED",
            params  => {ERROR => $self->{MESSAGE}->{ERROR}}
        );
    }
    my $loop = 0;
    my $loop_max = 100;
    while (not exists $self->{PKI_REALM})
    {
        if ($loop > $loop_max)
        {
            OpenXPKI::Exception->throw
            (
                message => "I18N_OPENXPKI_CLIENT_CLI_INIT_PKI_REALM_INFINITE_LOOP_DETECTED",
                params  => {MAXIMUM => $loop_max}
            );
        }
        eval {$self->__init_get_pki_realm({PKI_REALMS => $self->{MESSAGE}->{PKI_REALMS}});};
        $loop++;
    }

    ##! 8: "set_pki_realm"
    $self->{TRANSPORT}->write ($self->{SERIALIZATION}->serialize(
    {
        PKI_REALM => $self->{PKI_REALM}
    }));

    ##! 4: "end"
    return 1;
}

sub __init_get_pki_realm
{
    my $self = shift;
    my $keys = shift;
    ##! 8: "read the pki realm from the CLI"

    print STDOUT i18nGettext ("I18N_OPENXPKI_CLIENT_CLI_INIT_GET_PKI_REALM_MESSAGE")."\n";
    my @list  = ();
    my $i = 1;
    foreach my $realm (sort keys %{$keys->{PKI_REALMS}})
    {
        $list[$i] = $realm;
        print STDOUT "    ".$keys->{PKI_REALMS}->{$realm}->{NAME}." [$i]\n";
        for (my $i=0; $i < length($keys->{PKI_REALMS}->{$realm}->{DESCRIPTION}) / 56; $i++)
        {
            print STDOUT "        ".
                         substr($keys->{PKI_REALMS}->{$realm}->{DESCRIPTION},$i*56,56).
                         "\n";
        }
        $i++;
    }
    print STDOUT i18nGettext ("I18N_OPENXPKI_CLIENT_CLI_INIT_GET_PKI_REALM_ENTER_ID");
    my $id = readline (*STDIN);
       $id =~ s/\n$//s;
    if (not exists $list[$id])
    {
        print STDERR i18nGettext ("I18N_OPENXPKI_CLIENT_CLI_INIT_GET_PKI_REALM_WRONG_ID")."\n";
        OpenXPKI::Exception->throw
        (
            message => "I18N_OPENXPKI_CLIENT_CLI_INIT_GET_PKI_REALM_WRONG_ID",
        );
    }
    $self->{PKI_REALM} = $list[$id];

    ##! 8: "end"
    return $self->{PKI_REALM};
}

sub __init_user
{
    ##! 4: "init user"
    my $self = shift;

    ##! 8: "get_login_stack"
    if (not exists $self->{MESSAGE}->{AUTHENTICATION_STACKS})
    {
        OpenXPKI::Exception->throw
        (
            message => "I18N_OPENXPKI_CLIENT_CLI_INIT_USER_AUTH_LIST_FAILED",
            params  => {ERROR => $self->{MESSAGE}->{ERROR}}
        );
    }
    my $loop = 0;
    my $loop_max = 100;
    while (not $self->{AUTH_STACK})
    {
        if ($loop > $loop_max)
        {
            OpenXPKI::Exception->throw
            (
                message => "I18N_OPENXPKI_CLIENT_CLI_INIT_USER_INFINITE_LOOP_DETECTED",
                params  => {MAXIMUM => $loop_max}
            );
        }
        eval {$self->__init_get_auth_stack({AUTH_STACKS => $self->{MESSAGE}->{AUTHENTICATION_STACKS}});};
        $loop++;
    }

    ##! 8: "login via stack"
    $self->{TRANSPORT}->write ($self->{SERIALIZATION}->serialize(
    {
        SERVICE_MESSAGE      => "SET_AUTHENTICATION_STACK",
        AUTHENTICATION_STACK => $self->{AUTH_STACK}
    }));

    ##! 8: "login with passphrase or anonymous"
    $self->{MESSAGE} = $self->{SERIALIZATION}->deserialize ($self->{TRANSPORT}->read());
    if (not exists $self->{MESSAGE}->{SERVICE_MSG})
    {
        ##! 16: "we expect a service message and received something else"
        OpenXPKI::Exception->throw
        (
            message => "I18N_OPENXPKI_CLIENT_CLI_INIT_USER_UNEXPECTED_MESSAGE",
        );
    }
    elsif ($self->{MESSAGE}->{SERVICE_MSG} eq "GET_LOGIN_PASSWD")
    {
        ##! 16: "passwd_login requested"
        $self->__init_passwd_login();
    }
    elsif ($self->{MESSAGE}->{SERVICE_MSG} ne "SERVICE_READY")
    {
        ##! 16: "unknown service message - ".$self->{MESSAGE}->{SERVICE_MSG}
        OpenXPKI::Exception->throw
        (
            message => "I18N_OPENXPKI_CLIENT_CLI_INIT_USER_UNSUPPORTED_SERVICE_MSG",
            params  => {SERVICE_MSG => $self->{MESSAGE}->{SERVICE_MSG}}
        );
    }

    ##! 4: "end"
    return 1;
}

sub __init_get_auth_stack
{
    my $self = shift;
    my $keys = shift;
    ##! 8: "read the auth stacks from the CLI"

    print STDOUT i18nGettext ("I18N_OPENXPKI_CLIENT_CLI_INIT_GET_AUTH_STACK_MESSAGE")."\n";
    my @list  = ();
    my $i = 1;
    foreach my $stack (sort keys %{$keys->{AUTH_STACKS}})
    {
        $list[$i] = $stack;
        print "    ".$keys->{AUTH_STACKS}->{$stack}->{NAME}." [$i]\n";
        for (my $i=0; $i < length($keys->{AUTH_STACKS}->{$stack}->{DESCRIPTION}) / 56; $i++)
        {
            print STDOUT "        ".
                         substr($keys->{AUTH_STACKS}->{$stack}->{DESCRIPTION},$i*56,56).
                         "\n";
        }
        $i++;
    }
    print STDOUT i18nGettext ("I18N_OPENXPKI_CLIENT_CLI_INIT_AUTH_STACK_ENTER_ID");
    my $id = readline (*STDIN);
       $id =~ s/\n$//s;
    if (not exists $list[$id])
    {
        print STDERR i18nGettext ("I18N_OPENXPKI_CLIENT_CLI_INIT_AUTH_STACK_WRONG_ID")."\n";
        OpenXPKI::Exception->throw
        (
            message => "I18N_OPENXPKI_CLIENT_CLI_INIT_AUTH_STACK_WRONG_ID",
        );
    }
    $self->{AUTH_STACK} = $list[$id];

    ##! 8: "end"
    return $self->{AUTH_STACK};
}

sub __init_passwd_login
{
    my $self = shift;
    ##! 8: "login with login and passphrase"
    print STDOUT "Login: ";
    my $login = readline (*STDIN);
    print STDOUT "Password: ";
    my $passwd = readline (*STDIN);
    
    $self->{TRANSPORT}->write ($self->{SERIALIZATION}->serialize(
    {
        LOGIN  => $login,
        PASSWD => $passwd
    }));
    $self->{MESSAGE} = $self->{SERIALIZATION}->deserialize ($self->{TRANSPORT}->read());
    if (exists $self->{MESSAGE}->{ERROR})
    {
        OpenXPKI::Exception->throw
        (
            message => "I18N_OPENXPKI_CLIENT_CLI_INIT_PASSWD_LOGIN_FAILED",
            params  => {ERROR => $self->{MESSAGE}->{ERROR}}
        );
    }

    ##! 4: "end"
    return 1;
}

###################################
##     END OF INITIALIZATION     ##
###################################

sub run
{
    ##! 1: "entered command mode - client must send commands now"
    ##! 1: "first we have to detect the requested command mode"
}

sub run_shell
{
}

sub run_cli
{
}

sub DESTROY
{
    my $self = shift;

    ##! 2: "logout client and kill session"
    if (defined $self->{TRANSPORT} && defined $self->{SERIALIZATION}) {
	$self->{TRANSPORT}->write(
	    $self->{SERIALIZATION}->serialize(
		{
		    SERVICE_MSG => "LOGOUT",
		})
	    );
	print STDOUT i18nGettext('I18N_OPENXPKI_CLIENT_CLI_DESTROY_LOGOUT_SUCCESSFUL');
    }

    ##! 2: "session is now terminated"
    return 1;
}

1;
__END__
send (SOCK, $load, 0);
shutdown (SOCK, 1);
while (read (SOCK, $line, 1024))
{
    print $line;
}
close SOCK;
