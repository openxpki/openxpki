# OpenXPKI::Transport::Simple.pm
# Written 2006 by Michael Bell for the OpenXPKI project
# (C) Copyright 2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Transport::Simple;

use OpenXPKI::VERSION;
our $VERSION = $OpenXPKI::VERSION::VERSION;

use English;
use OpenXPKI::Exception;

use OpenXPKI::Debug;

$OUTPUT_AUTOFLUSH = 1;
our $MAX_MSG_LENGTH = 1048576; # 1024^2

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

    for (my $i=0; $i < length($data)/$MAX_MSG_LENGTH-1;$i++)
    {
        ##! 4: "sending intermediate message"
        my $msg = substr ($data, 0, $MAX_MSG_LENGTH);
        $self->__send ("type::=intermediate\n".
                       "length::=".length($msg)."\n".
                       $msg);
        my $ok;
        $ok = $self->__receive (3);
        if ($ok ne "OK\n")
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_TRANSPORT_SIMPLE_WRITE_MISSING_OK",
            );
        }
        $data = substr ($data, $MAX_MSG_LENGTH);
    }
    ##! 4: "sending last message"
    my $msg = "type::=last\n".
              "length::=".length($data)."\n".
              $data;
    eval {
        $self->__send ($msg);
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_TRANSPORT_SIMPLE_WRITE_ERROR_DURING___SEND',
            params  => {
                'EVAL_ERROR' => $EVAL_ERROR,
            },
        );
    }

    if ($self->{STDOUT})
    {
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

    my $type = "intermediate";
    my $msg = "";

    while ($type ne "last")
    {
        my $line   = "";
        my $tmp    = "";
        my $length = 8;

        ##! 4: "read type line"

        ## read until "type::=_"
        $tmp = $self->__receive (8);
        ##! 4: "type line: $tmp"
        if (substr ($tmp, 7, 1) eq "i")
        {
            ##! 8: "intermediate message part"
            $length = 12;
        }
        elsif (substr ($tmp, 7, 1) eq "l")
        {
            ##! 8: "last message part"
            $type   = "last"; 
            $length = 4;
        }
        else
        {
            ##! 8: "illegal type"
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_TRANSPORT_SIMPLE_CLIENT_READ_WRONG_MESSAGE_TYPE");
        }
        $tmp = $self->__receive ($length);

        ##! 4: "read length line"

        ## read until "length::="
        $tmp = $self->__receive (9);
        $line   = "";
        $length = 1;
        while ($length == 1)
        {
            $tmp = $self->__receive (1);
            if ($tmp =~ /^[0-9]$/)
            {
                $line .= $tmp;
            } else {
                ## newline read
                $length = 0;
            }
        }
        $length = $line;
        ##! 4: "length: $length"

        my $mesg = "";
        while (length ($mesg) < $length)
        {
            $mesg .= $self->__receive ($length - length($mesg));
        }
        ##! 4: "$type message: $mesg"

        if (length($mesg) < $length)
        {
            ## should never be reached
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_TRANSPORT_SIMPLE_CLIENT_READ_DAMAGED_MESSAGE");
        }

        $msg .= $mesg;
    }
    ##! 2: "message read successfully - $msg"

    if ($self->{STDOUT})
    {
        ##! 8: "close file"
        CORE::close $self->{STDIN};
        delete $self->{STDIN};
    }

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
        send ($self->{SOCKET},$msg,0);
        ## $self->{SOCKET}->flush();
    }
    else
    {
        ##! 8: "print message via STDOUT"
        print STDOUT $msg;
        ##! 8: "print completed"
    }
    ##! 4: "wrote message - $msg"
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
        ##! 8: "using socket to read some data"
        $length = CORE::read $self->{SOCKET}, $msg, $length;
        ##! 128: 'socket receive: ' . $msg
    }
    else
    {
        ##! 8: "read via STDIN"
        eval {
            $length = CORE::read STDIN, $msg, $length;
        };
        if ($EVAL_ERROR) {
	    if ($EVAL_ERROR eq "alarm\n") {
		# our caller may have set an alarm signal handler, if we
		# die here, simply propagate this exception
		die $EVAL_ERROR;
	    }
            ##! 16: 'EVAL_ERROR!'
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_TRANSPORT_SIMPLE_CLIENT_READ_FAILED',
                params  => {
                    'EVAL_ERROR' => $EVAL_ERROR,
                },
            );
        }
        ##! 8: "read $length bytes - $msg"
    }
    if (not $length)
    {
        ##! 8: "connection closed"
        OpenXPKI::Exception->throw (
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
