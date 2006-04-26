## OpenXPKI::Service::Default.pm 
##
## Written 2005-2006 by Michael Bell for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project
## $Revision$

use strict;
use warnings;
use utf8;

package OpenXPKI::Service::Default;

## used modules

use English;
use OpenXPKI qw (set_language);
use OpenXPKI::Debug 'OpenXPKI::Service::Default';
use OpenXPKI::Exception;
use OpenXPKI::Server::Session;
use OpenXPKI::Server::Context qw( CTX );

sub new
{
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    bless $self, $class;

    my $keys = shift;

    ##! 2: "init protocol stack"
    if (not $keys->{TRANSPORT})
    {
        OpenXPKI::Exception->throw
        (
            message => "I18N_OPENXPKI_SERIALIZATION_DEFAULT_NEW_MISSING_TRANSPORT",
        );
    }
    if (not $keys->{SERIALIZATION})
    {
        OpenXPKI::Exception->throw
        (
            message => "I18N_OPENXPKI_SERIALIZATION_DEFAULT_NEW_MISSING_SERIALIZATION",
        );
    }
    $self->{TRANSPORT}     = $keys->{TRANSPORT};
    $self->{SERIALIZATION} = $keys->{SERIALIZATION};

    return $self;
}

sub init
{
    my $self = shift;

    ##! 1: "start"

    $self->__init_session();
    $self->__init_pki_realm();
    if (not CTX('session')->get_user() or
	not CTX('session')->get_role()) {
	my $authentication = CTX('authentication');
        ##! 2: $authentication
	$authentication->login()
    }
    $self->{TRANSPORT}->write
    (
        $self->{SERIALIZATION}->serialize
        (
            {SERVICE_MSG => "SERVICE_READY"}
        )
    );

    return 1;
}

sub __init_session
{
    ##! 1: "check if this is a ne session"
    my $self    = shift;
    my $session = undef;

    ##! 2: "read SESSION_INIT"
    my $msg = $self->{SERIALIZATION}->deserialize
              (
                  $self->{TRANSPORT}->read()
              );
    if ($msg->{SERVICE_MSG} eq "CONTINUE_SESSION")
    {
        ##! 4: "try to continue session"
        eval
        {
            $session = OpenXPKI::Server::Session->new
                       ({
                           DIRECTORY => CTX('xml_config')->get_xpath_count
                                        (
                                            XPATH => "common/server/session_dir"
                                        ),
                           LIFETIME  => CTX('xml_config')->get_xpath_count
                                        (
                                            XPATH => "common/server/session_lifetime"
                                        ),
                           ID        => $msg->{SESSION_ID}
                       });
        };
        if ($EVAL_ERROR)
        {
            $self->{TRANSPORT}->write
            (
                $self->{SERIALIZATION}->serialize
                (
                    {ERROR => "ILLEGAL_OLD_SESSION"}
                )
            );
            OpenXPKI::Exception->throw
            (
                message => "I18N_OPENXPKI_SERIALIZATION_DEFAULT_INIT_NEW_SESSION_CONTINUE_FAILED",
                params  => {ID => $msg->{SESSION_ID}}
            );
        }
    }
    elsif ($msg->{SERVICE_MSG} eq "NEW_SESSION")
    {
        ##! 4: "new session"
        $session = OpenXPKI::Server::Session->new
                   ({
                       DIRECTORY => CTX('xml_config')->get_xpath
                                    (
                                        XPATH => "common/server/session_dir"
                                    ),
                       LIFETIME  => CTX('xml_config')->get_xpath
                                    (
                                        XPATH => "common/server/session_lifetime"
                                    ),
                   });
        if (exists $msg->{LANGUAGE})
        {
            ##! 8: "set language"
            set_language($msg->{LANGUAGE});
            $session->set_language($msg->{LANGUAGE});
        } else {
            ##! 8: "no language specified"
        }
        
    }
    else
    {
        ##! 4: "illegal session init"
        $self->{TRANSPORT}->write
        (
            $self->{SERIALIZATION}->serialize
            (
                {ERROR => "UNKNOWN_COMMAND"}
            )
        );
        OpenXPKI::Exception->throw
        (
            message => "I18N_OPENXPKI_SERIALIZATION_DEFAULT_INIT_SESSION_UNKNOWN_COMMAND",
            params  => {COMMAND => $msg->{COMMAND}}
        );
    }
    OpenXPKI::Server::Context::setcontext ({'session' => $session});
    ##! 4: "send answer to client"
    $self->{TRANSPORT}->write
    (
        $self->{SERIALIZATION}->serialize
        ({
            SESSION_ID => $session->get_id(),
        })
    );
    ##! 4: "read commit from client (SESSION_ID_ACCEPTED)"
    $msg = $self->{SERIALIZATION}->deserialize
           (
               $self->{TRANSPORT}->read()
           );


    return 1;
}

sub __init_pki_realm
{
    my $self = shift;

    ##! 2: "if we know the session then return the ID"
    return CTX('session')->get_pki_realm()
        if (CTX('session')->get_pki_realm());

    ##! 2: "check if there is more than one pki"
    my @list = sort keys %{CTX('pki_realm')};
    if (scalar @list < 1)
    {
        ##! 4: "no PKI realm configured"
        OpenXPKI::Exception->throw
        (
            message => "I18N_OPENXPKI_SERVICE_DEFAULT_GET_PKI_REALM_NO_REALM_CONFIGURED",
        );
    }
    if (scalar @list == 1)
    {
        ##! 4: "update session with PKI realm"
        CTX('session')->set_pki_realm ($list[0]);
        return $list[0];
    }

    ##! 2: "build hash with ID, name and description"
    my %realms =();
    foreach my $realm (@list)
    {
        $realms{$realm}->{NAME}        = $realm;
        ## FIXME: we should add a description to every PKI realm
        $realms{$realm}->{DESCRIPTION} = $realm;
    }

    ##! 2: "send all available pki realms"
    $self->{TRANSPORT}->write
    (
        $self->{SERIALIZATION}->serialize
        ({
            SERVICE_MSG => "GET_PKI_REALM",
            PKI_REALMS  => \%realms,
        })
    );

    ##! 2: "read answer"
    my $msg = $self->{SERIALIZATION}->deserialize
              (
                  $self->{TRANSPORT}->read()
              );
    if (not exists $msg->{PKI_REALM} or
        not exists CTX('pki_realm')->{$msg->{PKI_REALM}})
    {
        $self->{TRANSPORT}->write
        (
            $self->{SERIALIZATION}->serialize
            (
                {ERROR => "ILLEGAL_PKI_REALM"}
            )
        );
        OpenXPKI::Exception->throw
        (
            message => "I18N_OPENXPKI_SERVICE_DEFAULT_GET_PKI_REALM_ILLEGAL_REALM",
            params  => {PKI_REALM => $msg->{PKI_REALM}}
        );
    }

    ##! 2: "update session with PKI realm"
    CTX('session')->set_pki_realm ($msg->{PKI_REALM});
    return $msg->{PKI_REALM};
}

sub run
{
    my $self = shift;

    while (my $msg = $self->{TRANSPORT}->read())
    {
        my $data = $self->{SERIALIZATION}->deserialize($msg);

        ##! 4: "check for logout"
        if (exists $data->{SERVICE_MSG} and
            $data->{SERVICE_MSG} eq "LOGOUT")
        {
            ##! 8: "logout received - killing session and connection"
            CTX('session')->delete();
            exit 0;
        }
    }

    return 1;
}

###########################################
##     begin native service messages     ##
###########################################

# ok was brauche ich?
# get_pki_realm (erledigt)
# authentication stack
# passwd_login
# x509_login
# token_login

sub get_authentication_stack
{
    my $self = shift;
    my $keys = shift;

    ##! 2: "send all available authentication stacks"
    $self->{TRANSPORT}->write
    (
        $self->{SERIALIZATION}->serialize
        ({
            SERVICE_MSG           => "GET_AUTHENTICATION_STACK",
            AUTHENTICATION_STACKS => $keys->{STACKS},
        })
    );

    ##! 2: "read answer"
    my $msg = $self->{SERIALIZATION}->deserialize
              (
                  $self->{TRANSPORT}->read()
              );
    if (not exists $msg->{AUTHENTICATION_STACK} or
        not exists $keys->{STACKS}->{$msg->{AUTHENTICATION_STACK}})
    {
        $self->{TRANSPORT}->write
        (
            $self->{SERIALIZATION}->serialize
            (
                {ERROR => "ILLEGAL_AUTHENTICATION_STACK"}
            )
        );
        OpenXPKI::Exception->throw
        (
            message => "I18N_OPENXPKI_SERVICE_DEFAULT_GET_AUTH_STACK_ILLEGAL_STACK",
            params  => {PKI_REALM => $msg->{AUTHENTICATION_STACK}}
        );
    }

    ##! 2: "return auth_stack ".$msg->{AUTHENTICATION_STACK}
    return $msg->{AUTHENTICATION_STACK};
}

sub get_passwd_login
{
    my $self = shift;
    ##! 1: "start"
    my $keys = shift;
    ##! 2: "handler ".$keys->{ID}

    $self->{TRANSPORT}->write
    (
        $self->{SERIALIZATION}->serialize
        ({
            SERVICE_MSG => "GET_PASSWD_LOGIN",
            PARAMS      => $keys,
        })
    );

    ##! 2: "read answer"
    my $msg = $self->{SERIALIZATION}->deserialize
              (
                  $self->{TRANSPORT}->read()
              );
    if (not exists $msg->{LOGIN})
    {
        $self->{TRANSPORT}->write
        (
            $self->{SERIALIZATION}->serialize
            (
                {ERROR => "MISSING_LOGIN"}
            )
        );
        OpenXPKI::Exception->throw
        (
            message => "I18N_OPENXPKI_SERVICE_DEFAULT_GET_PASSWD_LOGIN_MISSING_LOGIN",
            params  => $keys
        );
    }
    if (not exists $msg->{PASSWD})
    {
        $self->{TRANSPORT}->write
        (
            $self->{SERIALIZATION}->serialize
            (
                {ERROR => "MISSING_PASSWD"}
            )
        );
        OpenXPKI::Exception->throw
        (
            message => "I18N_OPENXPKI_SERVICE_DEFAULT_GET_PASSWD_LOGIN_MISSING_PASSWD",
            params  => $keys
        );
    }

    return ({LOGIN => $msg->{LOGIN}, PASSWD => $msg->{PASSWD}});
}

#########################################
##     end native service messages     ##
#########################################

1;
__END__

=head1 Description

This module is only used to test the server. It is a simple dummy
class which does nothing.

=head1 Protocol Definition

=head2 Connection startup

You can send two messages at the beginning of a connection. You can
ask to continue an old session or you start a new session. The answer
is always the same - the session ID or an error message.

=head3 Session init

--> {SERVICE_MSG => "NEW_SESSION",
     LANGUAGE    => $lang}

<-- {SESSION_ID => $ID}

--> {SERVICE_MSG => "SESSION_ID_ACCEPTED"}

<-- {SERVICE_MSG => "GET_PKI_REALM",
     PKI_REALMS  => {
                     "0" => {
                             NAME => "Root Realm",
                             DESCRIPTION => "This is an example root realm."
                            }
                    }
    }

--> {PKI_REALM => $realm}

<-- {SERVICE_MSG => "GET_AUTHENTICATION_STACK",
     AUTH_STACKS => {
                     "0" => {
                             NAME => "Basic Root Auth Stack",
                             DESCRIPTION => "This is the basic root authentication stack."
                            }
                    }
    }

--> {AUTH_STACK => "0"}

Example 1: Anonymous Login

<-- {SERVICE_MSG => "SERVICE_READY"}

Answer is the first command.

Example 2: Password Login

<-- {SERVICE_MSG => "GET_PASSWD_LOGIN",
     PARAMS => {
                NAME        => "XYZ",
                DESCRIPTION => "bla bla ..."
               }
    }

--> {LOGIN  => "John Doe",
     PASSWD => "12345678"}

on success ...
<-- {SERVICE_MSG => "SERVICE_READY"}

on failure ...
<-- {ERROR => "some already translated message"}

=head3 Session continue

--> {SERVICE_MSG => "CONTINUE",
     SESSION_ID  => $ID}

<-- {SESSION_ID => $ID}

--> {SERVICE_MSG => "SESSION_ID_ACCEPTED}

<-- {SERVICE_MSG => "SERVICE_READY"}

=head1 Functions

The functions does nothing else than to support the test stuff
with a working user interface dummy.

=over

=item * new

=item * init

=item * run

=item * get_authentication_stack

=item * get_passwd_login

=back
