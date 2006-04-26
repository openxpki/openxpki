## OpenXPKI::Server::Authentication.pm 
##
## Written 2003 by Michael Bell
## Rewritten 2005 and 2006 by Michael Bell for the OpenXPKI project
## (C) Copyright 2003-2006 by The OpenXPKI Project
## $Revision$

use strict;
use warnings;
use utf8;

package OpenXPKI::Server::Authentication;

use English;
use OpenXPKI::Debug 'OpenXPKI::Server::Authentication';
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

use OpenXPKI::Server::Authentication::Anonymous;
use OpenXPKI::Server::Authentication::External;
use OpenXPKI::Server::Authentication::LDAP;
use OpenXPKI::Server::Authentication::Password;
use OpenXPKI::Server::Authentication::X509;

## constructor and destructor stuff

sub new {
    ##! 1: "start"
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    bless $self, $class;

    my $keys       = shift;

    $self->__load_config();

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

    ##! 8: "load all PKI realms"

    my $realms = CTX('xml_config')->get_xpath_count (XPATH => 'pki_realm');
    for (my $i=0; $i < $realms; $i++)
    {
        $self->__load_pki_realm ({PKI_REALM => $i});
    }

    ##! 4: "leaving function successfully"
    return 1;
}

sub __load_pki_realm
{
    ##! 4: "start"
    my $self  = shift;
    my $keys  = shift;
    my $realm = $keys->{PKI_REALM};

    my $name = CTX('xml_config')->get_xpath (XPATH   => ['pki_realm', 'name'],
                                         COUNTER => [$realm, 0]);
    $self->{PKI_REALM}->{$name}->{POS} = $realm;

    ##! 8: "load all handlers"

    my $handlers = CTX('xml_config')->get_xpath_count (XPATH   => ['pki_realm', 'auth', 'handler'],
                                                   COUNTER => [$realm, 0]);
    for (my $i=0; $i < $handlers; $i++)
    {
        $self->__load_handler ({PKI_REALM => $name, HANDLER => $i});
    }

    ##! 8: "determine all authentication stacks"

    my $stacks = CTX('xml_config')->get_xpath_count (XPATH   => ['pki_realm', 'auth', 'stack'],
                                                 COUNTER => [$realm, 0]);
    for (my $i=0; $i < $stacks; $i++)
    {
        $self->__load_stack ({PKI_REALM => $name, STACK => $i});
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

    ##! 8: "load stack name (this is what the user will see)"

    my $stack = CTX('xml_config')->get_xpath (XPATH   => ['pki_realm', 'auth', 'stack', 'name'],
                                              COUNTER => [$realm_pos, 0, $stack_pos, 0]);
    my $desc  = CTX('xml_config')->get_xpath (XPATH   => ['pki_realm', 'auth', 'stack', 'description'],
                                              COUNTER => [$realm_pos, 0, $stack_pos, 0]);

    ##! 8: "determine all used handlers"

    $self->{PKI_REALM}->{$realm}->{STACK}->{$stack}->{DESCRIPTION} = $desc;
    $self->{PKI_REALM}->{$realm}->{STACK}->{$stack}->{HANDLER} =
        CTX('xml_config')->get_xpath_list (XPATH   => ['pki_realm', 'auth', 'stack', 'handler'],
                                       COUNTER => [$realm_pos, 0, $stack_pos]);
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

    ##! 8: "load handler name and type"

    my $name = CTX('xml_config')->get_xpath (XPATH   => ['pki_realm', 'auth', 'handler', 'name'],
                                         COUNTER => [$realm_pos, 0, $handler_pos, 0]);
    my $type = CTX('xml_config')->get_xpath (XPATH   => ['pki_realm', 'auth', 'handler', 'type'],
                                         COUNTER => [$realm_pos, 0, $handler_pos, 0]);
    ##! 8: "name ::= $name"
    ##! 8: "type ::= $type"
    $type = "OpenXPKI::Server::Authentication::$type";
    $self->{PKI_REALM}->{$realm}->{HANDLER}->{$name} = eval {

        $type->new ({XPATH   => ['pki_realm', 'auth', 'handler'],
                     COUNTER => [$realm_pos, 0, $handler_pos]});

                                                           };
    if (my $exc = OpenXPKI::Exception->caught())
    {
        ##! 16: "exception from authentication sub module $type detected"
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LOAD_HANDLER_FAILED",
            child   => $exc);
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

sub login
{
    my $self = shift;

    ##! 1: "start"

    CTX('session')->start_authentication();

    ##! 2: "get PKI realm"
    my $realm = CTX('session')->get_pki_realm();

    ##! 2: "get authentication stack"
    my %stacks = ();
    foreach my $stack (sort keys %{$self->{PKI_REALM}->{$realm}->{STACK}})
    {
        $stacks{$stack}->{NAME}        = $stack;
        $stacks{$stack}->{DESCRIPTION} = $self->{PKI_REALM}->{$realm}->{STACK}->{$stack}->{DESCRIPTION};
    }
    my $stack = CTX('service')->get_authentication_stack (
                {
                    STACKS => \%stacks
                });
    if (not $stack)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LOGIN_NO_STACK_PRESENT");
    }
    if (not exists $self->{PKI_REALM}->{$realm}->{STACK}->{$stack} or
        not scalar @{$self->{PKI_REALM}->{$realm}->{STACK}->{$stack}->{HANDLER}})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LOGIN_INVALID_STACK",
            params  => {STACK => $stack});
    }

    ##! 2: "try the different available handlers for the stack $stack"
    my $ok = 0;
    foreach my $handler (@{$self->{PKI_REALM}->{$realm}->{STACK}->{$stack}->{HANDLER}})
    {
        ##! 4: "handler $handler from stack $stack"
        my $ref = $self->{PKI_REALM}->{$realm}->{HANDLER}->{$handler};
        if (not ref $ref)
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_WRONG_HANDLER",
                params  => {PKI_REALM => $realm, HANDLER => $handler});
        }
        eval
        {
            $ref->login($handler);
        };
        if (not $EVAL_ERROR)
        {
            ##! 8: "login ok"
            $ok = 1;
            CTX('session')->set_user ($ref->get_user());
            CTX('session')->set_role ($ref->get_role());
            CTX('session')->make_valid();
            ##! 8: "session configured"
            last;
        } else {
            ##! 8: "EVAL_ERROR detected"
        }
    }
    if (not $ok)
    {
        ##! 4: "show at minimum the last error message"
        if (my $exc = OpenXPKI::Exception->caught())
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LOGIN_FAILED",
                child   => $exc);
        }
        else
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_LOGIN_FAILED",
                child   => $EVAL_ERROR->message());
        }
    }

    return 1;
}

1;
__END__

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

=head2 login

is the function which performs the authentication. You cannot
specify any parameters. The function executes in the server's
context and only uses the configuration as source for
necessary informations. It returns true on success and throws
an exception on failure.

=head1 See Also

OpenXPKI::Server::Authentication::Anonymous
OpenXPKI::Server::Authentication::External
OpenXPKI::Server::Authentication::LDAP
OpenXPKI::Server::Authentication::Password
OpenXPKI::Server::Authentication::X509
