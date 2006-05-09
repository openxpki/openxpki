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
use OpenXPKI::Service::Default::Command;

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
            message => "I18N_OPENXPKI_SERVICE_DEFAULT_NEW_MISSING_TRANSPORT",
        );
    }
    if (not $keys->{SERIALIZATION})
    {
        OpenXPKI::Exception->throw
        (
            message => "I18N_OPENXPKI_SERVICE_DEFAULT_NEW_MISSING_SERIALIZATION",
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


sub __get_error {
    my $self = shift;
    my $arg  = shift;
    
    if (! exist $arg->{ERROR} || (ref $arg->{ERROR} ne '')) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVICE_DEFAULT_GET_ERROR_INVALID_PARAMETERS",
	    params => {
		PARAMETER => 'ERROR',
	    }
	    );
    }

    my $result = {
	ERROR => $arg->{ERROR},
    };

    if (exists $arg->{PARAMS}) {
	if (ref $arg->{PARAMS} ne 'HASH') {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVICE_DEFAULT_GET_ERROR_INVALID_PARAMETERS",
		params => {
		    PARAMETER => 'PARAMS',
		}
		);
	}
	$result->{PARAMS} = $arg->{PARAMS};
    }
    
    $result->{ERROR_MESSAGE} = OpenXPKI::i18nGettext($result->{ERROR}, 
						     %{$result->{PARAMS}});
    
    return $result;
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
            $self->{TRANSPORT}->write(
		$self->{SERIALIZATION}->serialize(
		    $self->__get_error(
			{
			    ERROR => $error,
			})));
	    
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
        $self->{TRANSPORT}->write(
            $self->{SERIALIZATION}->serialize(
		$self->__get_error(
		    {
			ERROR => $error,
		    })));

        OpenXPKI::Exception->throw(
	    message => $error,
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
	my $error = 'I18N_OPENXPKI_SERVICE_DEFAULT_GET_PKI_REALM_ILLEGAL_REALM';
        $self->{TRANSPORT}->write(
            $self->{SERIALIZATION}->serialize(
                $self->__get_error(
		    {
			ERROR => $error,
			PARAMS => {PKI_REALM => $msg->{PKI_REALM}},
		    })));
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
    my $self = shift;

  MESSAGE:
    while (1)
    {
	my $msg;
	eval {
	    $msg = $self->{TRANSPORT}->read();
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

	last MESSAGE unless defined $msg;

        my $data = $self->{SERIALIZATION}->deserialize($msg);

	my $service_msg = $data->{SERVICE_MSG};
	if (! defined $service_msg) {
	    $self->{TRANSPORT}->write(
		$self->{SERIALIZATION}->serialize(
		    $self->__get_error(
			{
			    ERROR => 'I18N_OPENXPKI_SERVICE_DEFAULT_RUN_MISSING_SERVICE_MESSAGE',
			})));
	    
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
	
	if ($service_msg eq 'COMMAND') {
	    if (defined $data->{COMMAND}) {
		##! 12: "command: $data->{COMMAND}"

		my $command = OpenXPKI::Service::Default::Command->new(
		    {
			COMMAND => $data->{COMMAND},
			PARAMS  => $data->{PARAMS},
		    });

		if (defined $command) {
		    my $result;
		    eval {
			$result = $command->execute();
		    };
		    if ($EVAL_ERROR) {
			##! 14: "Exception caught during command execution"
			$self->{TRANSPORT}->write(
			    $self->{SERIALIZATION}->serialize(
				$self->__get_error(
				    {
					ERROR => 'I18N_OPENXPKI_SERVICE_DEFAULT_RUN_COMMAND_EXECUTION_FAILED',
				    })));
			
			next MESSAGE;
		    }

		    # sanity checks on command reply
		    if (! defined $result || ref $result ne 'HASH') {
			$self->{TRANSPORT}->write(
			    $self->{SERIALIZATION}->serialize(
				$self->__get_error(
				    {
					ERROR => "I18N_OPENXPKI_SERVICE_DEFAULT_RUN_ILLEGAL_COMMAND_RETURN_VALUE",
				    })));

			next MESSAGE;
		    }

		    # FIXME: translate messages
		    $self->{TRANSPORT}->write(
			$self->{SERIALIZATION}->serialize(
			    $result));

		    next MESSAGE;
		}
	    }

	    $self->{TRANSPORT}->write(
		$self->{SERIALIZATION}->serialize(
		    $self->__get_error(
			{
			    ERROR => "I18N_OPENXPKI_SERVICE_DEFAULT_RUN_UNRECOGNIZED_COMMAND",
			})));

	    next MESSAGE;
	}


	$self->{TRANSPORT}->write(
	    $self->{SERIALIZATION}->serialize(
		$self->__get_error(
		    {
			ERROR => "I18N_OPENXPKI_SERVICE_DEFAULT_RUN_UNRECOGNIZED_SERVICE_MESSAGE",
		    })));
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

    my $msg;
  GET_AUTH_STACK:
    while (1) {
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
	$msg = $self->{SERIALIZATION}->deserialize
	    (
	     $self->{TRANSPORT}->read()
	    );
	if (exists $msg->{AUTHENTICATION_STACK}
	    && exists $keys->{STACKS}->{$msg->{AUTHENTICATION_STACK}}) {
	    last GET_AUTH_STACK;
	}
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
	my $error = 'I18N_OPENXPKI_SERVICE_DEFAULT_GET_PASSWD_LOGIN_MISSING_LOGIN';
	$self->{TRANSPORT}->write(
	    $self->{SERIALIZATION}->serialize(
		$self->__get_error(
		    {
			ERROR => $error,
		    })));

	OpenXPKI::Exception->throw
	    (
	     message => $error,
	     params  => $keys,
	    );
    }
    if (not exists $msg->{PASSWD})
    {
	my $error = 'I18N_OPENXPKI_SERVICE_DEFAULT_GET_PASSWD_LOGIN_MISSING_PASSWD';
	$self->{TRANSPORT}->write(
	    $self->{SERIALIZATION}->serialize(
		$self->__get_error(
		    {
			ERROR => $error,
		    })));

	OpenXPKI::Exception->throw
	    (
	     message => $error,
	     params  => $keys,
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

=item * new

=item * init

=item * run

=item * get_authentication_stack

=item * get_passwd_login

=item * __get_error

Expects named arguments 'ERROR' (required) and 'PARAMS' (optional).
ERROR must be a scalar indicating an I18N message, PARAMS are optional
variables (just like params in OpenXPKI Exceptions).

Returns a hash reference containing the original named parameters ERROR and
PARAMS (if specified) the corresponding i18n translation (in ERROR_MESSAGE).

Throws an exception if named argument ERROR is not a scalar.

=back
