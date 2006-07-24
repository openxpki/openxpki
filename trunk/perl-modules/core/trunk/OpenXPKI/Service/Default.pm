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


# macro function get a setting required for session init safely
sub __get_setting : PRIVATE {
    my $self    = shift;
    my $ident   = ident $self;
    my $arg     = shift;

    my $params            = $arg->{PARAMS};
    my $setting           = $arg->{SETTING};     # e. g. 'PKI_REALM'

    my $service_msg       = 'GET_' . $setting;   # e. g. 'GET_PKI_REALM'
    my $param_name        = $setting . "S";      # e. g. 'PKI_REALMS'
    my $expected_response = $setting;

    ##! 2: "get setting from client"
    my $msg;
    my $value;
  GET_SETTING:
    while (1) {
	##! 2: "send all available values"
	$self->talk(
	    {
		SERVICE_MSG => $service_msg,
		PARAMS => {
		    $param_name => $params,
		},
	    });
	
	##! 2: "read answer, expected service msg: $service_msg, expected parameter: $expected_response"
	$msg = $self->collect();

	if (defined $msg->{SERVICE_MSG} 
	    && ($msg->{SERVICE_MSG} eq $service_msg)
	    && (defined $msg->{PARAMS}->{$expected_response})) {

	    $value = $msg->{PARAMS}->{$expected_response};
	    ##! 2: "requested value: $value"

	    if (exists $params->{$value}) {
		##! 4: "value accepted"
		last GET_SETTING;
	    }
	    ##! 4: "value rejected"
	}
    }

    ##! 1: "returning $value"
    return $value;
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
            $self->__send_error ({ERROR     => $error,
                                  EXCEPTION => $EVAL_ERROR});
	    
	    if (my $exc = OpenXPKI::Exception->caught())
	    {
		OpenXPKI::Exception->throw (
		    message  => $error,
		    params   => {ID => $msg->{SESSION_ID}},
		    children => [ $exc ]);
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
	$self->__send_error ({ ERROR => $error });
 
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

    ##! 2: "check if PKI realm is already known"
    my $realm;
    eval {
	$realm = $self->get_API()->get_pki_realm();
    };
    return $realm if defined $realm;

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


    my $requested_realm = $self->__get_setting(
	{
	    SETTING => 'PKI_REALM',
	    PARAMS  => \%realms,
	});

    ##! 2: "update session with PKI realm"
    CTX('session')->set_pki_realm ($requested_realm);
    return $requested_realm;
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
	if (! defined $service_msg) 
        {
	    $self->__send_error({ ERROR => 'I18N_OPENXPKI_SERVICE_DEFAULT_RUN_MISSING_SERVICE_MESSAGE' });
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

        ##! 4: "check for ping"
        if ($service_msg eq 'PING') {
	    $self->talk({});
	    
	    next MESSAGE;
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
		    if ($exc->message() =~ m{
                            I18N_OPENXPKI_SERVICE_DEFAULT_COMMAND_INVALID_COMMAND
                        }xms) {
			##! 16: "Invalid command $data->{PARAMS}->{COMMAND}"
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
			    params  => {
				EVAL_ERROR => $EVAL_ERROR,
			    });
		    }
		}

		if (defined $command) {
		    my $result;
		    eval {
			$result = $command->execute();
		    };
		    if ($EVAL_ERROR) {
			##! 14: "Exception caught during command execution"
			$self->__send_error(
			{
                            ## this error is senseless and it breaks the error tree
                            ## we already have useful error message
			    ## ERROR     => 'I18N_OPENXPKI_SERVICE_DEFAULT_RUN_COMMAND_EXECUTION_FAILED',
			    EXCEPTION => $EVAL_ERROR,
			});
			
			next MESSAGE;
		    }

		    # sanity checks on command reply
		    if (! defined $result || ref $result ne 'HASH') {
			$self->__send_error(
			{
			    ERROR => "I18N_OPENXPKI_SERVICE_DEFAULT_RUN_ILLEGAL_COMMAND_RETURN_VALUE",
			});

			next MESSAGE;
		    }

		    # FIXME: translate messages
		    $self->talk($result);

		    next MESSAGE;
		}
	    }

	    $self->__send_error(
	    {
		ERROR => "I18N_OPENXPKI_SERVICE_DEFAULT_RUN_UNRECOGNIZED_COMMAND",
	    });

	    next MESSAGE;
	}

	$self->__send_error(
	{
	    ERROR => "I18N_OPENXPKI_SERVICE_DEFAULT_RUN_UNRECOGNIZED_SERVICE_MESSAGE",
	});
    }

    return 1;
}

###########################################
##     begin native service messages     ##
###########################################

# missing login methods:
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

    my $requested_stack = $self->__get_setting(
	{
	    SETTING => 'AUTHENTICATION_STACK',
	    PARAMS  => $keys->{STACKS},
	});
    
    ##! 2: "put the authentication stack into the session"
    CTX('session')->set_authentication_stack($requested_stack);

    ##! 2: "end"
    return $requested_stack;
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
	### FIXME: enforce maximum number of retries?
	### FIXME: delay for incorrect login?
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

##################################
##     begin error handling     ##
##################################

sub __send_error
{
    my $self = shift;
    my $params = shift;

    return $self->talk({SERVICE_MSG => "ERROR",
                        LIST        => [ $self->__get_error ($params) ] });
}

################################
##     end error handling     ##
################################

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
     PARAMS => {
         PKI_REALM  => {
                     "0" => {
                             NAME => "Root Realm",
                             DESCRIPTION => "This is an example root realm."
                            }
                    }
              }
         }
    }

--> {SERVICE_MSG => "GET_PKI_REALM",
     PARAMS => {
         PKI_REALM => $realm,
     }
    }

<-- {SERVICE_MSG => "GET_AUTHENTICATION_STACK",
     PARAMS => {
          AUTHENTICATION_STACKS => {
                    "0" => {
                             NAME => "Basic Root Auth Stack",
                             DESCRIPTION => "This is the basic root authentication stack."
                            }
                    }
             }
    }

--> {SERVICE_MSG => "GET_AUTHENTICATION_STACK",
     PARAMS => {
        AUTHENTICATION_STACK => "0"
     }
    }
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
