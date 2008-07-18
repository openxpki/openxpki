## OpenXPKI::Server::Authentication::ClientSSO.pm 
##
## Based on code Written 2005 by Martin Bartosch and Michael Bell
## Re-Written 2007 by Michael Bell
## Updated to use new Service::Default semantics 2007 by Alexander Klink
## (C) Copyright 2005-2007 by The OpenXPKI Project

package OpenXPKI::Server::Authentication::ClientSSO;

use strict;
use warnings;
use English;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

use base qw( OpenXPKI::Server::Authentication::External );

sub login_step {
    ##! 1: 'start' 
    my $self    = shift;
    my $arg_ref = shift;
 
    my $name    = $arg_ref->{HANDLER};
    my $msg     = $arg_ref->{MESSAGE};
    my $answer  = $msg->{PARAMS};

    if (! exists $msg->{PARAMS}->{LOGIN}) {
        ##! 4: 'no login data received (yet)' 
        return (undef, undef, 
            {
		SERVICE_MSG => "GET_CLIENT_SSO_LOGIN",
		PARAMS      => {
                    NAME        => $self->{NAME},
                    DESCRIPTION => $self->{DESC},
	        },
            },
        );
    }

    my ($account, $pseudo_role) = ($answer->{LOGIN}, $answer->{PSEUDO_ROLE});

    ##! 2: "credentials ... present"
    ##! 2: "account ... $account"
    ##! 2: "pseudo_role ... $pseudo_role"

    if ($self->{COMMAND})
    {
        ## if you use a static role and you use (trust) the
        ## client SSO then you have nothing todo
        ## Example: Shibboleth

        # see security warning below (near $out=`$cmd`)

        foreach my $name (keys %{$self->{ENV}})
        {
            my $value = $self->{ENV}->{$name};
            # we don't want to see expanded credentials in the log file,
            # so we just replace the credentials after logging it
            $value =~ s/__USER__/$account/g;
            $value =~ s/__PSEUDO_ROLE__/$pseudo_role/g;

            # set environment for executable
            $ENV{$name} = $value;
        }
        my $command = $self->{COMMAND};
        ##! 2: "execute command"

        # execute external program. this is safe, since cmd
        # is taken literally from the configuration.
        # NOTE: do not extend this code to allow login parameters
        # to be passed on the command line.
        # - the credentials may be visible in the OS process 
        #   environment
        # - worse yet, it is untrusted user input that might
        #   easily be used to execute arbitrary commands on the
        #   system.
        # SO DON'T EVEN THINK ABOUT IT!
        my $out = `$command`;
        map { delete $ENV{$_} } @{$self->{CLEARENV}}; # clear environment

        ##! 2: "command returned $CHILD_ERROR, STDOUT was: $out"
		
        if ($CHILD_ERROR != 0)
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_AUTHENTICATION_CLIENT_SSO_LOGIN_FAILED",
                params  => {
		    USER => $account,
		});
            return (undef, undef, {});
        }

        ## if the SSO requires command execution on the server side and
        ## the role is not statically defined
        ## then we parse the output of the command for the role
        if (not exists $self->{ROLE})
        {
            $out =~ s/$self->{PATTERN}/$self->{REPLACE}/;
            $self->{ROLE} = $out;
        }

    } ## end of command
    else
    {
        ## if we have not execute a server side command
        ## then we can use a statical role or we parse the role from the
        ## client SSO (pseudo_)role parameter
        if (! exists $self->{ROLE})
        {
            $pseudo_role =~ s/$self->{PATTERN}/$self->{REPLACE}/;
            $self->{ROLE} = $pseudo_role;
        }
    }

    $self->{USER} = $account;


    return (
        $self->{USER},
        $self->{ROLE},
        {
            SERVICE_MSG => 'SERVICE_READY',
        },
    );
}

1;
__END__

=head1 Name

OpenXPKI::Server::Authentication::ClientSSO - support for client based SSO.

=head1 Description

This is the class which supports OpenXPKI with an authentication method
via an SSO mechanism on the client side of the daemon. This can be for example
an installed Shibboleth system on the web server. Please notice that you must
trust the web server in this case. 
The parameters are passed as a hash reference.

=head1 Functions

=head2 new

is inherited from OpenXPKI::Server::Authentication::External

=head2 login

returns (user, role, service ready message) triple if login was
successful, (undef, undef, {}) otherwise. The message which
is supplied as a parameter to the function should contain at minimum
LOGIN as parameter. You can supply this module with preconfigured
role from the client SSO via the parameter pseudo_role. This
parameter can be processed on the server side via a regex or
a command to check its sanity.

It is higly recommended to take a look at the source code of
this module before you blindly trust a client's SSO mechanism.
Additionally you have to understand that the server in this
case must trust the client or the wrapper around the client.
