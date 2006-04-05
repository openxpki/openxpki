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

    if (not $skeys->{TRANSPORT})
    {
        OpenXPKI::Exception->throw
        (
            message => "I18N_OPENXPKI_SERIALIZATION_DEFAULT_NEW_MISSING_TRANSPORT",
        );
    }
    if (not $skeys->{SERIALIZATION})
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
    ## do we have to init something?
    return 1;
}

sub __init
{
    my $self = shift;

    ## create or reinit a new session
    $self->__init_session();

    ## determine the used PKI realm
    $self->__init_pki_realm();

    ## authenticate the server
    $self->__init_user();

    return 1;
}

sub __init_session
{
    my $self    = shift;
    my $session = undef;

    ## next transport action is to read something

    my $msg = $self->{SERIALIZATION}->deserialize
              (
                  $self->{TRANSPORT}->read()
              );
    if ($msg->{COMMAND} eq "CONTINUE_SESSION")
    {
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
        }
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
                message => "I18N_OPENXPKI_SERIALIZATION_DEFAULT_INIT_SESSION_CONTINUE_FAILED",
                params  => {ID => $msg->{SESSION_ID}}
            );
        }
    }
    elsif ($msg->{COMMAND} eq "NEW_SESSION")
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
                   });
    }
    else
    {
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
    return 1;
}

sub __init_pki_realm
{
    my $self = shift;

    ## next transport action is to write something

    while (not CTX('session')->get_pki_realm())
    {
        eval {$self->get_pki_realm()};
    }

    return 1;
}

sub __init_user
{
    my $self = shift;
    return 1 if (CTX('session')->get_user());

    ## next transport action is to write something

    CTX('authentication')->login ();
    return 1;
}

sub run
{
    my $self = shift;

    $self->__init();

    while (my $msg = $self->{TRANSPORT}->read())
    {
        my $data = $self->{SERIALIZATION}->deserialize($data);
        ## now we have to read the command
        ## and start the relevant workflow action
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
    ##! 1: "start"
    exit;
    return $self->{AUTHENTICATION_STACK};
}

sub get_passwd_login
{
    my $self = shift;
    ##! 1: "start"
    my $name = shift;
    ##! 2: "handler $name"
    exit;
    return ($self->{LOGIN}, $self->{PASSWD});
}

sub get_pki_realm
{
    my $self = shift;
    return CTX('session')->get_pki_realm()
        if (CTX('session')->get_pki_realm());

    ## send all available pki realms
    $self->{TRANSPORT}->write
    (
        $self->{SERIALIZATION}->serialize
        ({
            COMMAND    => "GET_PKI_REALM",
            PKI_REALMS => [keys %{CTX('pki_realm')}],
        })
    );

    ## read answer
    my $realm = $self->{SERIALIZATION}->deserialize
                (
                    $self->{TRANSPORT}->read()
                );
    if (not grep /^$realm$/, keys %{CTX('pki_realm')})
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
            message => "I18N_OPENXPKI_SERIALIZATION_DEFAULT_GET_PKI_REALM_ILLEGAL_REALM",
            params  => {PKI_REALM => $realm}
        );
    }
    CTX('session')->set_pki_realm ($realm);
    return $realm;
}

#########################################
##     end native service messages     ##
#########################################

1;
__END__

=head1 Description

This module is only used to test the server. It is a simple dummy
class which does nothing.

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
