package OpenXPKI::Service::Default;
use OpenXPKI -class_std;

use parent qw( OpenXPKI::Service );

use List::Util qw( first );
use Sys::SigAction qw( sig_alarm set_sig_handler );
use Log::Log4perl::MDC;
use Data::UUID;

use OpenXPKI::i18n qw(set_language);
use OpenXPKI::Server;
use OpenXPKI::Server::Session;
use OpenXPKI::Server::Context qw( CTX );


my %state_of :ATTR;     # the current state of the service

my %max_execution_time  : ATTR( :set<max_execution_time> );

my %api :ATTR; # API instance

my $UUID = Data::UUID->new;

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
            'GET_LOGOUT_MENU',
            'LOGOUT',
            'CONTINUE_SESSION',
            'NEW_SESSION',
            'DETACH_SESSION',
            'GET_ENDPOINT_CONFIG',
            'GET_REALM_LIST',
        ],
        'SESSION_ID_SENT' => [
            'PING',
            'GET_LOGOUT_MENU',
            'LOGOUT',
            'SESSION_ID_ACCEPTED',
            'CONTINUE_SESSION',
            'DETACH_SESSION',
        ],
        'SESSION_ID_SENT_FROM_CONTINUE' => [
            'PING',
            'GET_LOGOUT_MENU',
            'LOGOUT',
            'SESSION_ID_ACCEPTED',
            'CONTINUE_SESSION',
            'DETACH_SESSION',
        ],
        'SESSION_ID_SENT_FROM_RESET' => [
            'PING',
            'GET_LOGOUT_MENU',
            'LOGOUT',
            'SESSION_ID_ACCEPTED',
            'CONTINUE_SESSION',
            'DETACH_SESSION',
        ],
        'WAITING_FOR_PKI_REALM' => [
            'PING',
            'GET_LOGOUT_MENU',
            'LOGOUT',
            'GET_PKI_REALM',
            'NEW_SESSION',
            'CONTINUE_SESSION',
            'DETACH_SESSION',
        ],
        'WAITING_FOR_AUTHENTICATION_STACK' => [
            'PING',
            'GET_LOGOUT_MENU',
            'LOGOUT',
            'GET_AUTHENTICATION_STACK',
            'NEW_SESSION',
            'CONTINUE_SESSION',
            'DETACH_SESSION',
        ],
        'WAITING_FOR_LOGIN' => [
            'PING',
            'GET_LOGOUT_MENU',
            'LOGOUT',
            'GET_PASSWD_LOGIN',
            'GET_CLIENT_LOGIN',
            'GET_X509_LOGIN',
            'GET_OIDC_LOGIN',
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
            'GET_REALM_LIST',
        ],
    };

    my @valid_msgs_now = @{ $valid_messages->{$state_of{$ident}} };
    if (defined first { $_ eq $message_name } @valid_msgs_now) {
        # TODO - once could possibly check the content of the message
        # here, too
        ##! 16: 'message is valid'
        return 1;
    }

    CTX('log')->system()->warn('Invalid message '.$message_name.' received in state ' . $state_of{$ident});

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
        return $self->__list_pki_realms;
    }
    elsif ($state_of{$ident} eq 'WAITING_FOR_AUTHENTICATION_STACK') {
        return $self->__list_authentication_stacks();
    }
    elsif ($state_of{$ident} eq 'WAITING_FOR_LOGIN') {
        ##! 16: 'we are in state WAITING_FOR_LOGIN'
        ##! 16: 'auth stack: ' . CTX('session')->data->authentication_stack
        ##! 16: 'pki realm: ' . CTX('session')->data->pki_realm
        return $self->__handle_login( $message );
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

    # TODO: checking $state_of{$ident} is not necessary as this is already checked via __is_valid_message()
    if ($pki_realm_choice and $state_of{$ident} =~ m{\A SESSION_ID_SENT.* \z}xms) {
        $self->__change_state({
            STATE => 'WAITING_FOR_PKI_REALM',
        });
        return $self->__list_pki_realms;
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
        return $self->__handle_login( $message );
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
        # set session and forward state on success, returns reply
        delete $message->{PARAMS}->{'AUTHENTICATION_STACK'};
        return $self->__handle_login( $message );
    }

    return;
}

sub __handle_GET_PASSWD_LOGIN : PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;

    return $self->__handle_login( shift );

}

sub __handle_GET_CLIENT_LOGIN : PRIVATE {
    ##! 1: 'start'
    my $self = shift;

    return $self->__handle_login( shift );
}

sub __handle_GET_X509_LOGIN : PRIVATE {
    ##! 1: 'start'
    my $self = shift;

    return $self->__handle_login( shift );
}

sub __handle_GET_OIDC_LOGIN : PRIVATE {
    ##! 1: 'start'
    my $self = shift;

    return $self->__handle_login( shift );
}

sub __handle_LOGOUT : PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $message = shift;

    my $old_session;

    if (OpenXPKI::Server::Context::hascontext('session')) {
        $old_session = CTX('session');
        ##! 8: "logout received - terminate session " . $old_session->id,
        CTX('log')->system->debug('Terminating session ' . $old_session->id);
    }

    $self->__change_state({ STATE => 'NEW' });

    OpenXPKI::Server::Context::killsession;

    Log::Log4perl::MDC->remove;

    if ($old_session and not $old_session->delete) {
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


sub __handle_GET_ENDPOINT_CONFIG : PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $msg = shift;
    my $interface = $msg->{PARAMS}->{interface};
    my $endpoint = $msg->{PARAMS}->{endpoint};

    my $res;
    ##! 64: Dumper $msg->{PARAMS}
    if (!$interface) {
        # nothing given. list configured interfaces/services
        $res = { INTERFACE => [ CTX('config')->get_keys(['endpoint']) ] };
    } elsif (!$endpoint) {
        # default config plus names of all endpoints for given interface
        $res = {
            CONFIG =>   CTX('config')->get_hash(['endpoint', $interface, 'default' ]),
            ENDPOINT => [ CTX('config')->get_keys(['endpoint', $interface ]) ],
        };
    } else {
        # endpoint configuration
        $res = { CONFIG => CTX('config')->get_hash(['endpoint', $interface, $endpoint ]) }
    }
    ##! 128: $res
    return { PARAMS => $res };
}


sub __handle_GET_REALM_LIST : PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    return { PARAMS => CTX('api2')->get_realm_list() };
}

sub __handle_GET_LOGOUT_MENU : PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    return { PARAMS => CTX('api2')->get_menu() };
}

sub __handle_COMMAND : PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $data    = shift;

    my $command = $data->{PARAMS}->{COMMAND};
    my $params = $data->{PARAMS}->{PARAMS};
    my $api_version = $data->{PARAMS}->{API} || 2;
    my $timeout = $data->{PARAMS}->{TIMEOUT} || $max_execution_time{$ident};
    my $request_id = $data->{PARAMS}->{REQUEST_ID};

    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVICE_DEFAULT_COMMAND_COMMAND_MISSING',
    ) unless $command;

    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_SERVICE_DEFAULT_COMMAND_UNKNWON_COMMAND_API_VERSION",
        params  => $data->{PARAMS},
    ) unless $api_version =~ /^2$/;

    Log::Log4perl::MDC->put('rid', $request_id) if $request_id;

    # API2 instance
    # (late initialization because CTX('config') needs CTX('session'), i.e. logged in user)
    if (not $api{$ident}) {
        CTX('log')->system->debug("Initialization internal API for client command processing");
        my $enable_acls = not CTX('config')->get(['api','acl','disabled']);
        $api{$ident} = OpenXPKI::Server::API2->new(
            enable_acls => $enable_acls,
            acl_rule_accessor => sub { CTX('config')->get_hash(['api','acl', CTX('session')->data->role]) },
            log => CTX('log')->system,
        );
    }

    my $result;
    my $metric_id;
    eval {
        # create command ID
        my ($id) = split /-/, $UUID->create_str; # take only first part of UUID

        CTX('log')->system->debug("Executing client command '$command' (call id = $id)");

        # execution timeout
        my $sh;

        if ($timeout) {
            ##! 16: 'running command with timeout of ' . $timeout
            $sh = set_sig_handler( 'ALRM' ,sub {
                CTX('log')->system->error("Client command '$command' was aborted after ${timeout}s");
                CTX('log')->system->trace("Call was " . Dumper $data->{PARAMS} );
                OpenXPKI::Exception::Timeout->throw(
                    message => "Command took too long to - aborted!",
                    params => { command => $command }
                );
            });
            sig_alarm( $timeout );
        }

        # check parameters
        if ($params) {
            my @violated = grep { $_ =~ /\A_/ } (keys %{$params});
            OpenXPKI::Exception->throw(
                message => 'Access to private API command parameters via socket not allowed',
                params => { keys => \@violated },
            ) if (@violated);
        }

        Log::Log4perl::MDC->put('command_id', $id);
        $metric_id = CTX('metrics')->start("service_command_seconds", { command => $command }) if CTX('metrics')->do_histogram_metrics;

        # execute command enclosed with DBI transaction
        CTX('dbi')->start_txn();
        $result = $api{$ident}->dispatch(command => $command, params => $params);
        CTX('dbi')->commit();

        CTX('metrics')->stop($metric_id) if ($metric_id);

        # reset timeout
        sig_alarm(0) if $sh;
    };

    Log::Log4perl::MDC->put('command_id', undef);
    Log::Log4perl::MDC->put('rid', undef);

    if (my $error = $EVAL_ERROR) {
        CTX('metrics')->stop($metric_id) if ($metric_id);

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

    ##! 16: 'command executed successfully - returning result'
    return {
        SERVICE_MSG => 'COMMAND',
        COMMAND => $command,
        PARAMS => $result,
    };
}

sub __pki_realm_choice_available : PRIVATE {
    ##! 1: 'start'
    my $self    = shift;
    my $ident   = ident $self;

    ##! 2: "check if PKI realm is already known"
    my $realm = OpenXPKI::Server::Context::hascontext('session')
        ? CTX('session')->data->pki_realm
        : undef;
    # TODO: this method should only return 0 or 1 and the realm return value is not used in our code
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
}

sub __list_authentication_stacks : PRIVATE {
    my $self = shift;

    return {
        SERVICE_MSG => 'GET_AUTHENTICATION_STACK',
        PARAMS => {
            'AUTHENTICATION_STACKS' => CTX('authentication')->list_authentication_stacks(),
        },
    };
}

sub __list_pki_realms : PRIVATE {
    my $self = shift;

    my @realm_names = CTX('config')->get_keys("system.realms");
    my %realms;
    foreach my $realm (sort @realm_names) {
        my $label = CTX('config')->get("system.realms.$realm.label");

        $realms{$realm} = {
            NAME => $realm,
            LABEL => $label,
            DESCRIPTION => CTX('config')->get("system.realms.$realm.description") || '',
            IMAGE => CTX('config')->get("system.realms.$realm.image") || '',
            COLOR => CTX('config')->get("system.realms.$realm.color") || '',
            # auth stack info is needed to display stack label on realm selection page
            AUTH_STACKS => CTX('authentication')->list_authentication_stacks_of($realm),
        };
    }

    return {
        SERVICE_MSG => 'GET_PKI_REALM',
        PARAMS => {
            'PKI_REALMS' => \%realms,
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

sub __handle_login {

    my $self    = shift;
    my $ident   = ident $self;
    my $message = shift;

    my $auth_reply = CTX('authentication')->login_step({
        STACK   => CTX('session')->data->authentication_stack,
        MESSAGE => $message,
    });

    # returns an instance of OpenXPKI::Server::Authentication::Handle
    # if the login was successful, auth failure throws an exception
    if (ref $auth_reply eq 'OpenXPKI::Server::Authentication::Handle') {

        ##! 4: 'login successful'
        ##! 16: 'user: ' . $auth_reply->userid
        ##! 16: 'role: ' . $auth_reply->role
        ##! 32: $auth_reply

        CTX('log')->system->debug("Successful login from user ". $auth_reply->userid .", role ". $auth_reply->role);
        # successful login, save it in the session and mark session as valid
        CTX('session')->data->user( $auth_reply->userid );
        CTX('session')->data->role( $auth_reply->role );
        if ($auth_reply->has_tenants) {
            CTX('session')->data->tenants( $auth_reply->tenants );
        } else {
            CTX('session')->data->clear_tenants();
        }
        CTX('session')->data->userinfo( $auth_reply->userinfo // {} );
        CTX('session')->data->authinfo( $auth_reply->authinfo // {} );
        CTX('session')->is_valid(1);

        Log::Log4perl::MDC->put('user', $auth_reply->userid );
        Log::Log4perl::MDC->put('role', $auth_reply->role );

        $self->__change_state({ STATE => 'MAIN_LOOP', });

        return { SERVICE_MSG => 'SERVICE_READY' };
    }

    # returns a hash with information for the login stack if
    # no or insufficient auth data was passed
    return {
        SERVICE_MSG => 'GET_'.uc($auth_reply->{type}).'_LOGIN',
        PARAMS => $auth_reply->{params},
        ($auth_reply->{sign} ? (SIGN => $auth_reply->{sign}) : ()),
    };

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

    ##! 1: 'handle error'
    ##! 64: $params
    my $error;
    if ($params->{ERROR}) {
        $error = { LABEL => $params->{ERROR} };
    } elsif (ref $params->{EXCEPTION} eq '') {
        # got exception with already stringified error
        $error = { LABEL => $params->{EXCEPTION} };
    } else {
        my $class = ref $params->{EXCEPTION};
        # blessed exception object - there are some bubble ups where message
        # is an exception again => enforce stringification on message
        $error = {
            LABEL => "".$params->{EXCEPTION}->message(),
        };

        # get all scalar/hash/array parameters from OXI::Exceptions
        # this is used to transport some extra infos for validators, etc
        if ($class->isa('OpenXPKI::Exception')) {
            $error->{CLASS} = $class;
            if (defined $params->{EXCEPTION}->params) {
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

            if ($class->isa('OpenXPKI::Exception::InputValidator')) {
                $error->{ERRORS} = $params->{EXCEPTION}->{errors};
            }
        }
    }

    CTX('log')->system->trace('Sending error ' . Dumper $error) if CTX('log')->system->is_trace;

    return $self->talk({
        SERVICE_MSG => "ERROR",
        ERROR => $error,
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

Handles the COMMAND message by calling the corresponding API command if
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
