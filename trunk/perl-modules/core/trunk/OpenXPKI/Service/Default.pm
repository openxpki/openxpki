## OpenXPKI::Service::Default.pm 
##
## Written 2005-2006 by Michael Bell and Martin Bartosch for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project
## $Revision$

package OpenXPKI::Service::Default;

use base qw( OpenXPKI::Service );

use strict;
use warnings;
use utf8;
use English;

use Class::Std;

## used modules

use OpenXPKI::i18n qw(set_language);
use OpenXPKI::Debug 'OpenXPKI::Service::Default';
use OpenXPKI::Exception;
use OpenXPKI::Server;
use OpenXPKI::Server::Session;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Service::Default::Command;


sub init
{
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

    ##! 1: "start"

    # timeout idle clients
    
    my $timeout = 120;
    eval {
	$timeout = CTX('xml_config')->get_xpath(
	    XPATH => "common/server/connection_timeout"
	);
    };

    $self->set_timeout($timeout);
    
    $self->__init_session();
    $self->__init_pki_realm();
    if (! $self->get_API()->get_user() ||
	! $self->get_API()->get_role()) {
	my $authentication = CTX('authentication');
        ##! 2: $authentication
	$authentication->login();
    }

    $self->talk(
        {
	    SERVICE_MSG => "SERVICE_READY",
	});

    return 1;
}



sub __init_session : PRIVATE {
    my $self    = shift;
    my $ident   = ident $self;
    my $arg     = shift;

    my $session = undef;

    ##! 1: "check if this is a new session"

    ##! 2: "read SESSION_INIT"
    my $msg = $self->collect();

    if ($msg->{SERVICE_MSG} eq "CONTINUE_SESSION")
    {
        ##! 4: "try to continue session"
        eval
        {
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
                           ID        => $msg->{SESSION_ID}
                       });
        };
	if ($EVAL_ERROR) {
	    my $error = 'I18N_OPENXPKI_SEVICE_DEFAULT_INIT_NEW_SESSION_CONTINUE_FAILED';
	    $self->talk(
	        $self->__get_error(
		    {
			ERROR => $error,
			EXCEPTION => $EVAL_ERROR,
		    }));
	    
	    if (my $exc = OpenXPKI::Exception->caught())
	    {
		OpenXPKI::Exception->throw (
		    message => $error,
		    params  => {ID => $msg->{SESSION_ID}},
		    child   => $exc);
	    } else {
		OpenXPKI::Exception->throw
		    (
		     message => $error,
		     params  => {ID => $msg->{SESSION_ID}}
		    );
	    }
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
	my $error = 'I18N_OPENXPKI_SERVICE_DEFAULT_INIT_SESSION_UNKNOWN_COMMAND';
	$self->talk(
	    $self->__get_error(
	        {
		    ERROR => $error,
		}));

        OpenXPKI::Exception->throw(
	    message => $error,
	    params  => {COMMAND => $msg->{COMMAND}}
	    );
    }
    OpenXPKI::Server::Context::setcontext ({'session' => $session});
    ##! 4: "send answer to client"
    $self->talk(
        {
            SESSION_ID => $session->get_id(),
        });

    ##! 4: "read commit from client (SESSION_ID_ACCEPTED)"
    $msg = $self->collect();


    return 1;
}

sub __init_pki_realm
{
    my $self    = shift;
    my $ident   = ident $self;
    my $arg     = shift;

    ##! 1: "start"

    ##! 2: "if we know the PKI realm then return it"
    eval {
	my $realm = $self->get_API()->get_pki_realm();
	return $realm if defined $realm;
    };

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
    $self->talk(
        {
            SERVICE_MSG => "GET_PKI_REALM",
            PKI_REALMS  => \%realms,
        });

    ##! 2: "read answer"
    my $msg = $self->collect();

    if (not exists $msg->{PKI_REALM} or
        not exists CTX('pki_realm')->{$msg->{PKI_REALM}})
    {
	my $error = 'I18N_OPENXPKI_SERVICE_DEFAULT_GET_PKI_REALM_ILLEGAL_REALM';
	$self->talk(
	    $self->__get_error(
	        {
		    ERROR => $error,
		    PARAMS => {PKI_REALM => $msg->{PKI_REALM}},
		}));

        OpenXPKI::Exception->throw(
            message => $error,
            params  => {PKI_REALM => $msg->{PKI_REALM}}
        );
    }

    ##! 2: "update session with PKI realm"
    CTX('session')->set_pki_realm ($msg->{PKI_REALM});
    return $msg->{PKI_REALM};
}

sub run
{
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

  MESSAGE:
    while (1)
    {
	my $data;
	eval {
	    $data = $self->collect();
	};
	if (my $exc = OpenXPKI::Exception->caught()) {
	    if ($exc->message() =~ m{I18N_OPENXPKI_TRANSPORT.*CLOSED_CONNECTION}xms) {
		# client closed socket
		last MESSAGE;
	    } else {
		# FIXME: return error instead of rethrowing
		$exc->rethrow();
	    }
	} elsif ($EVAL_ERROR) {
	    if (ref $EVAL_ERROR) {
		$EVAL_ERROR->rethrow();
	    } else {
		OpenXPKI::Exception->throw (
		    message => "I18N_OPENXPKI_SERVICE_DEFAULT_RUN_READ_EXCEPTION",
		    params  => {EVAL_ERROR => $EVAL_ERROR});
	    }
	}

	last MESSAGE unless defined $data;

	my $service_msg = $data->{SERVICE_MSG};
	if (! defined $service_msg) {
	    $self->talk(
	        $self->__get_error(
		    {
			ERROR => 'I18N_OPENXPKI_SERVICE_DEFAULT_RUN_MISSING_SERVICE_MESSAGE',
		    }));
	    
	    next MESSAGE;
	}			

	##! 4: "$service_msg"

        ##! 4: "check for logout"
        if ($service_msg eq 'LOGOUT')
        {
            ##! 8: "logout received - killing session and connection"
	    CTX('log')->log(
		MESSAGE  => 'Terminating session',
		PRIORITY => 'info',
		FACILITY => 'system',
		);
	    CTX('session')->delete();
            exit 0;
        }

        ##! 4: "check for get_role"
        if ($service_msg eq 'STATUS') {
	    # FIXME: translate messages
	    my $result = {
		SESSION => {
		    ROLE => $self->get_API()->get_role(),
		    USER => $self->get_API()->get_user(),
		},
	    };

	    $self->talk($result);
	    
	    next MESSAGE;
        }
	
	if ($service_msg eq 'COMMAND') {
	    if (exists $data->{PARAMS}->{COMMAND}) {

		my $command;
		eval {
		    $command = OpenXPKI::Service::Default::Command->new(
			{
			    COMMAND => $data->{PARAMS}->{COMMAND},
			    PARAMS  => $data->{PARAMS}->{PARAMS},
			});
		};
		if (my $exc = OpenXPKI::Exception->caught()) {
		    if ($exc->message() =~ m{I18N_OPENXPKI_SERVICE_DEFAULT_COMMAND_INVALID_COMMAND}xms) {
			##! 16: "Invalid command $data->{COMMAND}"
			# fall-through intended
		    } else {
			$exc->rethrow();
		    }
		} elsif ($EVAL_ERROR) {
		    if (ref $EVAL_ERROR) {
			$EVAL_ERROR->rethrow();
		    } else {
			OpenXPKI::Exception->throw (
			    message => "I18N_OPENXPKI_SERVICE_DEFAULT_RUN_COULD_NOT_INSTANTIATE_COMMAND",
			    params  => {EVAL_ERROR => $EVAL_ERROR});
		    }
		}

		if (defined $command) {
		    my $result;
		    eval {
			$result = $command->execute();
		    };
		    if ($EVAL_ERROR) {
			##! 14: "Exception caught during command execution"
			$self->talk(
			    $self->__get_error(
			        {
				    ERROR => 'I18N_OPENXPKI_SERVICE_DEFAULT_RUN_COMMAND_EXECUTION_FAILED',
				    EXCEPTION => $EVAL_ERROR,
				}));
			
			next MESSAGE;
		    }

		    # sanity checks on command reply
		    if (! defined $result || ref $result ne 'HASH') {
			$self->talk(
			    $self->__get_error(
			        {
				    ERROR => "I18N_OPENXPKI_SERVICE_DEFAULT_RUN_ILLEGAL_COMMAND_RETURN_VALUE",
				}));

			next MESSAGE;
		    }

		    # FIXME: translate messages
		    $self->talk($result);

		    next MESSAGE;
		}
	    }

	    $self->talk(
	        $self->__get_error(
		    {
			ERROR => "I18N_OPENXPKI_SERVICE_DEFAULT_RUN_UNRECOGNIZED_COMMAND",
		    }));

	    next MESSAGE;
	}

	$self->talk(
	    $self->__get_error(
	        {
		    ERROR => "I18N_OPENXPKI_SERVICE_DEFAULT_RUN_UNRECOGNIZED_SERVICE_MESSAGE",
		}));
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
    my $self  = shift;
    my $ident = ident $self;
    my $keys  = shift;

    ##! 1: "start"

    ##! 2: "if we know the authentication stack then return it"
    return CTX('session')->get_authentication_stack()
        if (CTX('session')->get_authentication_stack());

    ##! 2: "determine the authentication stack"
    my $msg;
  GET_AUTH_STACK:
    while (1) {
	##! 2: "send all available authentication stacks"
	$self->talk(
	    {
		SERVICE_MSG           => "GET_AUTHENTICATION_STACK",
		AUTHENTICATION_STACKS => $keys->{STACKS},
	    });
	
	##! 2: "read answer"
	$msg = $self->collect();

	if (exists $msg->{AUTHENTICATION_STACK}
	    && exists $keys->{STACKS}->{$msg->{AUTHENTICATION_STACK}}) {
            ##! 2: "authentication stack ".$msg->{AUTHENTICATION_STACK}." accepted"
	    last GET_AUTH_STACK;
	}
    }

    ##! 2: "put the authentication stack into the session"
    CTX('session')->set_authentication_stack($msg->{AUTHENTICATION_STACK});

    ##! 2: "end"
    return $msg->{AUTHENTICATION_STACK};
}

sub get_passwd_login
{
    my $self  = shift;
    my $ident = ident $self;
    my $keys  = shift;

    ##! 1: "start"

    ##! 2: "handler ".$keys->{ID}

  GET_PASSWD_LOGIN:
    while (1) {
	$self->talk(
	    {
		SERVICE_MSG => "GET_PASSWD_LOGIN",
		PARAMS      => $keys,
	    });
	
	##! 2: "read answer"
	my $msg = $self->collect();
	
	next GET_PASSWD_LOGIN unless exists $msg->{PARAMS}->{LOGIN};
	next GET_PASSWD_LOGIN unless exists $msg->{PARAMS}->{PASSWD};
	
	return (
	    {
		LOGIN => $msg->{PARAMS}->{LOGIN}, 
		PASSWD => $msg->{PARAMS}->{PASSWD},
	    });
    }
}

#########################################
##     end native service messages     ##
#########################################

1;
__END__

=head1 Name

OpenXPKI::Service::Default - basic service implementation

=head1 Description

This is the common Service implementation to be used by most interactive
clients. It supports PKI realm selection, user authentication and session
handling.

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
     AUTHENTICATION_STACKS => {
                     "0" => {
                             NAME => "Basic Root Auth Stack",
                             DESCRIPTION => "This is the basic root authentication stack."
                            }
                    }
    }

--> {AUTHENTICATION_STACK => "0"}

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

--> {SERVICE_MSG => "CONTINUE_SESSION",
     SESSION_ID  => $ID}

<-- {SESSION_ID => $ID}

--> {SERVICE_MSG => "SESSION_ID_ACCEPTED}

<-- {SERVICE_MSG => "SERVICE_READY"}

=head1 Functions

The functions does nothing else than to support the test stuff
with a working user interface dummy.

=over

=item * START

=item * init

=item * run

=item * get_authentication_stack

=item * get_passwd_login

=back
