## OpenXPKI::Service::Default.pm 
##
## Written 2005-2006 by Michael Bell and Martin Bartosch for the OpenXPKI project
## Polished to use a state-machine like interface 2007 by Alexander Klink
## for the OpenXPKI project
## (C) Copyright 2005-2007 by The OpenXPKI Project

package OpenXPKI::Service::Default;

use base qw( OpenXPKI::Service );

use strict;
use warnings;
use utf8;
use English;
use List::Util qw( first );

use Class::Std;

use Data::Dumper;

## used modules

use OpenXPKI::i18n qw(set_language);
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server;
use OpenXPKI::Server::Session;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Service::Default::Command;

my %state_of :ATTR;                # the current state of the service
        
sub init {
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
    
    $state_of{$ident} = 'NEW';

    # do session init, PKI realm selection and authentication
    while ($state_of{$ident} ne 'MAIN_LOOP') {
        my $msg = $self->collect();
        my $is_valid = $self->__is_valid_message({
            MESSAGE => $msg,
        });
        if (! $is_valid) {
	    $self->__send_error({
	        ERROR => "I18N_OPENXPKI_SERVICE_DEFAULT_RUN_UNRECOGNIZED_SERVICE_MESSAGE",
	    });
        }
        else { # valid message received
            my $result;
            eval { # try to handle it
                $result = $self->__handle_message({
                    MESSAGE => $msg
                });
            };
            if (my $exc = OpenXPKI::Exception->caught()) {
                $self->__send_error({
                    EXCEPTION => $exc,
                });
            }
            elsif ($EVAL_ERROR) {
	        $self->__send_error({
	            ERROR     => $EVAL_ERROR,
	        });
            }
            else { # if everything was fine, send the result to the client
                $self->talk($result);
            }
        }
    }

    return 1;
}

sub __is_valid_message : PRIVATE {
    my $self    = shift;
    my $ident   = ident $self;
    my $arg_ref = shift;
    my $message = $arg_ref->{'MESSAGE'};
    my $message_name = $message->{'SERVICE_MSG'};

    ##! 32: 'message_name: ' . $message_name
    ##! 32: 'state: ' . $state_of{$ident}
    
    # this is a table of valid messages that may be received from the
    # client in the different states
    my $valid_messages = {
        'NEW' => [
            'PING',
            'CONTINUE_SESSION',
            'NEW_SESSION',
        ],
        'SESSION_ID_SENT' => [
            'PING',
            'SESSION_ID_ACCEPTED',
            'CONTINUE_SESSION',
        ],
        'SESSION_ID_SENT_FROM_CONTINUE' => [
            'PING',
            'SESSION_ID_ACCEPTED',
            'CONTINUE_SESSION',
        ],
        'WAITING_FOR_PKI_REALM' => [
            'PING',
            'GET_PKI_REALM',
            'CONTINUE_SESSION',
        ],
        'WAITING_FOR_AUTHENTICATION_STACK' => [
            'PING',
            'GET_AUTHENTICATION_STACK',
            'CONTINUE_SESSION',
        ],
        'WAITING_FOR_LOGIN' => [
            'PING',
            'GET_PASSWD_LOGIN',
            'GET_CLIENT_SSO_LOGIN',
            'GET_CLIENT_X509_LOGIN',
            'GET_X509_LOGIN',
            'CONTINUE_SESSION',
        ],
        'MAIN_LOOP' => [
            'PING',
            'LOGOUT',
            'STATUS',
            'COMMAND',
            'CONTINUE_SESSION',
        ],
    };
    
    my @valid_msgs_now = @{ $valid_messages->{$state_of{$ident}} };
    if (defined first { $_ eq $message_name } @valid_msgs_now) {
        # TODO - once could possibly check the content of the message
        # here, too
        ##! 16: 'message is valid'
        return 1;
    }
    ##! 16: 'message is NOT valid'
    return;
} 
    
sub __handle_message : PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $arg_ref = shift;
    my $message = $arg_ref->{'MESSAGE'};
    my $message_name = $message->{'SERVICE_MSG'};

    ##! 64: 'message: ' . Dumper $message

    my $result;
    # get the result from a method specific to the message name
    eval {
        my $method = '__handle_' . $message_name;
        $result = $self->$method($message);
    };
    if (my $exc = OpenXPKI::Exception->caught()) {
        $exc->rethrow();
    }
    elsif ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVICE_DEFAULT_HANDLE_MESSAGE_FAILED',
            params  => {
                'MESSAGE_NAME' => $message_name,
                'EVAL_ERROR'   => $EVAL_ERROR,
            },
        );
    }

    return $result;
}

sub __handle_NEW_SESSION : PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $msg     = shift;

    ##! 4: "new session"
    my $session = OpenXPKI::Server::Session->new({
                       DIRECTORY => CTX('xml_config')->get_xpath
                                    (
                                        XPATH => "common/server/session_dir"
                                    ),
                       LIFETIME  => CTX('xml_config')->get_xpath
                                    (
                                        XPATH => "common/server/session_lifetime"
                                    ),
    });

    if (exists $msg->{LANGUAGE}) {
        ##! 8: "set language"
        set_language($msg->{LANGUAGE});
        $session->set_language($msg->{LANGUAGE});
    } else {
        ##! 8: "no language specified"
    }
    OpenXPKI::Server::Context::setcontext({'session' => $session});

    CTX('log')->log(
	MESSAGE  => 'New session created',
	PRIORITY => 'info',
	FACILITY => 'system',
	);

    $self->__change_state({
        STATE => 'SESSION_ID_SENT',
    });

    return {
        SESSION_ID => $session->get_id(),
    };
}

sub __handle_CONTINUE_SESSION {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $msg     = shift;

    my $session;

    ##! 4: "try to continue session"
    eval {
        $session = OpenXPKI::Server::Session->new({
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
	my $error = 'I18N_OPENXPKI_SERVICE_DEFAULT_HANDLE_CONTINUE_SESSION_SESSION_CONTINUE_FAILED';
	if (my $exc = OpenXPKI::Exception->caught()) {
		OpenXPKI::Exception->throw (
		    message  => $error,
		    params   => {ID => $msg->{SESSION_ID}},
		    children => [ $exc ]);
	} else {
	    OpenXPKI::Exception->throw(
		message => $error,
		params  => {ID => $msg->{SESSION_ID}}
	    );
	}
    }
    if (defined $session) {
        eval {
            my $s = CTX('session');
        };
        if ($EVAL_ERROR) {
            # session is not yet defined, set it
            OpenXPKI::Server::Context::setcontext({'session' => $session});
        }
        # do not use __change_state here, as we want to have access
        # to the old session in __handle_SESSION_ID_ACCEPTED
        $state_of{$ident} = 'SESSION_ID_SENT_FROM_CONTINUE';
		
        return {
            SESSION_ID => $session->get_id(),
        };
    }

    return;
}

sub __handle_PING : PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $message = shift;

    if ($state_of{$ident} eq 'MAIN_LOOP') {
        return {
            SERVICE_MSG => 'SERVICE_READY',
        };
    }
    elsif ($state_of{$ident} eq 'WAITING_FOR_PKI_REALM') {
        my %realms =();
        my @list = sort keys %{CTX('pki_realm')};
        foreach my $realm (@list) {
            $realms{$realm}->{NAME}        = $realm;
            ## FIXME: we should add a description to every PKI realm
            $realms{$realm}->{DESCRIPTION} = $realm;
        }
        return {
	    SERVICE_MSG => 'GET_PKI_REALM',
	    PARAMS => {
		    'PKI_REALMS' => \%realms,
	    },
        };
    }
    elsif ($state_of{$ident} eq 'WAITING_FOR_AUTHENTICATION_STACK') {
        return $self->__list_authentication_stacks();
    }
    elsif ($state_of{$ident} eq 'WAITING_FOR_LOGIN') {
        ##! 16: 'we are in state WAITING_FOR_LOGIN'
        ##! 16: 'auth stack: ' . CTX('session')->get_authentication_stack()
        ##! 16: 'pki realm: ' . CTX('session')->get_pki_realm()
        my ($user, $role, $reply) = CTX('authentication')->login_step({
            STACK   => CTX('session')->get_authentication_stack(),
            MESSAGE => $message,
        });
        return $reply;
    }
    return {};
}

sub __handle_SESSION_ID_ACCEPTED : PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $message = shift;

    if ($state_of{$ident} eq 'SESSION_ID_SENT_FROM_CONTINUE') {
        ##! 4: 'existing session detected'
        $self->__change_state({
            STATE => CTX('session')->get_state(),
        });
    }
    ##! 16: 'state: ' . $state_of{$ident}
    my $pki_realm_choice = $self->__pki_realm_choice_available();
    ##! 16: 'pki_realm_choice: ' . $pki_realm_choice
    # if there is more than one PKI realm, send an appropriate
    # message for the user and set the state to
    # 'WAITING_FOR_PKI_REALM'
    # we only do this if we are in a 'SESSION_ID_SENT.*' state
    if ($pki_realm_choice
        && $state_of{$ident} =~ m{\A SESSION_ID_SENT.* \z}xms) {
        ##! 2: "build hash with ID, name and description"
        my %realms =();
        my @list = sort keys %{CTX('pki_realm')};
        foreach my $realm (@list) {
            $realms{$realm}->{NAME}        = $realm;
            ## FIXME: we should add a description to every PKI realm
            $realms{$realm}->{DESCRIPTION} = $realm;
        }
        $self->__change_state({
            STATE => 'WAITING_FOR_PKI_REALM',
        });
        return {
	    SERVICE_MSG => 'GET_PKI_REALM',
	    PARAMS => {
		    'PKI_REALMS' => \%realms,
	    },
        };
    }

    # if we do not have an authentication stack in the session,
    # send all available stacks to the user and set the state to
    # 'WAITING_FOR_AUTHENTICATION_STACK'
    if ($state_of{$ident} =~ m{\A SESSION_ID_SENT.* \z}xms
       && (! defined CTX('session')->get_authentication_stack()) ) {
        ##! 4: 'sending authentication stacks'
        $self->__change_state({
            STATE => 'WAITING_FOR_AUTHENTICATION_STACK',
        });
        return $self->__list_authentication_stacks();
    }

    if ($state_of{$ident} eq 'WAITING_FOR_AUTHENTICATION_STACK') {
        return $self->__list_authentication_stacks();
    }

    if ($state_of{$ident} eq 'WAITING_FOR_LOGIN') {
        ##! 16: 'we are in state WAITING_FOR_LOGIN'
        ##! 16: 'auth stack: ' . CTX('session')->get_authentication_stack()
        ##! 16: 'pki realm: ' . CTX('session')->get_pki_realm()
        my ($user, $role, $reply) = CTX('authentication')->login_step({
            STACK   => CTX('session')->get_authentication_stack(),
            MESSAGE => $message,
        });
        return $reply;
    }

    if ($state_of{$ident} eq 'MAIN_LOOP') {
        return {
            SERVICE_MSG => 'SERVICE_READY',
        };
    }
    ##! 16: 'end'
    return;
}

sub __handle_GET_PKI_REALM : PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $message = shift;

    my $requested_realm = $message->{PARAMS}->{'PKI_REALM'};

    if ($self->__is_valid_pki_realm($requested_realm)) {
        ##! 2: "update session with PKI realm"
        CTX('session')->set_pki_realm($requested_realm);
    }
    else {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVICE_DEFAULT_GET_PKI_REALM_INVALID_PKI_REALM_REQUESTED',
        );
    }

    if (! defined CTX('session')->get_authentication_stack() ) {
        $self->__change_state({
            STATE => 'WAITING_FOR_AUTHENTICATION_STACK',
        });
        return $self->__list_authentication_stacks();
    }
    # check for next step, change state and prepare response
    return;
}

sub __handle_GET_AUTHENTICATION_STACK : PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $message = shift;

    my $requested_stack = $message->{PARAMS}->{'AUTHENTICATION_STACK'};
    if (! $self->__is_valid_auth_stack($requested_stack)) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVICE_DEFAULT_GET_AUTHENTICATION_STACK_INVALID_AUTH_STACK_REQUESTED',
        );
    }
    else { # valid authentication stack
        $self->__change_state({
            STATE => 'WAITING_FOR_LOGIN',
        });
        CTX('session')->start_authentication(); 
        CTX('session')->set_authentication_stack($requested_stack);
        my ($user, $role, $reply) = CTX('authentication')->login_step({
            STACK   => $requested_stack,
            MESSAGE => $message,
        });
        if (defined $user && defined $role) {
            ##! 4: 'login successful'
            # successful login, save it in the session
            # and make the session valid
            CTX('session')->set_user($user);
            CTX('session')->set_role($role);
            CTX('session')->make_valid();
            $self->__change_state({
                STATE => 'MAIN_LOOP',
            });
        }
        else {
            ##! 4: 'login unsuccessful'
        }
        return $reply;
    }

    return;
}

sub __handle_GET_PASSWD_LOGIN : PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $message = shift;

    ## do not let users with non-ASCII characters in their username
    ## log in, as this will cause a crash on the web interface. This
    ## is a known bug (#1909037), and this code is here as a workaround
    ## until it is fixed.
    if (exists $message->{PARAMS}->{LOGIN}) {
	if (! defined $message->{PARAMS}->{LOGIN}) {
	    OpenXPKI::Exception->throw(
		message => 'I18N_OPENXPKI_SERVICE_DEFAULT_GET_PASSWD_USERNAME_UNDEFINED',
		);
	}
	
	if ($message->{PARAMS}->{LOGIN} !~ m{ \A \p{IsASCII}+ \z }xms) {
	    OpenXPKI::Exception->throw(
		message => 'I18N_OPENXPKI_SERVICE_DEFAULT_GET_PASSWD_LOGIN_NON_ASCII_USERNAME_BUG',
		);
	}
    }

    my ($user, $role, $reply) = CTX('authentication')->login_step({
        STACK   => CTX('session')->get_authentication_stack(),
        MESSAGE => $message,
    });
    ##! 16: 'user: ' . $user
    ##! 16: 'role: ' . $role
    ##! 16: 'reply: ' . Dumper $reply
    if (defined $user && defined $role) {
        ##! 4: 'login successful'
        # successful login, save it in the session
        # and make the session valid
        CTX('session')->set_user($user);
        CTX('session')->set_role($role);
        CTX('session')->make_valid();
        $self->__change_state({
            STATE => 'MAIN_LOOP',
        });
    }
    else {
        ##! 4: 'login unsuccessful'
    }
    return $reply;
}

sub __handle_GET_CLIENT_SSO_LOGIN : PRIVATE {
    ##! 1: 'start'
    my $self = shift;
    my $msg  = shift;
    
    # SSO login is basically handled in the same way as password login
    return $self->__handle_GET_PASSWD_LOGIN($msg);
}

sub __handle_GET_CLIENT_X509_LOGIN : PRIVATE {
    ##! 1: 'start'
    my $self = shift;
    my $msg  = shift;
    
    # client X509 login is basically handled in the same way as password login
    return $self->__handle_GET_PASSWD_LOGIN($msg);
}

sub __handle_GET_X509_LOGIN : PRIVATE {
    ##! 1: 'start'
    my $self = shift;
    my $msg  = shift;

    # X509 login is handled the same as password login, too
    return $self->__handle_GET_PASSWD_LOGIN($msg);
}

sub __handle_LOGOUT : PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $message = shift;

    ##! 8: "logout received - killing session and connection"
    CTX('log')->log(
	MESSAGE  => 'Terminating session',
	PRIORITY => 'info',
	FACILITY => 'system',
    );
    CTX('session')->delete();
    exit 0;
}

sub __handle_STATUS : PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $message = shift;
    
    # SERVICE_MSG ? 
    return {
	SESSION => {
	    ROLE => $self->get_API('Session')->get_role(),
	    USER => $self->get_API('Session')->get_user(),
        },
    };
}

sub __handle_COMMAND : PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $data    = shift;

    if (exists $data->{PARAMS}->{COMMAND}) {
        ##! 16: "executing access control before doing anything else"
        eval {
            CTX('acl')->authorize ({
                    ACTIVITY      => "Service::".$data->{PARAMS}->{COMMAND},
                    AFFECTED_ROLE => "",
            });
        };
        if ($EVAL_ERROR) {
            ##! 1: "Permission denied for Service::".$data->{PARAMS}->{COMMAND}."."
            if (my $exc = OpenXPKI::Exception->caught()) {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVICE_DEFAULT_COMMAND_PERMISSION_DENIED',
                    params  => {
                        EXCEPTION => $exc,
                    },
                );
            } else {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVICE_DEFAULT_COMMAND_PERMISSION_DENIED',
                    params  => {
                        ERROR => $EVAL_ERROR,
                    },
                );
            }
            return;
        }
        ##! 16: "access to command granted"

	my $command;
	eval {
	    $command = OpenXPKI::Service::Default::Command->new({
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
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVICE_DEFAULT_COMMAND_COULD_NOT_INSTANTIATE_COMMAND",
		params  => {
		    EVAL_ERROR => $EVAL_ERROR,
		},
                );
	}
        ##! 16: 'command class instantiated successfully'

	if (defined $command) {
	    my $result;
	    eval {
		$result = $command->execute();
	    };
            if (my $exc = OpenXPKI::Exception->caught()) {
                ##! 16: 'exception caught during execute'
                $exc->rethrow();
            }
	    elsif ($EVAL_ERROR) {
		##! 14: "Exception caught during command execution"
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVICE_DEFAULT_COMMAND_EXECUTION_ERROR',
                    params => {
                        ERROR => $EVAL_ERROR,
                    },
                );
                return;
	    }

            ##! 16: 'command executed successfully'
	    # sanity checks on command reply
	    if (! defined $result || ref $result ne 'HASH') {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVICE_DEFAULT_COMMAND_ILLEGAL_COMMAND_RETURN_VALUE',
                );
                return;
            }
            ##! 16: 'returning result'
            return $result;
        }
    }
    else {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVICE_DEFAULT_COMMAND_COMMAND_MISSING',
        );
    }
    return;
}

sub __pki_realm_choice_available : PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;

    ##! 2: "check if PKI realm is already known"
    my $realm;
    eval {
	$realm = $self->get_API('Session')->get_pki_realm();
    };
    return $realm if defined $realm;

    ##! 2: "check if there is more than one realm"
    my @list = sort keys %{CTX('pki_realm')};
    if (scalar @list < 1) {
        ##! 4: "no PKI realm configured"
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVICE_DEFAULT_NO_PKI_REALM_CONFIGURED",
        );
    }
    elsif (scalar @list == 1) {
        ##! 4: "update session with PKI realm"
        ##! 16: 'PKI realm: ' . $list[0]
        CTX('session')->set_pki_realm($list[0]);
        return 0;
    }
    else { # more than one PKI realm available
        return 1;
    }
    
    return 0;
}

sub __list_authentication_stacks : PRIVATE {
    my $self = shift;

    my $authentication = CTX('authentication');
    return {
        SERVICE_MSG => 'GET_AUTHENTICATION_STACK',
        PARAMS => {
            'AUTHENTICATION_STACKS' => $authentication->list_authentication_stacks(),
        },
    };
}

sub __is_valid_auth_stack : PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $stack   = shift;

    my $stacks = CTX('authentication')->list_authentication_stacks();
    return exists $stacks->{$stack};
}

sub __is_valid_pki_realm : PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $realm   = shift;

    return exists CTX('pki_realm')->{$realm};
}

sub __change_state : PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $arg_ref = shift;
    my $new_state = $arg_ref->{STATE};

    ##! 4: 'changing state from ' . $state_of{$ident} . ' to ' . $new_state
    CTX('log')->log(
	MESSAGE  => 'Changing session state from ' . $state_of{$ident} . ' to ' . $new_state,
	PRIORITY => 'debug',
	FACILITY => 'system',
	);
    $state_of{$ident} = $new_state;
    # save the new state in the session
    CTX('session')->set_state($new_state);

    return 1;
} 

sub run
{
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

    $SIG{'TERM'} = \&OpenXPKI::Server::sig_term;
  MESSAGE:
    while (1) {
        my $msg;
        eval {
            $msg = $self->collect();
        };
        if (my $exc = OpenXPKI::Exception->caught()) {
	    if ($exc->message() =~ m{I18N_OPENXPKI_TRANSPORT.*CLOSED_CONNECTION}xms) {
		# client closed socket
		last MESSAGE;
	    } else {
		$exc->rethrow();
	    }
	} elsif ($EVAL_ERROR) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVICE_DEFAULT_RUN_READ_EXCEPTION",
		params  => {
		    EVAL_ERROR => $EVAL_ERROR,
		});
	}

	last MESSAGE unless defined $msg;

        my $is_valid = $self->__is_valid_message({
            MESSAGE => $msg,
        });
        if (! $is_valid) {
	    $self->__send_error({
	        ERROR => "I18N_OPENXPKI_SERVICE_DEFAULT_RUN_UNRECOGNIZED_SERVICE_MESSAGE",
	    });
        }
        else { # valid message received
            my $result;
            if (! CTX('session')->is_valid()) {
                # check whether we still have a valid session (someone
                # might have logged out on a different forked server)
                $self->__send_error({
                    ERROR => 'I18N_OPENXPKI_SERVICE_DEFAULT_RUN_SESSION_INVALID',
                });
            }
            else {
                # our session is just fine
                eval { # try to handle it
                    $result = $self->__handle_message({
                        MESSAGE => $msg
                    });
                };
                if (my $exc = OpenXPKI::Exception->caught()) {
                    $self->__send_error({
                        EXCEPTION => $exc,
                    });
                }
                elsif ($EVAL_ERROR) {
                $self->__send_error({
                    ERROR     => $EVAL_ERROR,
                });
                }
                else { # if everything was fine, send the result to the client
                    $self->talk($result);
                }
            }
        }
    }
    return 1;
}
	
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

Receives messages, checks them for validity in the given state
and passes them of to __handle_message if they are valid. Runs
until it reaches the state 'MAIN_LOOP', which means that session
initialization, PKI realm selection and login are done.

=item * run

Receives messages, checks them for validity in the given state
(MAIN_LOOP) and passes them to __handle_message if they are valid.
Runs until a LOGOUT command is received.

=item * __is_valid_message

Checks whether a given message is a valid message in the current
state. Currently, this checks the message name ('SERVICE_MSG')
only, could be used to validate the input as well later.

=item * __handle_message

Handles a message by passing it off to a handler named using the
service message name.

=item * __handle_NEW_SESSION

Handles the NEW_SESSION message by creating a new session, saving it
in the context and sending back the session ID. Changes the state to
'SESSION_ID_ACCEPTED'

=item * __handle_CONTINUE_SESSION

Handles the CONTINUE_SESSION message.

=item * __handle_PING

Handles the PING message by sending back an empty response.

=item * __handle_SESSION_ID_ACCEPTED

Handles the 'SESSION_ID_ACCEPTED' message. It looks whether there
are multiple PKI realms defined. If so, it sends back the list
and changes to state 'WAITING_FOR_PKI_REALM'. If not, it looks
whether an authentication stack is present. If not, it sends the
list of possible stacks and changes the state to
'WAITING_FOR_AUTHENTICATION_STACK'. 

=item * __handle_GET_PKI_REALM

Handles the GET_PKI_REALM message by checking whether the received
realm is valid and setting it in the context if so.

=item * __handle_GET_AUTHENTICATION_STACK

Handles the GET_AUTHENTICATION_STACK message by checking whether
the received stack is valid and setting the corresponding attribute
if it is

=item * __handle_GET_PASSWD_LOGIN

Handles the GET_PASSWD_LOGIN message by passing on the credentials
to the Authentication modules 'login_step' method.

=item * __handle_LOGOUT

Handles the LOGOUT message by logging the logout and exiting.

=item * __handle_STATUS

Handles the STATUS message by sending back role and user information.

=item * __handle_COMMAND

Handles the COMMAND message by calling the corresponding command if
the user is authorized.

=item * __pki_realm_choice_available

Checks whether more than one PKI realm is configured.

=item * __list_authentication_stacks

Returns a list of configured authentication stacks.

=item * __is_valid_auth_stack

Checks whether a given stack is a valid one.

=item * __is_valid_pki_realm

Checks whether a given realm is a valid one.

=item * __change_state

Changes the internal state.

=item * __send_error

Sends an error message to the user.

=back
