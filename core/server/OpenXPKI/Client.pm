package OpenXPKI::Client;
use OpenXPKI -class;

use Carp;
use Socket;

use Sys::SigAction qw( sig_alarm set_sig_handler );

use OpenXPKI::Transport::Simple;
use OpenXPKI::Serialization::Simple;
eval { use OpenXPKI::Serialization::JSON; };
eval { use OpenXPKI::Serialization::Fast; };


$OUTPUT_AUTOFLUSH = 1;


has socketfile => (
    is      => 'ro',
    isa     => 'Str',
    default => sub {
        # Automated fallback to legacy socket location
        return $OpenXPKI::Defaults::SERVER_LEGACY_SOCKET
            if (! -e $OpenXPKI::Defaults::SERVER_SOCKET &&
                -e $OpenXPKI::Defaults::SERVER_LEGACY_SOCKET);

        return $OpenXPKI::Defaults::SERVER_SOCKET;
    }
);

has timeout => (
    is      => 'ro',
    isa     => 'Int',
    default => 30
);

has transport => (
    is      => 'ro',
    isa     => 'Str',
    default => 'Simple',
);

has serialization => (
    is      => 'ro',
    isa     => 'Str',
    default => 'Simple',
);

has service => (
    is      => 'ro',
    isa     => 'Str',
    default => 'Default',
);

has session_id => (
    is      => 'rw',
    isa     => 'Str',
    init_arg => undef,   # not settable via constructor
    lazy    => 1,
    default => '',
);

has api_version => (
    is      => 'ro',
    isa     => 'Int',
    default => 2
);

has _channel => (
    is       => 'rw',
    lazy     => 1,
    builder  => '__build_channel',
    clearer   => 'clear_channel',
    predicate => 'has_channel',
);

has _serializer => (
    is       => 'rw',
    lazy     => 1,
    init_arg => undef,   # not settable via constructor
    default => sub {
        my $self = shift;
        my $class = "OpenXPKI::Serialization::" . $self->serialization;
        return $class->new;
    }
);

has _socket => (
    is       => 'rw',
    lazy     => 1,
    init_arg => undef,   # not settable via constructor
    builder  => '__build_socket',
    clearer   => 'clear_socket',
    predicate => 'has_socket',
);

sub __build_socket ($self) {
    ##! 2: "Initialize server socket connection"
    ##! 4: "socket..."
    my $socket;
    if (not socket($socket, PF_UNIX, SOCK_STREAM, 0)) {
        OpenXPKI::Exception::Socket->throw(
            message => 'Unable to initialize socket',
            socket => $self->socketfile,
        );
    }
    ##! 4: "connect..."
    if (not connect($socket, sockaddr_un($self->socketfile))) {
        OpenXPKI::Exception::Socket->throw(
            message => 'Unable to connect socket',
            socket => $self->socketfile,
            error      => $!,
        );
    }
    ##! 4: "finished"
    return $socket;
}

sub __build_channel ($self) {
    my $msg;

    ##! 8: "send requested transport protocol to server"
    send($self->_socket, sprintf("start %s\n", $self->transport), 0);

    ##! 8: "receive answer from server"
    read($self->_socket, $msg, 3); ## read OK

    ##! 8: "evaluate answer"
    if ($msg !~ /^OK/) {
        ##! 16: "transport protocol was not accepted by server - $msg"
        OpenXPKI::Exception::Socket->throw(
            message => 'Transport protocol was not accepted by server',
            socket => $self->socketfile,
        );
    }

    ##! 8: "intializing transport protocol"
    # FIXME: dynamically assign transport protocol
    my $channel = OpenXPKI::Transport::Simple->new({
        SOCKET => $self->_socket,
    });

    ##! 4: "channel established"

    # initializate serialization protocol
    $channel->write($self->serialization);

    ##! 8: "receive answer from server"
    $msg = $channel->read;   ## read 'OK'

    ##! 8: "evaluate answer"
    if ($msg !~ /^OK/) {
        OpenXPKI::Exception::Socket->throw(
            message => 'Serialization protocol was not accepted by server',
            socket => $self->socketfile,
        );
    }

    ##! 8: "intializing serialization protocol"
    my $class = "OpenXPKI::Serialization::" . $self->serialization;
    $self->_serializer( $class->new );

    ##! 4: "request service protocol"
    $channel->write( $self->_serializer->serialize( $self->service ) );
    $msg = $self->_serializer->deserialize( $channel->read );

    if ($msg ne "OK") {
        OpenXPKI::Exception::Socket->throw(
            message => 'Service protocol was not accepted by server',
            socket => $self->socketfile,
            params => { service => $self->service }
        );
    }

    ##! 4: "finished"

    return $channel;
}

sub talk ($self, $msg) {
    # for whatever reason using try/catch here does NOT behave like the
    # eval construct and causes the session reinit to end in an endless loop
    eval {
        $self->_channel->write(
            $self->_serializer->serialize($msg)
        );
    };
    if (my $error = $EVAL_ERROR) {
        OpenXPKI::Exception::Socket->throw(
            message => 'Error while writing to socket',
            socket => $self->socketfile,
            error  => $error,
        );
    }

    my $sh = set_sig_handler('ALRM', sub {
        $self->close_connection;
        OpenXPKI::Exception::Timeout->throw(
            message => 'Timeout while reading from socket',
            params  => {
                command => ($msg->{SERVICE_MSG} eq 'COMMAND' ? $msg->{PARAMS}->{COMMAND} : $msg->{SERVICE_MSG}),
                timeout => $self->timeout
            },
        );
    });

    sig_alarm( $self->timeout );
    my $result = $self->_serializer->deserialize(
        $self->_channel->read
    );
    sig_alarm( 0 );

    # TODO - is this ever fired ?
    if (my $error = $EVAL_ERROR) {
        OpenXPKI::Exception::Socket->throw(
            message => 'Error while reading from socket',
            socket => $self->socketfile,
            error  => $error,
        );
    }
    ##! 4: Dumper $result
    return $result;
}

# send service message and read response
sub send_receive_service_msg ($self, $cmd, $arg = {}) {
    if ($cmd eq 'COMMAND' and not $arg->{API}) {
        $arg->{API} = $self->api_version;
    }

    ##! 1: "send_receive_service_msg"
    ##! 2: $cmd
    ##! 4: Dumper $arg

    return $self->talk({
        SERVICE_MSG => $cmd,
        PARAMS => $arg,
    });
}

# send service message and read response
sub send_receive_command_msg ($self, $cmd, $arg = {}) {
    return $self->send_receive_service_msg( 'COMMAND', {
        COMMAND => $cmd,
        PARAMS => $arg,
    });
}

sub check_msg ($self, $msg, $key, $value) {
    return (
        defined $msg and ref $msg eq 'HASH'
        and defined $msg->{$key} and $msg->{$key} eq $value
    );
}

sub init_session ($self, $arg = {}) {
    my $msg;
    ##! 4: "initialize session"
    if (defined $arg->{SESSION_ID}) {
        ##! 8: "using existing session"
        $msg = $self->send_receive_service_msg( 'CONTINUE_SESSION', {
            SESSION_ID => $arg->{SESSION_ID},
        });
    } else {
        ##! 8: "creating new session"
        ##! 8: "FIXME: we should send the preferred language here"
        $msg = $self->send_receive_service_msg( 'NEW_SESSION' );
    }

    # init a new session if reload failed
    if (not defined $msg->{SESSION_ID} and $arg->{SESSION_ID} and $arg->{NEW_ON_FAIL}) {
        $msg = $self->send_receive_service_msg( 'NEW_SESSION' );
    }

    if (not defined $msg->{SESSION_ID}) {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_CLIENT_INIT_SESSION_FAILED",
            params => { MESSAGE_FROM_SERVER => Dumper $msg },
        );
    }

    $self->session_id( $msg->{SESSION_ID} );

    return $self->send_receive_service_msg('SESSION_ID_ACCEPTED');

}

sub rekey_session ($self) {
    # if no session exists (e.g after logout or socket timeout)
    # we start a new session
    return $self->init_session unless $self->session_id;

    my $msg = $self->send_receive_service_msg('RESET_SESSIONID');

    if (not defined $msg->{SESSION_ID}) {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_CLIENT_REKEY_SESSION_FAILED",
            params => { MESSAGE_FROM_SERVER => Dumper $msg },
        );
    }

    $self->session_id( $msg->{SESSION_ID} );

    return $self->send_receive_service_msg('SESSION_ID_ACCEPTED');
}


sub detach ($self) {
    # already detached (happens on logout)
    return 2 unless $self->session_id;
    return 3 unless $self->is_connected;

    my $msg;
    eval {
        $msg = $self->send_receive_service_msg('DETACH_SESSION');
    };

    $self->session_id( '' );

    return 1 if $self->check_msg($msg, SERVICE_MSG => 'DETACH');

    OpenXPKI::Exception->throw(
        message => "I18N_OPENXPKI_CLIENT_DETACH_FAILED",
        params => { MESSAGE_FROM_SERVER => Dumper $msg },
    );
}


sub logout ($self) {
    return 3 unless $self->is_connected;

    my $msg = $self->send_receive_service_msg('LOGOUT');

    $self->session_id( '' );

    return 1 if $self->check_msg($msg, SERVICE_MSG => 'LOGOUT');

    OpenXPKI::Exception->throw(
        message => "I18N_OPENXPKI_CLIENT_LOGOUT_FAILED",
        params => { MESSAGE_FROM_SERVER => Dumper $msg },
    );
}

sub is_logged_in ($self) {
    my $msg;
    eval {
        $msg = $self->send_receive_service_msg('PING');
    };

    return 1 if $self->check_msg($msg, SERVICE_MSG => 'SERVICE_READY');

    return;
}

sub is_connected ($self) {
    return 0 if (not $self->has_socket or not $self->has_channel);

    # get current session status
    eval {
        my $msg = $self->send_receive_service_msg('PING');
    };
    if (my $exc = OpenXPKI::Exception->caught) {
        if ($exc->message eq 'I18N_OPENXPKI_TRANSPORT_SIMPLE_WRITE_ERROR_DURING_SOCKET_SEND') {
            # this is probably an OpenXPKI server that died at the other end
            # normal missing connection => 0
            return 0;
        } else {
            # OpenXPKI::Exception but from where ? => undef
            return;
        }
    } elsif ($EVAL_ERROR) {
        # completely unknown die => -1
        return;
    }
    return 1;
}

sub ping ($self) {
    try {
        my $msg = $self->send_receive_service_msg('PING');
        ##! 32: $msg
        return 1;
    } catch ($error) {
    }

    return 0;
}

sub close_connection ($self) {
    if (not $self->has_socket) {
        warn "got close_connection on already closed socket";
        return;
    }
    shutdown($self->_socket, 2); # we have stopped using this socket
    # for whatever reasons shutdown does not free the handle, see #645
    close($self->_socket);

    $self->clear_channel;
    $self->clear_socket;
}

sub DEMOLISH {
    ##! 4: 'Demolish'
    my $self = shift;

    if ($self->has_socket) {
        $self->close_connection;
    }

}

# for legacy clients
sub get_session_id ($self) {
    return $self->session_id;
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

OpenXPKI::Client - OpenXPKI Client base library

=head1 SYNOPSIS

    use OpenXPKI::Client;
    my $client = OpenXPKI::Client->new(
        socketfile => './foo.socket',
    );

    # create new session
    $client->init_session;

=head1 DESCRIPTION

OpenXPKI::Client is a base class for client communication with an
OpenXPKI server daemon.

=head1 INTERFACE

=head2 talk

Expects a hash reference as first argument. Serializes the argument and
sends it to the OpenXPKI server.
Throws an exception if the connection is not in communication state
'can_send'.

=head2 send_receive_service_msg

Send a service message, reads the response and returns it.
See send_service_msg.

=head2 send_receive_command_msg

Send a service command message, reads the response and returns it.
See send_command_msg.

=head2 init_session

Initialize session. If the named argument SESSION_ID exists, this session
is re-opened. If it can not be loaded, and exception is thrown. If you don't
pass a session id, a new session is created.

If you want to create a new session if the existing one is no longer
available, pass NEW_ON_FAIL with a true value as extra argument.

Returns the first server response.

=head2 rekey_session

Assign a new session id to the existing session. The old session id is
deleted. Returns the new session id.

=head2 get_session_id

Returns current session ID (or undef if no session is active).

=head2 set_timeout

Set socket read timeout (seconds, default: 30).

=head2 close_connection

Closes the socket connection to the server.

=head1 DIAGNOSTICS

=head2 is_connected

returns true on a normal established connection. Returns false if the
connection is missing or something goes wrong during the check.

=head2 is_logged_in

returns true if a connection is available and the user has finished
authentication (i.e. PING returns 'SERVICE_READY').
