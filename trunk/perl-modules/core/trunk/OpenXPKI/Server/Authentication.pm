## OpenXPKI::Server::Authentication.pm 
##
## Written 2003 by Michael Bell
## Rewritten 2005 and 2006 by Michael Bell for the OpenXPKI project
## adapted to new Service::Default semantics 2007 by Alexander Klink
## for the OpenXPKI project
## (C) Copyright 2003-2007 by The OpenXPKI Project

package OpenXPKI::Server::Authentication;

use strict;
use warnings;
use utf8;

use English;
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

use OpenXPKI::Server::Authentication::Anonymous;
use OpenXPKI::Server::Authentication::External;
use OpenXPKI::Server::Authentication::LDAP;
use OpenXPKI::Server::Authentication::Password;
use OpenXPKI::Server::Authentication::X509;
use OpenXPKI::Server::Authentication::ClientSSO;
use OpenXPKI::Server::Authentication::ClientX509;

## constructor and destructor stuff

sub new {
    ##! 1: "start"
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    bless $self, $class;

    my $keys       = shift;

    $self->__load_config($keys);

    ##! 1: "end"
    return $self;
}

#############################################################################
##                         load the configuration                          ##
##                            (caching support)                            ##
#############################################################################

sub __load_config
{
    ##! 4: "start"
    my $self = shift;
    my $keys = shift;

    ##! 8: "load all PKI realms"

    my $realms = CTX('xml_config')->get_xpath_count(
        XPATH     => 'pki_realm',
        CONFIG_ID => $keys->{CONFIG_ID},
    );
    for (my $i=0; $i < $realms; $i++)
    {
        $self->__load_pki_realm ({
                PKI_REALM => $i,
                CONFIG_ID => $keys->{CONFIG_ID},
        });
    }

    ##! 4: "leaving function successfully"
    return 1;
}

sub __load_pki_realm
{
    ##! 4: "start"
    my $self   = shift;
    my $keys   = shift;
    my $realm  = $keys->{PKI_REALM};
    my $cfg_id = $keys->{CONFIG_ID};

    my $name = CTX('xml_config')->get_xpath (XPATH   => ['pki_realm', 'name'],
                                         COUNTER => [$realm, 0],
                                         CONFIG_ID => $cfg_id );
    $self->{PKI_REALM}->{$name}->{POS} = $realm;

    ##! 8: "load all handlers"

    my $handlers = CTX('xml_config')->get_xpath_count (XPATH   => ['pki_realm', 'auth', 'handler'],
                                                   COUNTER => [$realm, 0],
                                                   CONFIG_ID => $cfg_id);
    for (my $i=0; $i < $handlers; $i++)
    {
        $self->__load_handler ({
                PKI_REALM => $name,
                HANDLER   => $i,
                CONFIG_ID => $cfg_id,
        });
    }

    ##! 8: "determine all authentication stacks"

    my $stacks = CTX('xml_config')->get_xpath_count (XPATH   => ['pki_realm', 'auth', 'stack'],
                                                 COUNTER => [$realm, 0],
                                                 CONFIG_ID => $cfg_id);
    for (my $i=0; $i < $stacks; $i++)
    {
        $self->__load_stack ({
                PKI_REALM => $name,
                STACK     => $i,
                CONFIG_ID => $cfg_id,
        });
    }
    ##! 4: "end"
    return 1;
}

sub __load_stack
{
    ##! 4: "start"
    my $self  = shift;
    my $keys  = shift;
    my $realm     = $keys->{PKI_REALM};
    my $realm_pos = $self->{PKI_REALM}->{$realm}->{POS};
    my $stack_pos = $keys->{STACK};
    my $cfg_id    = $keys->{CONFIG_ID};

    ##! 8: "load stack name (this is what the user will see)"

    my $stack = CTX('xml_config')->get_xpath (XPATH   => ['pki_realm', 'auth', 'stack', 'name'],
                                              COUNTER => [$realm_pos, 0, $stack_pos, 0],
                                              CONFIG_ID => $cfg_id,
    );
    my $desc  = CTX('xml_config')->get_xpath (XPATH   => ['pki_realm', 'auth', 'stack', 'description'],
                                              COUNTER => [$realm_pos, 0, $stack_pos, 0],
                                              CONFIG_ID => $cfg_id,
    );

    ##! 8: "determine all used handlers"

    $self->{PKI_REALM}->{$realm}->{STACK}->{$stack}->{DESCRIPTION} = $desc;
    $self->{PKI_REALM}->{$realm}->{STACK}->{$stack}->{HANDLER} =
        CTX('xml_config')->get_xpath_list (XPATH   => ['pki_realm', 'auth', 'stack', 'handler'],
                                       COUNTER => [$realm_pos, 0, $stack_pos],
                                        CONFIG_ID => $cfg_id,
    );
    ##! 4: "end"
    return 1;
}

sub __load_handler
{
    ##! 4: "start"
    my $self  = shift;
    my $keys  = shift;
    my $realm       = $keys->{PKI_REALM};
    my $realm_pos   = $self->{PKI_REALM}->{$realm}->{POS};
    my $handler_pos = $keys->{HANDLER};
    my $cfg_id      = $keys->{CONFIG_ID};

    ##! 8: "load handler name and type"

    my $name = CTX('xml_config')->get_xpath (XPATH   => ['pki_realm', 'auth', 'handler', 'name'],
                                         COUNTER => [$realm_pos, 0, $handler_pos, 0],
                                        CONFIG_ID => $cfg_id);
    my $type = CTX('xml_config')->get_xpath (XPATH   => ['pki_realm', 'auth', 'handler', 'type'],
                                         COUNTER => [$realm_pos, 0, $handler_pos, 0],
                                        CONFIG_ID => $cfg_id);
    ##! 8: "name ::= $name"
    ##! 8: "type ::= $type"
    $type = "OpenXPKI::Server::Authentication::$type";
    $self->{PKI_REALM}->{$realm}->{HANDLER}->{$name} = eval {

        $type->new ({XPATH   => ['pki_realm', 'auth', 'handler'],
                     COUNTER => [$realm_pos, 0, $handler_pos],
                     CONFIG_ID => $cfg_id,
                   });

                                                           };
    if (my $exc = OpenXPKI::Exception->caught())
    {
        ##! 16: "exception from authentication sub module $type detected"
        OpenXPKI::Exception->throw (
            message  => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LOAD_HANDLER_FAILED",
            children => [ $exc ]);
    }
    elsif ($EVAL_ERROR)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LOAD_HANDLER_CRASHED",
            params  => {ERRVAL => $EVAL_ERROR->message()});
    }

    ##! 4: "end"
    return 1;
}

########################################################################
##                          identify the user                         ##
########################################################################

sub list_authentication_stacks {
    my $self = shift;

    ##! 1: "start"

    ##! 2: "get PKI realm"
    my $realm = CTX('session')->get_pki_realm();

    ##! 2: "get authentication stack"
    my %stacks = ();
    foreach my $stack (sort keys %{$self->{PKI_REALM}->{$realm}->{STACK}}) {
        $stacks{$stack}->{NAME}        = $stack;
        $stacks{$stack}->{DESCRIPTION} = $self->{PKI_REALM}->{$realm}->{STACK}->{$stack}->{DESCRIPTION};
    }
    ##! 1: 'end'
    return \%stacks;
}

sub login_step {
    my $self    = shift;
    my $arg_ref = shift;

    my $msg     = $arg_ref->{MESSAGE};
    my $stack   = $arg_ref->{STACK};
    my $realm   = CTX('session')->get_pki_realm();

    ##! 16: 'realm: ' . $realm
    ##! 16: 'stack: ' . $stack
    if (! exists $self->{PKI_REALM}->{$realm}->{STACK}->{$stack} ||
        ! scalar @{$self->{PKI_REALM}->{$realm}->{STACK}->{$stack}->{HANDLER}}) {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LOGIN_INVALID_STACK",
            params  => {
		STACK => $stack
	    },
	    log     => {
		logger => CTX('log'),
		priority => 'info',
		facility => 'auth',
	    },
        );
    }

    ##! 2: "try the different available handlers for the stack $stack"
    my $ok = 0;
    my $user;
    my $role;
    my $return_msg = {};
  HANDLER:
    foreach my $handler (@{$self->{PKI_REALM}->{$realm}->{STACK}->{$stack}->{HANDLER}}) {
        ##! 4: "handler $handler from stack $stack"
        my $ref = $self->{PKI_REALM}->{$realm}->{HANDLER}->{$handler};
        if (! ref $ref) { # note the great choice of variable name ...
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_INCORRECT_HANDLER",
                params  => {
		    PKI_REALM => $realm, 
		    HANDLER => $handler,
		},
		log => {
		    logger => CTX('log'),
		    priority => 'error',
		    facility => 'system',
		},
		);
        }
        eval {
            ($user, $role, $return_msg) = $ref->login_step({
                HANDLER => $handler,
                MESSAGE => $msg,
            });
        };
        if (! $EVAL_ERROR) {
            ##! 8: "login step ok"
            $ok = 1;

            ##! 8: "session configured"
            last HANDLER;
        } else {
            ##! 8: "EVAL_ERROR detected"
            ##! 64: '$EVAL_ERROR = ' . $EVAL_ERROR
        }
    }
    if (! $ok) {
        ##! 4: "show at minimum the last error message"
        if (my $exc = OpenXPKI::Exception->caught()) {
            OpenXPKI::Exception->throw (
                message  => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LOGIN_FAILED",
                children => [ $exc ],
		log => {
		    logger => CTX('log'),
		    priority => 'warn',
		    facility => 'auth',
		},
		);
        }
        else {
            OpenXPKI::Exception->throw (
                message  => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LOGIN_FAILED",
                children => [ $EVAL_ERROR->message() ],
		log => {
		    logger => CTX('log'),
		    priority => 'warn',
		    facility => 'auth',
		},
		);
        }
    }

    if (defined $user) {
	CTX('log')->log(
	    MESSAGE  => "Login successful using authentication stack '$stack' (user: '$user', role: '$role')",
	    PRIORITY => 'info',
	    FACILITY => 'auth',
	    );
    }

    return ($user, $role, $return_msg); 
};

1;
__END__

=head1 Name

OpenXPKI::Server::Authentication

=head1 Description

This module is the top class of OpenXPKI's authentication
framework. Every authentication method is implemented in an
extra class but you only have to init this class and then
you have to call login if you need an authentication. The
XMl configuration and session handling is done via the servers
global context.

=head1 Functions

=head2 new

is the constructor and accepts no parameters.
If you call new then the complete
configuration is loaded. This makes it possible to cash
this object and to use login when it is required in a very
fast way.

=head2 login_step

is the function which performs the authentication. 
Named parameters are STACK (the authentication stack to use)
and MESSAGE (the message received by the service).
It returns a triple (user, role, reply). The authentication
is not finished until user and role are defined. Multiple
calls can then be made until this state is achieved.
Reply is the reply message that is to be sent to the user
(i.e. a challenge, or the 'SERVICE_READY' message in case
the authentication has been successful).

=head1 See Also

OpenXPKI::Server::Authentication::Anonymous
OpenXPKI::Server::Authentication::External
OpenXPKI::Server::Authentication::LDAP
OpenXPKI::Server::Authentication::Password
OpenXPKI::Server::Authentication::X509
