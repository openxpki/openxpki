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

use Sys::SigAction qw( sig_alarm set_sig_handler );

use Data::Dumper;

## used modules

use OpenXPKI::i18n qw(set_language);
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server;
use OpenXPKI::Server::Session;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Service::Default::CommandApi2;
use Log::Log4perl::MDC;


my %state_of :ATTR;     # the current state of the service

my %max_execution_time  : ATTR( :set<max_execution_time> );

sub init {
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

    ##! 1: "start"

    # timeout idle clients
    my $timeout = CTX('config')->get("system.server.service.Default.idle_timeout") || 120;

    $self->set_timeout($timeout);

    my $max_execution_time = CTX('config')->get("system.server.service.Default.max_execution_time") || 0;
    $self->set_max_execution_time($max_execution_time);

    $state_of{$ident} = 'NEW';

    # in case we reuse a child in PreFork mode make sure there is
    # no session left in context
    OpenXPKI::Server::Context::killsession();

    # TODO - this should be handled by the run method after some cleanup
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
                $result = $self->__handle_message({ MESSAGE => $msg });
                # persist session unless it was killed (we assume someone saved it before)
                CTX('session')->persist if OpenXPKI::Server::Context::hascontext('session');
            };
            if (my $exc = OpenXPKI::Exception->caught()) {
                $self->__send_error({ EXCEPTION => $exc });
            }
            elsif ($EVAL_ERROR) {
                $self->__send_error({ EXCEPTION => $EVAL_ERROR });
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
            'DETACH_SESSION',
        ],
        'SESSION_ID_SENT' => [
            'PING',
            'SESSION_ID_ACCEPTED',
            'CONTINUE_SESSION',
            'DETACH_SESSION',
        ],
        'SESSION_ID_SENT_FROM_CONTINUE' => [
            'PING',
            'SESSION_ID_ACCEPTED',
            'CONTINUE_SESSION',
            'DETACH_SESSION',
        ],
        'SESSION_ID_SENT_FROM_RESET' => [
            'PING',
            'SESSION_ID_ACCEPTED',
            'CONTINUE_SESSION',
            'DETACH_SESSION',
        ],
        'WAITING_FOR_PKI_REALM' => [
            'PING',
            'LOGOUT',
            'GET_PKI_REALM',
            'NEW_SESSION',
            'CONTINUE_SESSION',
            'DETACH_SESSION',
        ],
        'WAITING_FOR_AUTHENTICATION_STACK' => [
            'PING',
            'LOGOUT',
            'GET_AUTHENTICATION_STACK',
            'NEW_SESSION',
            'CONTINUE_SESSION',
            'DETACH_SESSION',
        ],
        'WAITING_FOR_LOGIN' => [
            'PING',
            'LOGOUT',
            'GET_PASSWD_LOGIN',
            'GET_CLIENT_SSO_LOGIN',
            'GET_CLIENT_X509_LOGIN',
            'GET_X509_LOGIN',
            'NEW_SESSION',
            'CONTINUE_SESSION',
            'DETACH_SESSION',
        ],
        'MAIN_LOOP' => [
            'PING',
            'LOGOUT',
            'STATUS',
            'COMMAND',
            'NEW_SESSION',
            'CONTINUE_SESSION',
            'DETACH_SESSION',
            'RESET_SESSIONID',
        ],
    };

    my @valid_msgs_now = @{ $valid_messages->{$state_of{$ident}} };
    if (defined first { $_ eq $message_name } @valid_msgs_now) {
        # TODO - once could possibly check the content of the message
        # here, too
        ##! 16: 'message is valid'
        return 1;
    }

    CTX('log')->system()->warn('Invalid message '.$message_name.' recevied in state ' . $state_of{$ident});

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
        CTX('log')->system->trace("<< $message_name (message from client)");
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

    Log::Log4perl::MDC->put('sid', undef);

    ##! 4: "new session"
    my $session = OpenXPKI::Server::Session->new(load_config => 1)->create;

    if (exists $msg->{LANGUAGE}) {
        ##! 8: "set language"
        set_language($msg->{LANGUAGE});
        $session->data->language($msg->{LANGUAGE});
    } else {
        ##! 8: "no language specified"
    }

    OpenXPKI::Server::Context::setcontext({'session' => $session, force => 1});
    Log::Log4perl::MDC->put('sid', substr($session->data->id,0,4));
    CTX('log')->system->info('New session created');

    $self->__change_state({ STATE => 'SESSION_ID_SENT', });

    return {
        SESSION_ID => $session->data->id,
    };
}

sub __handle_CONTINUE_SESSION {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $msg     = shift;

    my $session;

    # for whatever reason prior to the Client rewrite continue_session
    # has the session id not in params
    my $sess_id = exists $msg->{SESSION_ID} ? $msg->{SESSION_ID} : $msg->{PARAMS}->{SESSION_ID};

    ##! 4: "try to continue session " . $sess_id
    $session = OpenXPKI::Server::Session->new(load_config => 1);
    $session->resume($sess_id)
        or OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVICE_DEFAULT_HANDLE_CONTINUE_SESSION_SESSION_CONTINUE_FAILED',
            params  => {ID => $sess_id}
        );

    # There might be an exisiting session if the child did some work before
    # we therefore use force to overwrite exisiting entries
    OpenXPKI::Server::Context::setcontext({'session' => $session, force => 1});
    Log::Log4perl::MDC->put('sid', substr($sess_id,0,4));
    CTX('log')->system->debug('Session resumed');

    # do not use __change_state here, as we want to have access
    # to the old session in __handle_SESSION_ID_ACCEPTED
    $state_of{$ident} = 'SESSION_ID_SENT_FROM_CONTINUE';

    return {
        SESSION_ID => $session->data->id,
    };
}

sub __handle_RESET_SESSIONID: PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $msg     = shift;

    my $sess_id = CTX('session')->new_id;
    CTX('log')->system->debug("Changing session ID to ".substr($sess_id,0,4));
    Log::Log4perl::MDC->put('sid', substr($sess_id,0,4));

    ##! 4: 'new session id ' . $sess_id

    $self->__change_state({
        STATE => 'SESSION_ID_SENT_FROM_RESET',
    });

    return {
        SESSION_ID => $sess_id,
    };

}

sub __handle_DETACH_SESSION: PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $msg     = shift;

    my $sessid = CTX('session')->data->id;
    ##! 4: "detach session " . $sessid
    OpenXPKI::Server::Context::killsession();
    # Cleanup ALL items from the MDC!
    Log::Log4perl::MDC->remove();

    $self->__change_state({ STATE => 'NEW' });

    return { 'SERVICE_MSG' => 'DETACH' };
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
        my @realm_names = CTX('config')->get_keys("system.realms");
        my %realms =();
        foreach my $realm (sort @realm_names) {
            my $label = CTX('config')->get("system.realms.$realm.label");
            $realms{$realm}->{NAME} = $realm;
            $realms{$realm}->{LABEL} = $label;
            $realms{$realm}->{DESCRIPTION} = CTX('config')->get("system.realms.$realm.description") || $label;
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
        ##! 16: 'auth stack: ' . CTX('session')->data->authentication_stack
        ##! 16: 'pki realm: ' . CTX('session')->data->pki_realm
        my ($user, $role, $reply) = CTX('authentication')->login_step({
            STACK   => CTX('session')->data->authentication_stack,
            MESSAGE => $message,
        });
        return $reply;
    }
    return { SERVICE_MSG => 'START_SESSION' };
}

sub __handle_SESSION_ID_ACCEPTED : PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $message = shift;

    if ($state_of{$ident} eq 'SESSION_ID_SENT_FROM_RESET') {
        ##! 4: 'existing session detected'
        my $session = CTX('session');
        ##! 8: 'Session ' . Dumper $session
        $self->__change_state({
            STATE => 'MAIN_LOOP',
        });
    }

    if ($state_of{$ident} eq 'SESSION_ID_SENT_FROM_CONTINUE') {
        ##! 4: 'existing session detected'
        my $session = CTX('session');
        ##! 8: 'Session ' . Dumper $session
        $self->__change_state({
            STATE => CTX('session')->data->status,
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
        my @realm_names = CTX('config')->get_keys("system.realms");
        my %realms =();
        foreach my $realm (sort @realm_names) {
            $realms{$realm}->{NAME} = $realm;
            $realms{$realm}->{DESCRIPTION} = CTX('config')->get("system.realms.$realm.label");
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
       && (! defined CTX('session')->data->authentication_stack) ) {
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
        ##! 16: 'auth stack: ' . CTX('session')->data->authentication_stack
        ##! 16: 'pki realm: ' . CTX('session')->data->pki_realm
        my ($user, $role, $reply) = CTX('authentication')->login_step({
            STACK   => CTX('session')->data->authentication_stack,
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
        CTX('session')->data->pki_realm($requested_realm);
        Log::Log4perl::MDC->put('pki_realm', $requested_realm);
    }
    else {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVICE_DEFAULT_GET_PKI_REALM_INVALID_PKI_REALM_REQUESTED',
        );
    }

    if (! defined CTX('session')->data->authentication_stack ) {
        $self->__change_state({
            STATE => 'WAITING_FOR_AUTHENTICATION_STACK',
        });
        # proceed if stack is already set
        if (defined $message->{PARAMS}->{'AUTHENTICATION_STACK'}) {
            delete $message->{PARAMS}->{'PKI_REALM'};
            return $self->__handle_GET_AUTHENTICATION_STACK($message);
        }
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
        CTX('session')->data->authentication_stack($requested_stack);
        my ($user, $role, $reply, $userinfo) = CTX('authentication')->login_step({
            STACK   => $requested_stack,
            MESSAGE => $message,
        });
        if (defined $user && defined $role) {
            ##! 4: 'login successful'
            # successful login, save it in the session
            # and make the session valid
            CTX('session')->data->user($user);
            CTX('session')->data->role($role);
            CTX('session')->data->userinfo($userinfo) if ($userinfo);

            CTX('session')->is_valid(1); # mark session as "valid"

            Log::Log4perl::MDC->put('user', $user);
            Log::Log4perl::MDC->put('role', $role);

            $self->__change_state({ STATE => 'MAIN_LOOP', });
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

    my ($user, $role, $reply, $userinfo) = CTX('authentication')->login_step({
        STACK   => CTX('session')->data->authentication_stack,
        MESSAGE => $message,
    });
    ##! 16: 'user: ' . $user
    ##! 16: 'role: ' . $role
    ##! 16: 'reply: ' . Dumper $reply
    if (defined $user && defined $role) {
        CTX('log')->system->debug("Successful login from user $user, role $role");
        ##! 4: 'login successful'
        # successful login, save it in the session and mark session as valid
        CTX('session')->data->user($user);
        CTX('session')->data->role($role);
        CTX('session')->data->userinfo($userinfo) if ($userinfo);

        CTX('session')->is_valid(1);

        Log::Log4perl::MDC->put('user', $user);
        Log::Log4perl::MDC->put('role', $role);

        $self->__change_state({ STATE => 'MAIN_LOOP', });
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

    my $old_session = CTX('session');

    ##! 8: "logout received - terminate session " . $old_session->id,
    CTX('log')->system->debug('Terminating session ' . $old_session->id);

    $self->__change_state({ STATE => 'NEW' });

    OpenXPKI::Server::Context::killsession();

    Log::Log4perl::MDC->remove();

    if (!$old_session->delete()) {
        CTX('log')->system->warn('Error terminating session!');
    }

    return { 'SERVICE_MSG' => 'LOGOUT' };
}

sub __handle_STATUS : PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $message = shift;

    # closure to access session parameters or return undef if CTX('session') is not defined
    my $session_param = sub {
        my $param = shift;
        return CTX('session')->data->$param if OpenXPKI::Server::Context::hascontext('session');
        return undef;
    };
    # SERVICE_MSG ?
    return {
        SESSION => {
            ROLE => $session_param->("role"),
            USER => $session_param->("user"),
        },
    };
}

sub __handle_COMMAND : PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $data    = shift;

    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVICE_DEFAULT_COMMAND_COMMAND_MISSING',
    ) unless exists $data->{PARAMS}->{COMMAND};

    ##! 16: "executing access control before doing anything else"
    #eval {
        # FIXME - ACL
        #CTX('acl')->authorize ({
        #        ACTIVITY      => "Service::".$data->{PARAMS}->{COMMAND},
        #        AFFECTED_ROLE => "",
        #});
    #};
    ##! 32: 'Callstack ' . Dumper $data
    if (0 || $EVAL_ERROR) {
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
    my $api = $data->{PARAMS}->{API} || 2;
    if ($api !~ /^2$/) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVICE_DEFAULT_COMMAND_UNKNWON_COMMAND_API_VERSION",
            params  => $data->{PARAMS},
        );
    }

    eval {
        $command = OpenXPKI::Service::Default::CommandApi2->new(
            command => $data->{PARAMS}->{COMMAND},
            params  => $data->{PARAMS}->{PARAMS},
        );
    };
    if (my $exc = OpenXPKI::Exception->caught()) {
        if ($exc->message() =~ m{ I18N_OPENXPKI_SERVICE_DEFAULT_COMMAND_INVALID_COMMAND }xms) {
            ##! 16: "Invalid command $data->{PARAMS}->{COMMAND}"
            # fall-through intended
        } else {
            $exc->rethrow();
        }
    }
    elsif ($EVAL_ERROR) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVICE_DEFAULT_COMMAND_COULD_NOT_INSTANTIATE_COMMAND",
            params  => { EVAL_ERROR => $EVAL_ERROR },
        );
    }
    return unless defined $command;

    ##! 16: 'command class instantiated successfully'
    my $result;
    eval {
        CTX('log')->system->debug("Executing command ".$data->{PARAMS}->{COMMAND});

        my $sh;
        if ($max_execution_time{$ident}) {
            $sh = set_sig_handler( 'ALRM' ,sub {
                CTX('log')->system->error("Service command ".$data->{PARAMS}->{COMMAND}." was aborted after " . $max_execution_time{$ident});
                CTX('log')->system->trace("Call was " . Dumper $data->{PARAMS} );
                OpenXPKI::Exception->throw(
                    message => "Server took too long to respond to your request - aborted!",
                    params => {
                        COMMAND => $data->{PARAMS}->{COMMAND}
                    }
                );
            });
            sig_alarm( $max_execution_time{$ident} );
        }

        # enclose command with DBI transaction
        CTX('dbi')->start_txn();
        $result = $command->execute();
        CTX('dbi')->commit();

        if ($sh) {
            sig_alarm(0);
        }
    };

    if (my $error = $EVAL_ERROR) {
        # rollback DBI (should not matter as we throw exception anyway)
        CTX('dbi')->rollback();

        # just rethrow if we have an exception
        if (my $exc = OpenXPKI::Exception->caught()) {
            ##! 16: 'exception caught during execute'
            $exc->rethrow();
        }

        ##! 16: "Exception caught during command execution"
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVICE_DEFAULT_COMMAND_EXECUTION_ERROR',
            params => { ERROR => $error },
        );
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

sub __pki_realm_choice_available : PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;

    ##! 2: "check if PKI realm is already known"
    my $realm = OpenXPKI::Server::Context::hascontext('session')
        ? CTX('session')->data->pki_realm
        : undef;
    return $realm if defined $realm;

    ##! 2: "check if there is more than one realm"

    my @list = CTX('config')->get_keys('system.realms');
    if (scalar @list < 1) {
        ##! 4: "no PKI realm configured"
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVICE_DEFAULT_NO_PKI_REALM_CONFIGURED",
        );
    }
    elsif (scalar @list == 1) {
        ##! 4: "update session with PKI realm"
        ##! 16: 'PKI realm: ' . $list[0]
        CTX('session')->data->pki_realm($list[0]);
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

    return CTX('config')->exists("system.realms.$realm");
}

sub __change_state : PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $arg_ref = shift;
    my $new_state = $arg_ref->{STATE};

    ##! 4: 'changing state from ' . $state_of{$ident} . ' to ' . $new_state
    CTX('log')->system()->debug('Changing session state from ' . $state_of{$ident} . ' to ' . $new_state);

    $state_of{$ident} = $new_state;
    # save the new state in the session
    if (OpenXPKI::Server::Context::hascontext('session')) {
        CTX('session')->data->status($new_state);
    }

    # Set the daemon name after enterin MAIN_LOOP

    if ($new_state eq "MAIN_LOOP") {
        OpenXPKI::Server::__set_process_name("worker: %s (%s)", CTX('session')->data->user, CTX('session')->data->role);
    } elsif ($new_state eq "NEW") {
        OpenXPKI::Server::__set_process_name("worker: connected");
    }

    return 1;
}

sub run
{
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

    $SIG{'TERM'} = \&OpenXPKI::Server::sig_term;
    $SIG{'HUP'} = \&OpenXPKI::Server::sig_hup;
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

        my $is_valid = $self->__is_valid_message({ MESSAGE => $msg });
        if (! $is_valid) {
            CTX('log')->system->debug("Invalid message received from client: ".($msg->{SERVICE_MSG} // "(empty)"));
            $self->__send_error({
                ERROR => "I18N_OPENXPKI_SERVICE_DEFAULT_RUN_UNRECOGNIZED_SERVICE_MESSAGE",
            });
        }
        else { # valid message received
            my $result;
            # we dont need a valid session when we are not in main loop state
            if ($state_of{$ident} eq 'MAIN_LOOP' && ! CTX('session')->is_valid) {
                # check whether we still have a valid session (someone
                # might have logged out on a different forked server)
                CTX('log')->system->debug("Can't process client message: session is not valid (login incomplete)");
                $self->__send_error({
                    ERROR => 'I18N_OPENXPKI_SERVICE_DEFAULT_RUN_SESSION_INVALID',
                });
            }
            else {
                # our session is just fine
                eval { # try to handle it
                    $result = $self->__handle_message({ MESSAGE => $msg });
                    # persist session unless it was killed (we assume someone saved it before)
                    CTX('session')->persist if OpenXPKI::Server::Context::hascontext('session');
                };
                if (my $exc = OpenXPKI::Exception->caught()) {
                    $self->__send_error({ EXCEPTION => $exc, });
                }
                elsif ($EVAL_ERROR) {
                    $self->__send_error({ EXCEPTION => $EVAL_ERROR, });
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

    my $error;
    if ($params->{ERROR}) {
        $error = { LABEL => $params->{ERROR} };
    } elsif (ref $params->{EXCEPTION} eq '') {
        # got exception with already stringified error
        $error = { LABEL => $params->{EXCEPTION} };
    } else {
        # blessed exception object - there are some bubble ups where message
        # is an exception again => enforce stringification on message
        $error = { LABEL => "".$params->{EXCEPTION}->message() };

        # get all scalar/hash/array parameters from OXI::Exceptions
        # this is used to transport some extra infos for validators, etc
        if (ref $params->{EXCEPTION} eq 'OpenXPKI::Exception' &&
            defined $params->{EXCEPTION}->params) {
            my $p = $params->{EXCEPTION}->params;
            map {
                my $key = $_;
                my $val = $p->{$_};
                my $ref = ref $val;
                delete $p->{$_} unless(defined $val && $ref =~ /^(|HASH|ARRAY)$/);
            } keys %{$p};

            if($p) {
                $error->{PARAMS} = $p;
            }
        }
    }

    CTX('log')->system->debug('Sending error ' . Dumper $error);

    return $self->talk({
        SERVICE_MSG => "ERROR",
        LIST        => [ $error ]
    });
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

=item * __handle_DETACH

Removes the current session from this worker but does not delete
the session. The worker is now free to handle requests for other
sessions.

=item * __handle_LOGOUT

Handles the LOGOUT message by deleting the session from the backend.

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
