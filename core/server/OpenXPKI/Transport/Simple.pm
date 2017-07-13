use strict;
use warnings;

package OpenXPKI::Transport::Simple;

use OpenXPKI::VERSION;
our $VERSION = $OpenXPKI::VERSION::VERSION;

use English;
use OpenXPKI::Exception;
use OpenXPKI::Debug;

# If you encounter problems with corrupted transports, try enabling
# the base64 encode/decode in the read/write methods
#use MIME::Base64;

$OUTPUT_AUTOFLUSH = 1;
our $MAX_MSG_LENGTH = 1048544;

sub new
{
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    bless $self, $class;
    ##! 1: "initializing simple transport layer ..."

    my $keys = shift;
    $self->{INFILE}  = $keys->{INFILE}  if (exists $keys->{INFILE});
    $self->{OUTFILE} = $keys->{OUTFILE} if (exists $keys->{OUTFILE});
    $self->{SOCKET}  = $keys->{SOCKET}  if (exists $keys->{SOCKET});

    ##! 1: "transport layer successfully initialized"
    return $self;
}

sub close
{
    return 1;
}

sub write
{
    my $self = shift;
    my $data = shift;
    ##! 1: "start"

    ##! 2: "send message"

    my @list = ();

    # The data string might have the utf8 flag set - to prevent messing with
    # wide chars / length issues on the transport, we do a "downgrade" which
    # will make the string look like a sequence of 8-bit chars.
    # We will upgrade on the other side of the transport again
    utf8::downgrade( $data );

#    $data = encode_base64( $data );

    # while the message is to large for the buffer, we send only chunks
    while ( length($data) > $MAX_MSG_LENGTH ) {

        ##! 4: "sending intermediate message"
        ##! 8: "size of (remaining) message " . length($data)
        $self->__send ( "type::=chunk\n" .
            sprintf("length::=%08d\n", $MAX_MSG_LENGTH) .
            substr ($data, 0, $MAX_MSG_LENGTH));

        # await confirmation
        if ($self->__receive (3) ne "OK\n") {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_TRANSPORT_SIMPLE_WRITE_MISSING_OK",
            );
        }

        # shift off already send data
        $data = substr ($data, $MAX_MSG_LENGTH);
    }

    ##! 4: "sending last message"
    $self->__send ( "type::=final\n" .
        sprintf("length::=%08d\n", length($data)).
        $data);

    if ($self->{STDOUT}) {
        ##! 8: "close file"
        CORE::close $self->{STDOUT};
        delete $self->{STDOUT};
    }

    ##! 1: "end"
    return 1;
}

sub read
{
    my $self = shift;
    ##! 1: "start"

    ##! 2: "read new message"

    my $type;
    my $msg = "";

    do {

        my $tmp;

        ##! 4: "read type line"
        ## type is always 5 chars, + 7 prefix + EOL
        $tmp = $self->__receive(13);

        ##! 4: "type line: $tmp"
        $type = substr($tmp, 7, 5);

        if ($type !~ /chunk|final/) {
            ##! 8: "illegal type " . $type
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_TRANSPORT_SIMPLE_CLIENT_READ_WRONG_MESSAGE_TYPE",
                params => { TYPE => $type }
            );
        }

        ##! 4: "read length line"
        ## length is always 8 digits + prefix + EOL
        $tmp = $self->__receive(18);

        my $length = substr($tmp,9,8);

        if ((substr($tmp,0,6) ne 'length') || ($length !~ /\d{8}/)) {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_TRANSPORT_SIMPLE_CLIENT_READ_LENGTH_EXPECTED",
                params => { READ => $tmp }
            );
        }

        ##! 4: "length: $length"

        my $buffer = "";
        # receive might not return all bytes on first call, loop required
        while (length ($buffer) < $length) {
            $buffer .= $self->__receive ( $length - length($buffer) );
        }

        $msg .= $buffer;

        # sender expects an "OK" before the next chunk is send
        if ( $type eq "chunk" ) {
            $self->__send("OK\n");
        }

    } while ($type ne "final");

    ##! 2: "message read successfully - $msg"

    if ($self->{STDOUT})
    {
        ##! 8: "close file"
        CORE::close $self->{STDIN};
        delete $self->{STDIN};
    }


#    $msg = decode_base64( $msg );
    # Transmission is done with plain 8-bit, we make the string "be" utf8
    # again by calling upgrade. See docs for known issues
    utf8::upgrade( $msg );

    return $msg;
}

sub __send
{
    my $self = shift;
    my $msg  = shift;

    if (exists $self->{OUTFILE})
    {
        ##! 8: "open file for writing"
        if (not exists $self->{STDOUT} and
            not open $self->{STDOUT}, ">".$self->{OUTFILE})
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_TRANSPORT_SIMPLE_CLIENT_NEW_OPEN_OUTFILE_FAILED",
                params  => {OUTFILE => $self->{OUTFILE}}
            );
        }
        print {$self->{STDOUT}} $msg;
    }
    elsif (exists $self->{SOCKET})
    {
        ##! 8: "using socket to write some data"
        ##! 128: 'socket send: ' . $msg
        eval {
            send ($self->{SOCKET},$msg,0);
        };
        if ($EVAL_ERROR) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_TRANSPORT_SIMPLE_WRITE_ERROR_DURING_SOCKET_SEND',
                params  => {
                    'EVAL_ERROR' => $EVAL_ERROR,
                    'MESSAGE' => substr($msg,0,50)
                },
            );
        }
    }
    else
    {
        ##! 8: "print message via STDOUT"
        print STDOUT $msg;
        ##! 8: "print completed"
    }
    ##! 4: "wrote message"
    return 1;
}

sub __receive
{
    my $self   = shift;
    my $length = shift;
    my $msg    = "";

    ##! 4: "start"

    if (exists $self->{INFILE})
    {
        ##! 8: "using infile to read some data"
        if (not exists $self->{STDIN} and
            not open $self->{STDIN}, "<".$self->{INFILE})
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_TRANSPORT_SIMPLE_CLIENT_NEW_OPEN_INFILE_FAILED",
                params  => {INFILE => $self->{INFILE}}
            );
        }
        $length = CORE::read $self->{STDIN}, $msg, $length;
    }
    elsif (exists $self->{SOCKET})
    {
        ##! 8: "using socket to read $length byte of data"
        $length = CORE::read $self->{SOCKET}, $msg, $length;
        ##! 128: 'socket receive: ' . $msg
    }
    else
    {
        ##! 8: "read via STDIN"
        eval {
            $length = CORE::read STDIN, $msg, $length;
        };
        if (my $eval_err = $EVAL_ERROR) {
            if ($eval_err eq "alarm\n") {
                # our caller may have set an alarm signal handler, if we
                # die here, simply propagate this exception
                die $eval_err;
            }
            ##! 16: 'EVAL_ERROR!'
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_TRANSPORT_SIMPLE_CLIENT_READ_FAILED',
                params  => { EVAL_ERROR => $eval_err },
            );
        }
        ##! 8: "read $length bytes - $msg"
    }
    if (not $length)
    {
        ##! 8: "connection closed"
        OpenXPKI::Exception->throw(
           message => "I18N_OPENXPKI_TRANSPORT_SIMPLE_CLIENT_READ_CLOSED_CONNECTION",
           log => undef, # do not log exception
        );
    }
    ##! 4: "read message - $msg"
    return $msg;
}

1;

__END__

=head1 Name

OpenXPKI::Transport::Simple - basic transport protocol.

=head1 Description

This is the interface specification for all common OpenXPKI
transport protocol implementations. Please note that every
read operation returns an interpretable answer. We do not
return partial messages.

To handle utf8 transparently, we assume that data stream are B<always>
utf8 sequences. Therefore the transport will corrupt data that might
be missinterpreted by the utf8::upgrade pragma and we strongly recommend
to base64 encode all data that is neither UTF8 nor plain ASCII!

=head1 Functions

=head2 new

accepts only INFILE and OUTFILE as parameters. It takes over the
complete communication via STDIN and STDOUT. If INFILE is specified then
messages are written to INFILE instead of STDIN. If OUTFILE is
present than messages are read from OUTFILE instead of STDOUT.

Example:

my $transport = OpenXPKI::Transport::Simple->new ({});

=head2 close

close the connection and calls DESTROY.

=head2 write

send a message.

=head2 read

read a message.

=head1 internal communication protocol

A header is added to the data to correctly handle reading from the socket.

The header has a fixed format::

  type::=final
  length::=12345678
  <data>

=head2 type

The default type is I<final>, which means this is the last message (most
times the only one) and all data was transmitted after this package was read.
If the data is too large to fit into a single package, it is splitted into
several parts, each one with the maximum allowed size. Those intermediate
packages are transmitted wit the type set to I<chunk>.

The maximum allowed size is a fixed value of 1048544 bytes (2^20 - 32).
The 32 bytes are sufficient to place the header, so the total size is
always below 1MB.

=head2 length

The length of the raw data portion in bytes, to ease parsing this is
always written with 8 digit using decimal notation.


