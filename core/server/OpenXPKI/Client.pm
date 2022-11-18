package OpenXPKI::Client;
use Moose;

use English;

use Carp;
use Socket;

use Sys::SigAction qw( sig_alarm set_sig_handler );

use OpenXPKI::Exception;
use OpenXPKI::Transport::Simple;
use OpenXPKI::Serialization::Simple;
eval { use OpenXPKI::Serialization::JSON; };
eval { use OpenXPKI::Serialization::Fast; };

$OUTPUT_AUTOFLUSH = 1;

# use Smart::Comments;
use Data::Dumper;

has socketfile => (
    is      => 'ro',
    isa     => 'Str',
    required => 1,
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
        my $class = "OpenXPKI::Serialization::" . $self->serialization();
        return $class->new();
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

around BUILDARGS => sub {

    my $orig = shift;
    my $class = shift;

    # old call format using hash
    if ( @_ == 1 && ref $_[0] eq 'HASH' ) {
        my %params = %{$_[0]};
        foreach my $key (qw(TIMEOUT SOCKETFILE TRANSPORT SERIALIZATION SERVICE  API_VERSION)) {
            #warn $params->{$key};
            if ($params{$key}) {
                $params{lc($key)} = $params{$key};
                delete $params{$key};
            }
        }

        return $class->$orig(%params);
    } else {
        return $class->$orig(@_);
    }

};

sub __build_socket {

    my $self = shift;

    ##! 2: "Initialize server socket connection"
    ##! 4: "socket..."
    my $socket;
    if (! socket($socket, PF_UNIX, SOCK_STREAM, 0)) {
    OpenXPKI::Exception->throw(
        message => "I18N_OPENXPKI_CLIENT_INIT_CONNECTION_NO_SOCKET",
        );
    }
    ##! 4: "connect..."
    if (! connect($socket, sockaddr_un($self->socketfile()))) {
    OpenXPKI::Exception->throw(
        message => "I18N_OPENXPKI_CLIENT_INIT_CONNECTION_FAILED",
        params  => {
            SOCKETFILE => $self->socketfile(),
            ERROR      => $!,
        });
    }
    ##! 4: "finished"
    return $socket;
}

sub __build_channel {

    my $self = shift;

    my $msg;

    ##! 8: "send requested transport protocol to server"
    send($self->_socket(), sprintf("start %s\n", $self->transport()), 0);

    ##! 8: "receive answer from server"
    read($self->_socket(), $msg, 3); ## read OK

    ##! 8: "evaluate answer"
    if ($msg !~ /^OK/) {
        ##! 16: "transport protocol was not accepted by server - $msg"
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_CLIENT_INIT_TRANSPORT_PROTOCOL_REJECTED",
        );
    }

    ##! 8: "intializing transport protocol"
    # FIXME: dynamically assign transport protocol
    my $channel = OpenXPKI::Transport::Simple->new({
        SOCKET => $self->_socket(),
    });

    ##! 4: "channel established"

    # initializate serialization protocol
    $channel->write($self->serialization());

    ##! 8: "receive answer from server"
    $msg = $channel->read();   ## read 'OK'

    ##! 8: "evaluate answer"
    if ($msg !~ /^OK/) {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_CLIENT_INIT_SERIALIZATION_PROTOCOL_REJECTED",
        );
    }

    ##! 8: "intializing serialization protocol"
    my $class = "OpenXPKI::Serialization::" . $self->serialization();
    $self->_serializer( $class->new() );

    ##! 4: "request service protocol"
    $channel->write( $self->_serializer()->serialize( $self->service() ) );
    $msg = $self->_serializer()->deserialize( $channel->read() );

    if ($msg ne "OK") {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_CLIENT_INIT_SERVICE_PROTOCOL_REJECTED",
        );
    }

    ##! 4: "finished"

    return $channel;

}

sub talk {

    my $self  = shift;

    my $msg  = shift;

    eval {
        $self->_channel()->write(
            $self->_serializer()->serialize($msg)
        );
    };

    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => 'Error while writing to socket',
            params  => {
                EVAL_ERROR => $EVAL_ERROR,
            },
        );
    }

    my $result;
    my $sh = set_sig_handler('ALRM', sub {
        $self->close_connection();
        OpenXPKI::Exception::Timeout->throw(
            message => 'Timeout while reading from socket',
            params  => {
                command => ($msg->{SERVICE_MSG} eq 'COMMAND' ? $msg->{PARAMS}->{COMMAND} : $msg->{SERVICE_MSG}),
                timeout => $self->timeout()
            },
        );
    });

    sig_alarm( $self->timeout() );
    $result = $self->_serializer()->deserialize(
        $self->_channel()->read()
    );
    sig_alarm( 0 );

    if (my $eval_err = $EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => 'Error while reading from socket',
            params  => {
                EVAL_ERROR => $eval_err,
            },
        );
    }
    ##! 4: Dumper $result
    return $result;

}

# send service message and read response
sub send_receive_service_msg {

    my $self  = shift;

    my $cmd   = shift;
    my $arg   = shift;

    if ($cmd eq 'COMMAND' && !$arg->{API}) {
        $arg->{API} = $self->api_version();
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
sub send_receive_command_msg {
    my $self  = shift;
    my $cmd   = shift;
    my $arg   = shift || {};

    return $self->send_receive_service_msg(
        'COMMAND',
        {
            COMMAND     => $cmd,
            PARAMS      => $arg,
        }
    );

}

sub init_session {

    my $self  = shift;
    my $args  = shift;

    my $msg;
    ##! 4: "initialize session"
    if (defined $args->{SESSION_ID}) {
        ##! 8: "using existing session"
        $msg = $self->send_receive_service_msg(
            'CONTINUE_SESSION',
            { SESSION_ID  => $args->{SESSION_ID} }
        );
    } else {
        ##! 8: "creating new session"
        ##! 8: "FIXME: we should send the preferred language here"
        $msg = $self->send_receive_service_msg( 'NEW_SESSION' );
    }

    # init a new session if reload failed
    if (! defined $msg->{SESSION_ID} &&
        $args->{SESSION_ID} && $args->{NEW_ON_FAIL}) {
        $msg = $self->send_receive_service_msg( 'NEW_SESSION' );
    }

    if (! defined $msg->{SESSION_ID}) {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_CLIENT_INIT_SESSION_FAILED",
            params  => {
                MESSAGE_FROM_SERVER => Dumper $msg,
        });
    }

    $self->session_id( $msg->{SESSION_ID} );

    return $self->send_receive_service_msg('SESSION_ID_ACCEPTED');

}

sub rekey_session {

    my $self  = shift;
    my $args  = shift;

    # if no session exists (e.g after logout or socket timeout)
    # we start a new session
    if (!$self->session_id()) {
        return $self->init_session();
    }

    my $msg = $self->send_receive_service_msg('RESET_SESSIONID');

    if (! defined $msg->{SESSION_ID}) {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_CLIENT_REKEY_SESSION_FAILED",
            params  => {
                MESSAGE_FROM_SERVER => Dumper $msg,
        });
    }

    $self->session_id( $msg->{SESSION_ID} );

    return $self->send_receive_service_msg('SESSION_ID_ACCEPTED');
}


sub detach {
    my $self  = shift;
    my $args  = shift;

    # already detached (happens on logout)
    if (!$self->session_id()) {
        return 2;
    }

    if (!$self->is_connected()) {
        return 3;
    }

    my $msg;
    eval {
        $msg = $self->send_receive_service_msg('DETACH_SESSION');
    };

    $self->session_id( '' );

    if (defined $msg &&
        ref $msg eq 'HASH' &&
        $msg->{SERVICE_MSG} eq 'DETACH') {
        return 1;
    }

    OpenXPKI::Exception->throw(
        message => "I18N_OPENXPKI_CLIENT_DETACH_FAILED",
        params  => {
            MESSAGE_FROM_SERVER => Dumper $msg,
    });

}


sub logout {
    my $self  = shift;
    my $args  = shift;

    if (!$self->is_connected()) {
        return 3;
    }

    my $msg = $self->send_receive_service_msg('LOGOUT');

    $self->session_id( '' );

    if (defined $msg &&
        ref $msg eq 'HASH' &&
        $msg->{SERVICE_MSG} eq 'LOGOUT') {
        return 1;
    }

    OpenXPKI::Exception->throw(
        message => "I18N_OPENXPKI_CLIENT_LOGOUT_FAILED",
        params  => {
            MESSAGE_FROM_SERVER => $msg,
    });

}

sub is_logged_in {
    my $self = shift;

    my $msg;
    eval {
        $msg = $self->send_receive_service_msg('PING');
    };
    if (defined $msg &&
        ref $msg eq 'HASH' &&
        $msg->{SERVICE_MSG} eq 'SERVICE_READY') {
        return 1;
    }
    return undef;
}

sub is_connected
{
    my $self = shift;

    if (!$self->has_socket() || !$self->has_channel() ) {
        return 0;
    }

    # get current session status
    eval
    {
        my $msg = $self->send_receive_service_msg('PING');
    };
    if (my $exc = OpenXPKI::Exception->caught())
    {
        if ($exc->message() eq 'I18N_OPENXPKI_TRANSPORT_SIMPLE_WRITE_ERROR_DURING_SOCKET_SEND') {
            # this is probably an OpenXPKI server that died at the other end
            # normal missing connection => 0
            return 0;
        } else {
            # OpenXPKI::Exception but from where ? => undef
            return undef;
        }
    } elsif ($EVAL_ERROR) {
        # completely unknown die => -1
        return -1;
    }
    return 1;
}

sub close_connection {
    my $self = shift;

    if (!$self->has_socket()) {
        warn "got close_connection on already closed socket";
        return;
    }
    shutdown($self->_socket(), 2); # we have stopped using this socket
    # for whatever reasons shutdown does not free the handle, see #645
    close($self->_socket());

    $self->clear_channel();
    $self->clear_socket();

}

sub DEMOLISH {
    ##! 4: 'Demolish'
    my $self = shift;

    if ($self->has_socket()) {
        $self->close_connection();
    }

}

# for legacy clients
sub get_session_id {
    my $self = shift;
    return $self->session_id();
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

OpenXPKI::Client - OpenXPKI Client base library


=head1 VERSION

This document describes OpenXPKI::Client version 0.0.1


=head1 SYNOPSIS

    use OpenXPKI::Client;
    my $client = OpenXPKI::Client->new(
        {
             SOCKETFILE => './foo.socket',
        });

    # create new session
    $client->init_session();


=head1 DESCRIPTION

OpenXPKI::Client is a base class for client communication with an
OpenXPKI server daemon.

=head1 INTERFACE

=head2 BUILD

See perldoc Class::Std.

=head2 START

See perldoc Class::Std.

=head2 talk

Expects a hash reference as first argument. Serializes the argument and
sends it to the OpenXPKI server.
Throws an exception if the connection is not in communication state
'can_send'.

=head2 collect

Reads an answer from the OpenXPKI server, deserializes the message and
returns the corresponding data structure.
Throws an exception if the connection is not in communication state
'can_receive'.

=head2 get_communication_state

Get internal communication state. Returns 'can_send' if the next action
should be a talk() call. Returns 'can_receive' if the next action should
be a collect() call.

=head2 send_service_msg

Send a service message.
The first argument must be a string identifying the service command to send.
The (optional) second argument is a hash reference containing the
arguments to be sent along with the service message.
The caller must assure that this argument is properly specified.

=head2 send_command_msg

Send a service command message.
The first argument must be a string identifying the command to send.
The (optional) second argument is a hash reference containing the
arguments to be sent along with the command message.

=head2 send_receive_service_msg

Send a service message, reads the response and returns it.
See send_service_msg.

=head2 send_receive_command_msg

Send a service command message, reads the response and returns it.
See send_command_msg.

=head2 init_session

Initialize session. If the named argument SESSION_ID exists, this session
is re-opened. If it can not be loaded, and expcetion is thrown. If you don't
pass a session id, a new session is created.
If you want to create a new session if the existing one is no longer
available, pass NEW_ON_FAIL with a true value as extra argument.

Returns the first server response (see collect()).

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

=head1 CONFIGURATION AND ENVIRONMENT

OpenXPKI::Client requires no configuration files or environment variables.


=head1 DEPENDENCIES

Requires an OpenXPKI perl core module installation.


=head1 INCOMPATIBILITIES

None reported.


=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to the OpenXPKI mailing list
or its project home page http://www.openxpki.org/.


=head1 AUTHOR

Martin Bartosch C<< <m.bartosch@cynops.de> >>

=head1 LICENCE AND COPYRIGHT

Written 2006 by Martin Bartosch for the OpenXPKI project
Copyright (C) 2006 by The OpenXPKI Project

See the LICENSE file for license details.



=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
