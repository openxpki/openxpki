package OpenXPKI::Service::CLI;
use OpenXPKI -class;
with 'OpenXPKI::ServiceRole';

use List::Util qw( first );

use Crypt::JWT qw(decode_jwt);
use Crypt::PK::ECC;

use Sys::SigAction qw( sig_alarm set_sig_handler );

## used modules

use OpenXPKI::DTO::Message;
use OpenXPKI::DTO::Message::ErrorResponse;
use OpenXPKI::DTO::Message::Response;
use OpenXPKI::Server;
use OpenXPKI::Server::API2;
use OpenXPKI::Server::Session;
use OpenXPKI::Server::Context qw( CTX );
use Log::Log4perl::MDC;

has 'kid_list' => (
    is => 'ro',
    isa => 'ArrayRef',
    required => 1,
);

has 'kid2role' => (
    is => 'ro',
    isa => 'HashRef',
    required => 1,
);

around BUILDARGS => sub {

    my $orig = shift;
    my $class = shift;
    my %args = @_;

    my $idle_timeout = CTX('config')->get(['system','server','service','CLI','idle_timeout']);
    $args{idle_timeout} = $idle_timeout if ($idle_timeout);

    my $max_execution_time = CTX('config')->get(['system','server','service','CLI','max_execution_time']);
    $args{max_execution_time} = $max_execution_time if ($max_execution_time);

    my $kid2role;
    my @keys = CTX('config')->get_list(['system','cli','auth']);
    my @key_list = map {
        my $pubkey = Crypt::PK::ECC->new(\$_->{key});
        my $jwk_hash = $pubkey->export_key_jwk('public', 1);
        $jwk_hash->{kid} = $pubkey->export_key_jwk_thumbprint();
        $kid2role->{$jwk_hash->{kid}} = $_->{role} || '_System';
        $jwk_hash;
    } @keys;

    $args{kid_list} = \@key_list;
    $args{kid2role} = $kid2role;
    return $class->$orig(%args);

};

sub init {

    my $self  = shift;
    OpenXPKI::Server::Context::killsession();
    return 1;

}

sub run {

    my $self  = shift;
    my $args  = shift;

    $SIG{'TERM'} = \&OpenXPKI::Server::sig_term;
    $SIG{'HUP'} = \&OpenXPKI::Server::sig_hup;

  MESSAGE:
    while (1) {
        my $msg;
        eval {
            $msg = $self->collect();
        };
        # TODO - rework "socket closed / read failed" exceptions
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

        # messages are JSON Web Tokens so we need to unwrap them
        ##! 16: $msg

        my $response;
        try {

            my ($header) = decode_jwt( token => $msg, kid_keys => { keys => $self->kid_list },
                decode_header => 1, decode_payload => 0, allow_none => 1 );
            if ($header->{alg} eq 'none') {
                ##! 8: 'Regular command'
                $response = $self->_process_regular_command($msg);
            } else {
                ##! 8: 'Operator command'
                $response = $self->_process_operator_command($msg);
            }

        } catch ($error) {
            # Anything below command should throw an exception
            if (blessed $error) {
                $response = OpenXPKI::DTO::Message::ErrorResponse->new(
                    message => "$error"
                );

            # so this should be a problem with the message decoding
            } else {
                chomp $error;
                CTX('log')->system()->error("Unable to handle message ($error)");
                $response = OpenXPKI::DTO::Message::ErrorResponse->new(
                    message => 'Unable to decode message'
                );
            }
        }
        $self->talk($response->to_hash());
    }
    return 1;
}


sub _process_regular_command {

    my $self  = shift;
    my $msg   = shift;

    my ($header, $hash) = decode_jwt( token => $msg, decode_header => 1, allow_none => 1 );
    ##! 64: $header
    $self->_init_session();
    $self->_process_login($header);

    my $message = OpenXPKI::DTO::Message::from_hash($hash);
    if (!$message->isa('OpenXPKI::DTO::Message::Command')) {
        OpenXPKI::Exception::Command->throw(
            sprintf('Invalid command message (not command but %s)', ref $message)
        );
    }
    ##! 32: $message
    my $method = '__handle_' . lc($hash->{class});
    return $self->$method($message);

}

sub _process_operator_command {

    my $self  = shift;
    my $msg   = shift;

    my ($header, $hash) = decode_jwt( token => $msg, kid_keys => { keys => $self->kid_list }, decode_header => 1 );
    ##! 64: $header
    $self->_init_session();
    my $kid = $header->{kid};
    CTX('session')->data->user('kid:'.$kid);
    CTX('session')->data->role($self->kid2role->{$kid});

    if ($header->{pki_realm}) {
        CTX('session')->data->pki_realm($header->{pki_realm});
    } else {
        # special realm for admin tasks
        CTX('session')->data->pki_realm('_void');
    }

    my $method = '__handle_' . lc($hash->{class});
    my $message = OpenXPKI::DTO::Message::from_hash($hash);
    ##! 32: $message
    return $self->$method($message);

}

# Bulk copy from Default Stack, still using using old parameter format
# TODO - consolidation and cleanup parameter structures

sub _process_login {

    my $self  = shift;
    # header from the JWT holding, realm, stack and auth parameters
    my $auth   = shift;

    my $pki_realm = $auth->{pki_realm} ||
        OpenXPKI::Exception::Authentication->throw(
            'no realm given'
        );
    delete $auth->{pki_realm};
    if (!$self->_is_valid_pki_realm($pki_realm)) {
        OpenXPKI::Exception::Authentication->throw(
            message => 'invalid realm given',
            params => { pki_realm =>  $pki_realm }
        );
    }

    CTX('session')->data->pki_realm($pki_realm);

    my $stack = $auth->{stack} ||
        OpenXPKI::Exception::Authentication->throw(
            'no auth stack given'
        );

    delete $auth->{stack};
    if (!$self->_is_valid_auth_stack($stack)) {
        OpenXPKI::Exception::Authentication->throw(
            message => 'oops - invalid auth stack',
            stack => $stack
        );
    }

    # TODO - use data objects here and no longer hashes
    my $auth_reply = CTX('authentication')->login_step({
        STACK   => $stack,
        MESSAGE => { PARAMS => $auth },
    });

    # returns an instance of OpenXPKI::Server::Authentication::Handle
    # if the login was successful, auth failure throws an exception
    # returns a hash ref with stack information when auth data was incomplete
    if (!ref $auth_reply eq 'OpenXPKI::Server::Authentication::Handle') {
        OpenXPKI::Exception::Authentication->throw(
            message => 'Insufficient information to authenticate',
            stack => $stack
        );
    }

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

    return 1;

}


# send message to client
sub talk {
    my $self  = shift;
    my $arg   = shift;

    my $rc = $self->transport()->write(
        $self->serialization()->serialize($arg)
    );
    if ($OpenXPKI::Server::stop_soon) {
        ##! 1: 'stop_soon hit'
        CTX('log')->system()->info("Child $$ terminated by SIGTERM");
        CTX('config')->cleanup();
        exit 0;
    }
    return $rc;
}

# get server response
sub collect {
    my $self  = shift;

    if ($OpenXPKI::Server::stop_soon) {
        ##! 1: 'stop_soon hit'
        CTX('log')->system()->info("Child $$ terminated by SIGTERM");
        CTX('config')->cleanup();
        exit 0;
    }

    my $result;
    try {
        ##! 32: "setting signal handler ALRM"
        my $h = set_sig_handler('ALRM', sub { die "alarm\n"; });

        alarm $self->idle_timeout();

        $result = $self->serialization->deserialize(
            $self->transport->read()
        );
        alarm 0;
    } catch ($error) {
        alarm 0;
        ##! 1: "ERROR: " . Dumper($error)
        if ($error eq "alarm\n") {
            OpenXPKI::Exception->throw(
                message => "I18N_OPENXPKI_SERVICE_COLLECT_TIMEOUT",
                log => undef, # do not log this exception
            );
        }
        # FIXME
        die $error;
    }
    ##! 128: 'collect: ' . Dumper $result
    return $result;
}

=head2 __handle_command

Command is routed to the regular API.

If no session_id is given, the request must contain authentication
information and a realm to create a session on the fly.

=cut

sub __handle_command {

    my $self = shift;
    my $message = shift;

    try {

        CTX('dbi')->start_txn();
        my $result = $self->api()->dispatch(
            command => $message->command,
            params => $message->params
        );
        CTX('dbi')->commit();

        $result = { result => $result } unless (ref $result eq 'HASH');

        return OpenXPKI::DTO::Message::Response->new(params => $result);
    } catch ($error) {
        chomp $error;
        return OpenXPKI::DTO::Message::ErrorResponse->new(
            message => "$error"
        );
    }

}

=head2 __handle_protectedcommand

Command is routed to the protected API

=cut

sub __handle_protectedcommand {

    my $self = shift;
    my $message = shift;

    try {

        CTX('dbi')->start_txn();
        my $result = $self->api()->dispatch(
            # TODO rework protected command marker
            command => '__'.$message->command,
            params => $message->params
        );
        CTX('dbi')->commit();

        $result = { result => $result } unless (ref $result eq 'HASH');

        return OpenXPKI::DTO::Message::Response->new(params => $result);
    } catch ($error) {
        chomp $error;
        return OpenXPKI::DTO::Message::ErrorResponse->new(
            message => "$error"
        );
    }

}

sub _init_session {
    # memory-only session is sufficient as we do not persist/resume the session

    my $session = OpenXPKI::Server::Session->new(
        type => "Memory",
    )->create;
    OpenXPKI::Server::Context::setcontext({ session => $session, force => 1 });
    Log::Log4perl::MDC->put('sid', $session->short_id);
}

sub _init_api {

    my $self = shift;
    # TODO - define ACL handling in void context
    #my $enable_acls = not CTX('config')->get(['api','acl','disabled']);
    return OpenXPKI::Server::API2->new(
        enable_protected => 1,
        enable_acls => 0, #$enable_acls,
        #acl_rule_accessor => sub { CTX('config')->get_hash(['api','acl', CTX('session')->data->role]) },
    );
}

1;

=head1 SYNOPSIS

The CLI service class implements a sessionless and stateless command
protocol. Each message must be signed by a JSON Web Signature using a
key defined in I<system.cli.auth>.
