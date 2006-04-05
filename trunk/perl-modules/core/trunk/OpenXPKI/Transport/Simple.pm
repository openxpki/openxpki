# OpenXPKI::Transport::Simple.pm
# Written 2006 by Michael Bell for the OpenXPKI project
# (C) Copyright 2006 by The OpenXPKI Project
# $Revision$

use strict;
use warnings;

package OpenXPKI::Transport::Simple;

use English;
use OpenXPKI::Exception;
use OpenXPKI::Debug 'OpenXPKI::Transport::Simple';

$OUTPUT_AUTOFLUSH = 1;
our $MAX_MSG_LENGTH = 1048576; # 1024^2

sub new
{
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {
                "STDIN"  => *STDIN,
                "STDOUT" => *STDOUT
               };

    bless $self, $class;

    my $keys = shift;
    $self->{INFILE}  = $keys->{INFILE}  if (exists $keys->{INFILE});
    $self->{OUTFILE} = $keys->{OUTFILE} if (exists $keys->{OUTFILE});

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

    ## open file for writing if necessary

    if (exists $self->{OUTFILE} and
        (
         not delete $self->{STDOUT} or
         not open $self->{STDOUT}, ">".$self->{OUTFILE}
        )
       )
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_TRANSPORT_SIMPLE_CLIENT_NEW_OPEN_OUTFILE_FAILED",
            params  => {OUTFILE => $self->{OUTFILE}}
        );
    }

    ## send message

    my @list = ();

    for (my $i=0; $i < length($data)/$MAX_MSG_LENGTH-1;$i++)
    {
        my $msg = substr ($data, 0, $MAX_MSG_LENGTH);
        print {$self->{STDOUT}} "type::=intermediate\n".
                                "length::=".length($msg)."\n";
        print {$self->{STDOUT}} $msg;
        $self->{STDOUT}->flush();
        ## FIXME: we must flush the file descriptor ?!
        my $ok;
        read {$self->{STDIN}}, $ok, 3;
        if ($ok ne "OK\n")
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_TRANSPORT_SIMPLE_WRITE_MISSING_OK",
            );
        }
        $data = substr ($data, $MAX_MSG_LENGTH);
    }
    print {$self->{STDOUT}} "type::=last\n".
                            "length::=".length($data)."\n";
    print {$self->{STDOUT}} $data;

    ## close file to flush data

    CORE::close $self->{STDOUT} if (exists $self->{OUTFILE});

    return 1;
}

sub read
{
    my $self = shift;

    ## open file to read new data if nessary

    if (exists $self->{INFILE} and
        (
         not delete $self->{STDIN} or
         not open $self->{STDIN}, "<".$self->{INFILE}
        )
       )
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_TRANSPORT_SIMPLE_CLIENT_NEW_OPEN_INFILE_FAILED",
            params  => {INFILE => $self->{INFILE}}
        );
    }

    ## read new message

    my $type = "intermediate";
    my $msg = "";

    while ($type ne "last")
    {
        my $line   = "";
        my $tmp    = "";
        my $length = 8;

        ## read type line

        ## read until "type::=_"
        if (not read $self->{STDIN}, $tmp, 8)
        {
            # connection closed
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_TRANSPORT_SIMPLE_CLIENT_READ_CLOSED_CONNECTION");
        }
        if (substr ($tmp, 7, 1) eq "i")
        {
            # intermediate message part
            $length = 12;
        }
        elsif (substr ($tmp, 7, 1) eq "l")
        {
            # last message part
            $type   = "last"; 
            $length = 4;
        }
        else
        {
            # illegal type
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_TRANSPORT_SIMPLE_CLIENT_READ_WRONG_MESSAGE_TYPE");
        }
        read $self->{STDIN}, $tmp, $length;

        ## read length line

        ## read until "length::="
        read $self->{STDIN}, $tmp, 9;
        $line   = "";
        $length = 1;
        while ($length == 1)
        {
            read $self->{STDIN}, $tmp, 1;
            if ($tmp =~ /^[0-9]$/)
            {
                $line .= $tmp;
            } else {
                ## newline read
                $length = 0;
            }
        }
        $length = $line;

        my $mesg = "";
        while (length ($mesg) < $length and read ($self->{STDIN}, $tmp, $length - length($mesg)))
        {
            $mesg .= $tmp;
        }

        if (length($mesg) < $length)
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_TRANSPORT_SIMPLE_CLIENT_READ_DAMAGED_MESSAGE");
        }

        $msg .= $mesg;
    }

    ## close file if necessary

    CORE::close $self->{STDIN} if (exists $self->{INFILE});

    return $msg;
}

1;

__END__

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
