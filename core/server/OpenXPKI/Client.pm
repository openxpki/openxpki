# OpenXPKI::Client
# Written 2006 by Michael Bell and Martin Bartosch for the OpenXPKI project
# (C) Copyright 2006 by The OpenXPKI Project

package OpenXPKI::Client;

use warnings;
use strict;
use Carp;
use English;

use Class::Std;

use Socket;

use OpenXPKI::Debug 'OpenXPKI::Client';

use OpenXPKI::Client::API;
use OpenXPKI::Exception;
use OpenXPKI::Transport::Simple;
use OpenXPKI::Serialization::Simple;
eval { use OpenXPKI::Serialization::JSON; };
eval { use OpenXPKI::Serialization::Fast; };

$OUTPUT_AUTOFLUSH = 1;

# use Smart::Comments;
use Data::Dumper;

my %socketfile             : ATTR( :init_arg<SOCKETFILE> );
my %transport_protocol     : ATTR( :init_arg<TRANSPORT>     :default('Simple') );
my %serialization_protocol : ATTR( :init_arg<SERIALIZATION> :default('Simple') );
my %service_protocol       : ATTR( :init_arg<SERVICE>       :default('Default') );
my %read_timeout           : ATTR( :init_arg<TIMEOUT>       :default(30) :set<timeout> );

my %sessionid              : ATTR( :get<session_id> );
my %api                    : ATTR( :get<API> );
my %communication_state    : ATTR( :get<communication_state> :set<communication_state> );

my %socket                 : ATTR;
my %transport              : ATTR;
my %serialization          : ATTR;

#sub catch_signal {
#    my $signame = shift;
#    OpenXPKI::Exception->throw(
#        message => 'I18N_OPENXPKI_CLIENT_SIGNAL_CAUGHT',
#        params  => {
#            'SIGNAL' => $signame,
#        },
#    );
#    return 1;
#}

#$SIG{CHLD} = \&catch_signal;
#$SIG{PIPE} = \&catch_signal;

sub START {
    my ($self, $ident, $arg_ref) = @_;

    ##! 1: "Initialize protocol stack"
    $self->__init_connection();
    $self->__init_transport_protocol();
    $self->__init_serialization_protocol();
    $self->__init_service_protocol();

    # attach API to this instance
    $api{$ident} = OpenXPKI::Client::API->new(
        {
        CLIENT => $self,
    });

}


###########################################################################
# interface methods

# send message to server
sub talk {
    my $self  = shift;
    my $arg   = shift;
    my $ident = ident $self;

    ##! 1: "talk"
    if ($self->get_communication_state() eq 'can_send') {
        my $rc;
        eval {
        $rc = $transport{$ident}->write(
            $serialization{$ident}->serialize($arg)
            );
        $self->set_communication_state('can_receive');
        };
        if ($EVAL_ERROR) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_CLIENT_TALK_ERROR_DURING_WRITE',
                params  => {
                    'EVAL_ERROR' => $EVAL_ERROR,
                    'ARGUMENT'   => $arg,
                },
            );
        }
    return $rc;
    } else {
    OpenXPKI::Exception->throw(
        message => "I18N_OPENXPKI_CLIENT_INCORRECT_COMMUNICATION_STATE",
        params => {
        STATUS => $self->get_communication_state(),
        },
        );
    }
    return 1;
}

# get server response
sub collect {
    my $self  = shift;
    my $ident = ident $self;

    ##! 1: "collect"
    if ($self->get_communication_state() ne 'can_receive') {
    OpenXPKI::Exception->throw(
        message => "I18N_OPENXPKI_CLIENT_INCORRECT_COMMUNICATION_STATE",
        params => {
        STATUS => $self->get_communication_state(),
        },
        );
    }

    my $result;
    eval {
        local $SIG{ALRM} = sub { die "alarm\n" };

        alarm $read_timeout{$ident};
        $result = $serialization{$ident}->deserialize(
            $transport{$ident}->read()
        );
        $self->set_communication_state('can_send');
        alarm 0;
    };
    if (my $exc = OpenXPKI::Exception->caught()) {
        $self->set_communication_state('can_send');
        if ($exc->message() eq 'I18N_OPENXPKI_TRANSPORT_SIMPLE_CLIENT_READ_FAILED'
         && $exc->params()->{'__EVAL_ERROR__'} eq 'alarm') {
            # timeout, return
            return;
        }
        die $exc->message();
    }
    elsif (my $eval_err = $EVAL_ERROR) {
        $self->set_communication_state('can_send');
        if ($eval_err =~ m{\A alarm }xms) {
            # Timeout from the above alarm signal handler
            return {
                'SERVICE_MSG' => 'ERROR',
                'LIST' => [
                    {
                        'LABEL' => 'I18N_OPENXPKI_CLIENT_COLLECT_TIMEOUT',
                    },
                ],
            };
        }
        else {
            return {
                'SERVICE_MSG' => 'ERROR',
                'LIST' => [
                    {
                        'LABEL'  => 'I18N_OPENXPKI_CLIENT_COLLECT_EVAL_ERROR',
                        'PARAMS' => {
                            ERROR => $eval_err,
                        },
                    },
                ],
            };
        }
    }
    return $result;
}

###########################################################################
# send-only functions

# send service message
sub send_service_msg {
    my $self  = shift;
    my $ident = ident $self;
    my $cmd   = shift;
    my $arg   = shift || {};

    ##! 1: "send_service_msg"
    ##! 2: $cmd
    ##! 4: Dumper $arg

    my %arguments = (
    SERVICE_MSG => $cmd,
    PARAMS => $arg,
    );

    ##! 4: Dumper \%arguments
    eval {
        $self->talk(\%arguments);
    };
    if ($EVAL_ERROR) {
        ##! 16: 'eval error during send_service_msg!'
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CLIENT_SEND_SERVICE_MSG_TALK_FAILED',
            params  => {
                EVAL_ERROR => $EVAL_ERROR,
            },
        );
    }

    return 1;
}

# send service command message
sub send_command_msg {
    my $self  = shift;
    my $ident = ident $self;
    my $cmd   = shift;
    my $arg   = shift;

    ##! 1: "send_command_msg"
    ##! 2: $cmd
    ##! 4: Dumper $arg

    return $self->send_service_msg(
    'COMMAND',
    {
        COMMAND     => $cmd,
        PARAMS      => $arg,
    });
}

###########################################################################
# all-in-one functions

# send service message and read response
sub send_receive_service_msg {
    my $self  = shift;
    my $ident = ident $self;
    my $cmd   = shift;
    my $arg   = shift;

    ##! 1: "send_receive_service_msg"
    ##! 2: $cmd
    ##! 4: Dumper $arg

    eval {
        $self->send_service_msg($cmd, $arg);
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CLIENT_SEND_RECEIVE_SERVICE_MSG_ERROR_DURING_SEND_SERVICE_MSG',
            params  => {
                EVAL_ERROR => $EVAL_ERROR,
            },
        );
    }
    my $rc;
    eval {
        $rc = $self->collect();
    };
    if (my $eval_err = $EVAL_ERROR) {

        # TODO - server closes socket when getting the LOGOUT command
        # which crahes the collect method, should be fixed in server, see #300
        if ($cmd eq 'LOGOUT') {
             return { 'SERVICE_MSG' => 'LOGOUT' };
        }

        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_CLIENT_SEND_RECEIVE_SERVICE_MSG_ERROR_DURING_COLLECT',
            params  => {
                EVAL_ERROR => $eval_err,
                STATE      => $self->get_communication_state(),
            },
        );
    }
    ##! 4: Dumper $rc
    return $rc;
}


# send service message and read response
sub send_receive_command_msg {
    my $self  = shift;
    my $ident = ident $self;
    my $cmd   = shift;
    my $arg   = shift;

    ##! 1: "send_receive_command_msg"
    ##! 2: $cmd
    ##! 4: Dumper $arg

    $self->send_command_msg($cmd, $arg);
    my $rc = $self->collect();
    ##! 4: Dumper $rc
    return $rc;
}


###########################################################################

sub init_session {
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

    ##! 4: "initialize session"
    if (defined $args->{SESSION_ID}) {
        ##! 8: "using existing session"
        $self->talk({
            SERVICE_MSG => 'CONTINUE_SESSION',
            SESSION_ID  => $args->{SESSION_ID},
        });
    } else {
        ##! 8: "creating new session"
        ##! 8: "FIXME: we should send the preferred language here"
        $self->talk({
            SERVICE_MSG => "NEW_SESSION",
        });
    }

    my $msg = $self->collect();

    # init a new session if reload failed
    if (! defined $msg->{SESSION_ID} &&
        $args->{SESSION_ID} && $args->{NEW_ON_FAIL}) {
        $self->talk({
            SERVICE_MSG => "NEW_SESSION",
        });
        $msg = $self->collect();
    }

    if (! defined $msg->{SESSION_ID}) {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_CLIENT_INIT_SESSION_FAILED",
            params  => {
                MESSAGE_FROM_SERVER => Dumper $msg,
            });
    }

    $sessionid{$ident} = $msg->{SESSION_ID};

    $self->talk(
    {
        SERVICE_MSG => 'SESSION_ID_ACCEPTED',
    });

    # we want to be able to send after initialization, so collect a message!
    $msg = $self->collect();
    return $msg;
}

sub rekey_session {
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

    # if no session exists (e.g after logout or socket timeout)
    # we start a new session
    if (!$sessionid{$ident}) {
        return $self->init_session();
    }

    $self->talk({
        SERVICE_MSG => "RESET_SESSIONID",
    });

    my $msg = $self->collect();

    if (! defined $msg->{SESSION_ID}) {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_CLIENT_REKEY_SESSION_FAILED",
            params  => {
                MESSAGE_FROM_SERVER => Dumper $msg,
            });
    }

    $sessionid{$ident} = $msg->{SESSION_ID};

    $self->talk(
    {
        SERVICE_MSG => 'SESSION_ID_ACCEPTED',
    });

    # we want to be able to send after initialization, so collect a message!
    $msg = $self->collect();
    return $msg;
}


sub detach {
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;


    my $msg;
    eval {
        $msg = $self->send_receive_service_msg('DETACH_SESSION')
    };

    $sessionid{$ident} = undef;

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
    return undef;
}


sub logout {
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

    my $msg;

    $msg = $self->send_receive_service_msg('LOGOUT');

    $sessionid{$ident} = undef;

    if (defined $msg &&
        ref $msg eq 'HASH' &&
        $msg->{SERVICE_MSG} eq 'LOGOUT') {
        return 1;
    }

    OpenXPKI::Exception->throw(
        message => "I18N_OPENXPKI_CLIENT_LOGOUT_FAILED",
        params  => {
            MESSAGE_FROM_SERVER => Dumper $msg,
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

    # get current session status
    eval
    {
        my $msg = $self->send_receive_service_msg('PING');
    };
    if (my $exc = OpenXPKI::Exception->caught())
    {
        if ($exc->message() eq 'I18N_OPENXPKI_TRANSPORT_SIMPLE_WRITE_ERROR_DURING___SEND') {
            # this is probably an OpenXPKI server that died at the
            # other end
            # normal missing connection => 0
            return 0;
        } else {
            # OpenXPKI::Exception but from where ? => undef
            return undef;
        }
    } elsif ($EVAL_ERROR) {
        # completely unkown die => -1
        return -1;
    }
    return 1;
}

sub close_connection {
    my $self = shift;
    my $ident = ident $self;

    shutdown($socket{$ident}, 2); # we have stopped using this socket
}

###########################################################################
# private methods

sub __init_connection : PRIVATE {
    my $self = shift;
    my $ident = ident $self;

    ##! 2: "Initialize server socket connection"
    ##! 4: "socket..."
    if (! socket($socket{$ident}, PF_UNIX, SOCK_STREAM, 0))
    {
    OpenXPKI::Exception->throw(
        message => "I18N_OPENXPKI_CLIENT_INIT_CONNECTION_NO_SOCKET",
        );
    }
    ##! 4: "connect..."
    if (! connect($socket{$ident}, sockaddr_un($socketfile{$ident})))
    {
    OpenXPKI::Exception->throw(
        message => "I18N_OPENXPKI_CLIENT_INIT_CONNECTION_FAILED",
        params  => {
            SOCKETFILE => $socketfile{$ident},
            ERROR      => $!,
        });
    }
    ##! 4: "finished"
    return 1;
}

sub __init_transport_protocol : PRIVATE {
    my $self = shift;
    my $ident = ident $self;

    my $msg;

    ##! 8: "send requested transport protocol to server"
    send($socket{$ident}, "start $transport_protocol{$ident}\n", 0);

    ##! 8: "receive answer from server"
    read($socket{$ident}, $msg, 3); ## read OK

    ##! 8: "evaluate answer"
    if ($msg ne "OK\n")
    {
        ##! 16: "transport protocol was not accepted by server - $msg"
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_CLIENT_INIT_TRANSPORT_PROTOCOL_REJECTED",
        );
    }

    ##! 8: "intializing transport protocol"
    # FIXME: dynamically assign transport protocol
    $transport{$ident} = OpenXPKI::Transport::Simple->new(
    {
        SOCKET => $socket{$ident},
    });

    ##! 4: "finished"
    return 1;
}


sub __init_serialization_protocol : PRIVATE {
    my $self = shift;
    my $ident = ident $self;

    ##! 4: "request serialization protocol"
    ##! 8: "send requested protocol to server"
    $transport{$ident}->write($serialization_protocol{$ident}); ## send simple

    ##! 8: "receive answer from server"
    my $msg = $transport{$ident}->read();   ## read 'OK'

    ##! 8: "evaluate answer"
    if ($msg ne "OK")
    {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_CLIENT_INIT_SERIALIZATION_PROTOCOL_REJECTED",
        );
    }

    ##! 8: "intializing serialization protocol"
    my $class = "OpenXPKI::Serialization::" . $serialization_protocol{$ident};
    $serialization{$ident} = $class->new();

    # initialize communication state; the first message must be a write
    # operation to the socket
    $self->set_communication_state('can_send');

    ##! 4: "finished"
    return 1;
}

sub __init_service_protocol : PRIVATE {
    my $self = shift;
    my $ident = ident $self;

    ##! 4: "request service protocol"
    $self->talk($service_protocol{$ident});
    my $msg = $self->collect();

    if ($msg ne "OK")
    {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_CLIENT_INIT_SERVICE_PROTOCOL_REJECTED",
        );
    }

    ##! 4: "finished"
    return 1;
}

1;
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
