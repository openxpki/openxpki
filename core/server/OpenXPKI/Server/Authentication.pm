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
use Data::Dumper;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

use OpenXPKI::Server::Authentication::Handle;

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

    my @realms = CTX('config')->get_keys('system.realms');

    foreach my $realm (@realms) {
        $self->__load_pki_realm ({
            PKI_REALM => $realm,
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

    my $config = CTX('config');
    my $restore_realm = CTX('session')->data->pki_realm;

    # Fake Session for Config!
    CTX('session')->data->pki_realm( $realm );

    my @handlers = $config->get_keys('auth.handler');
    foreach my $handler (@handlers) {
        $self->__load_handler ({
            HANDLER   => $handler
        });
    }

    my @stacks = $config->get_keys('auth.stack');
    foreach my $stack (@stacks) {

        $self->{PKI_REALM}->{$realm}->{STACK}->{$stack}->{DESCRIPTION} =
            $config->get("auth.stack.$stack.description");

        $self->{PKI_REALM}->{$realm}->{STACK}->{$stack}->{LABEL} =
            $config->get("auth.stack.$stack.label") || $stack;

        ##! 8: "determine all used handlers"
        my @supported_handler = $config->get_scalar_as_list("auth.stack.$stack.handler");
        ##! 32: " supported_handler " . Dumper @supported_handler
        $self->{PKI_REALM}->{$realm}->{STACK}->{$stack}->{HANDLER} = \@supported_handler;

    }

    ##! 64: "Realm auth config " . Dumper $self->{PKI_REALM}->{$realm}

    CTX('session')->data->pki_realm( $restore_realm ) if $restore_realm;
    ##! 4: "end"
    return 1;
}

sub __load_handler
{
    ##! 4: "start"
    my $self  = shift;
    my $keys  = shift;
    my $handler = $keys->{HANDLER};

    my $realm = CTX('session')->data->pki_realm;
    my $config = CTX('config');

    ##! 8: "load handler type"

    my $type = $config->get("auth.handler.$handler.type");
    $type =~ s/[^a-zA-Z0-9]//g;

    ##! 8: "name ::= $handler"
    ##! 8: "type ::= $type"
    my $class = "OpenXPKI::Server::Authentication::$type";
    eval "use $class;1";
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw (
            message => "Unable to load authentication handler class $type",
            params  => {ERRVAL => $EVAL_ERROR});
    }

    $self->{PKI_REALM}->{$realm}->{HANDLER}->{$handler} = $class->new( "auth.handler.$handler" );

    CTX('log')->auth()->info('Loaded auth handler ' . $handler);

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
    my $realm = CTX('session')->data->pki_realm;

    ##! 2: "get authentication stack"
    my %stacks = ();
    foreach my $stack (sort keys %{$self->{PKI_REALM}->{$realm}->{STACK}}) {
        $stacks{$stack}->{NAME}        = $stack;
        $stacks{$stack}->{DESCRIPTION} = $self->{PKI_REALM}->{$realm}->{STACK}->{$stack}->{DESCRIPTION};
        $stacks{$stack}->{LABEL} = $self->{PKI_REALM}->{$realm}->{STACK}->{$stack}->{LABEL};
    }
    ##! 1: 'end'
    return \%stacks;
}

sub get_stack_info {

    ##! 1: "start"

    my $self = shift;
    my $stack = shift;
    my $realm = CTX('session')->data->pki_realm;

    # no result at all usually means we even did not try to login
    # fetch the required "challenges" from the STACK! We use the fast
    # path via the config layer - FIXME - check if we should cache this

    my $auth_type = CTX('config')->get(['auth','stack', $stack, 'type']);
    my $auth_param;
    if (!$auth_type) {
        ##! 8: "legacy config found for $stack"
        # for legacy handler / configs we call the first handler
        # to determine the type from the given service message
        my $handler = $self->{PKI_REALM}->{$realm}->{STACK}->{$stack}->{HANDLER}->[0];
        my $handlerClass = $self->{PKI_REALM}->{$realm}->{HANDLER}->{$handler};
        if (!$handlerClass->isa('OpenXPKI::Server::Authentication::Base')) {
            my ($user, $role, $return_msg) = $handlerClass->login_step({
                HANDLER => $handler,
                MESSAGE => { PARAMS => {}},
            });
            $return_msg->{SERVICE_MSG} =~ /GET_(\w+)_LOGIN/;
            $auth_type = lc($1) || 'passwd';
        } else {
            $auth_type = 'passwd';
        }
    } else {
        $auth_param = CTX('config')->get_hash(['auth','stack', $stack, 'param']);
    }

    ##! 8: "Auth Type $auth_type"
    ##! 32: $auth_param
    # TODO - clean this up and return some more abstract info
    return (undef, undef, { SERVICE_MSG => 'GET_'.uc($auth_type).'_LOGIN', PARAMS => ($auth_param //= {}) });
}

sub __legacy_login {

    ##! 8: "start"

    my $self = shift;
    my $handlerClass = shift;
    my $handler = shift;
    my $msg = shift;

    my ($user, $role, $return_msg, $userinfo);
    eval {
        ($user, $role, $return_msg, $userinfo) = $handlerClass->login_step({
            HANDLER => $handler,
            MESSAGE => $msg,
        });
    };
    if ($EVAL_ERROR) {
        CTX('log')->auth()->debug("Login to $handler failed with error $EVAL_ERROR");
        return OpenXPKI::Server::Authentication::Handle->new(
            username => $msg->{PARAMS}->{LOGIN} || 'unknown',
            userid => ($user || $msg->{PARAMS}->{LOGIN} || 'unknown'),
            error => 128,
            error_message => "$EVAL_ERROR",
            handler => $handler,
        );
    }

    if ($user && $role) {
        return OpenXPKI::Server::Authentication::Handle->new(
            username => $user,
            userid => $user,
            role => $role,
            userinfo => $userinfo,
            handler => $handler,
            is_valid => 1,
        );
    }

    return;
}

sub login_step {

    ##! 1: "start"
    my $self    = shift;
    my $arg_ref = shift;

    my $msg     = $arg_ref->{MESSAGE};
    my $stack   = $arg_ref->{STACK};
    my $realm   = CTX('session')->data->pki_realm;

    ##! 16: 'realm: ' . $realm
    ##! 16: 'stack: ' . $stack
    ##! 64: $msg
    if (! exists $self->{PKI_REALM}->{$realm}->{STACK}->{$stack} ||
        ! scalar @{$self->{PKI_REALM}->{$realm}->{STACK}->{$stack}->{HANDLER}}) {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LOGIN_INVALID_STACK",
            params  => {
                STACK => $stack
            },
            log     => {
                priority => 'warn',
                facility => 'auth'
            },
        );
    }

    ##! 2: "try the different available handlers for the stack $stack"
    my $last_result;
  HANDLER:
    foreach my $handler (@{$self->{PKI_REALM}->{$realm}->{STACK}->{$stack}->{HANDLER}}) {
        ##! 4: "handler $handler from stack $stack"
        my $handlerClass = $self->{PKI_REALM}->{$realm}->{HANDLER}->{$handler};

        OpenXPKI::Exception->throw (
            message => "Invalid handler given for stack",
            params  => {
                PKI_REALM => $realm,
                HANDLER => $handler,
            },
            log => {
                priority => 'error',
                facility => 'auth',
            }
        ) unless (ref $handlerClass);

        # The more modern classes inherit from this base class
        # so we test for it to fetch legacy implementations
        my $auth_result;
        if ($handlerClass->isa('OpenXPKI::Server::Authentication::Base')) {
            ##! 16: 'New handler'
            # the new handlers should not throw errors
            $auth_result = $handlerClass->handleInput( $msg->{PARAMS} );
        } else {
            ##! 16: 'Legacy handler'
            # legacy stuff
            $auth_result = $self->__legacy_login( $handlerClass, $handler, $msg);
        }

        # store the result if we got a result
        if ($auth_result) {
            ##! 8: 'Got auth result'
            ##! 64: Dumper $auth_result
            $last_result = $auth_result;
            # abort processing if the login was valid
            last HANDLER if ($auth_result->is_valid());
        }
    }

    ##! 16: Dumper $last_result
    # no result at all usually means we even did not try to login
    # fetch the required "challenges" from the STACK! We use the fast
    # path via the config layer - FIXME - check if we should cache this
    return $self->get_stack_info($stack) unless ($last_result);

    # if we have a result but it is not valid we tried to log in but failed
    # we use the "old" exception pattern as we need to rework the error
    # handling first.....
    if (!$last_result->is_valid()) {
        OpenXPKI::Exception::Authentication->throw(
            message => 'Authentication failed',
            error => $last_result->error_message(),
            authinfo => $last_result->authinfo(),
            log => { facility => 'auth', priority => 'error' },
        );
    }

    CTX('log')->auth()->info(sprintf("Login successful (user: %s, role: %s)",
        $last_result->userid, $last_result->role));

    return (
        $last_result->userid,
        $last_result->role,
        { SERVICE_MSG => 'SERVICE_READY' },
        ($last_result->userinfo // {}),
        ($last_result->authinfo // {})
    );

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
