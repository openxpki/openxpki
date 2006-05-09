# OpenXPKI::Client
# Written 2006 by Michael Bell and Martin Bartosch for the OpenXPKI project
# (C) Copyright 2006 by The OpenXPKI Project
# $Revision$

package OpenXPKI::Client;
use Class::Std;

use version; 
our $VERSION = '0.9.$Revision$';
$VERSION =~ s{ \$ Revision: \s* (\d+) \s* \$ \z }{$1}xms;
$VERSION = qv($VERSION);

use warnings;
use strict;
use Carp;
use English;

$OUTPUT_AUTOFLUSH = 1;

use OpenXPKI::Debug 'OpenXPKI::Client';

use Socket;
use OpenXPKI qw( read_file i18nGettext );
use OpenXPKI::Exception;
use OpenXPKI::Transport::Simple;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Serialization::JSON;

# use Smart::Comments;

my %socketfile             : ATTR( :init_arg<SOCKETFILE> );
my %sessionid              : ATTR( :get<session_id> );
my %read_timeout           : ATTR( :default(30) :set<timeout> );

my %socket                 : ATTR;
my %transport_protocol     : ATTR( :default('Simple') );
my %serialization_protocol : ATTR( :default('Simple') );
my %transport              : ATTR;
my %serialization          : ATTR;



sub START {
    my ($self, $ident, $arg_ref) = @_;
    
    ##! 1: "Initialize protocol stack"
    $self->__init_connection();
    $self->__init_transport_protocol();
    $self->__init_serialization_protocol();
    $self->__init_service_protocol();

}


###########################################################################
# interface methods

# send message to server
sub talk {
    my $self  = shift;
    my $arg   = shift;
    my $ident = ident $self;
    
    return $transport{$ident}->write(
	$serialization{$ident}->serialize($arg)
	);
}

# get server response
sub collect {
    my $self  = shift;
    my $ident = ident $self;

    my $result;
    eval {
 	local $SIG{ALRM} = sub { die "alarm\n" };
	
 	alarm $read_timeout{$ident};
 	$result = $serialization{$ident}->deserialize(
 	    $transport{$ident}->read()
 	    );
 	alarm 0;
    };
    if ($EVAL_ERROR) {
 	if ($EVAL_ERROR eq "alarm\n") {
 	    return undef;
 	} else {
	    # FIXME
	    die $EVAL_ERROR;
	}
    }
    return $result;
}


sub init_session {
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

    if (exists $sessionid{$ident}) {
	# a specific session was requested, check if it's the current one
	if (defined $args->{SESSION_ID} 
	    && ($sessionid{$ident} ne $args->{SESSION_ID})) {
	    
	    OpenXPKI::Exception->throw(
		message => "I18N_OPENXPKI_CLIENT_INIT_SESSION_ALREADY_ESTABLISHED",
		);
	}

	# session already established, return success
	return 1;
    }
    
    ##! 4: "initialize session"
    if (exists $args->{SESSION_ID}) {
	##! 8: "using existing session"
        $self->talk(
	    {
		SERVICE_MSG => 'CONTINUE_SESSION',
		SESSION_ID  => $args->{SESSION_ID},
	    });
    } else {
	##! 8: "creating new session"
        ##! 8: "FIXME: we should send the preferred language here"
        $self->talk(
	    {
		SERVICE_MSG => "NEW_SESSION",
	    });
    }

    my $msg = $self->collect();
    
    if (! exists $msg->{SESSION_ID})
    {
        OpenXPKI::Exception->throw(
	    message => "I18N_OPENXPKI_CLIENT_INIT_SESSION_FAILED",
	    params  => {
		ERROR => $msg->{ERROR},
	    });
    }
    
    $sessionid{$ident} = $msg->{SESSION_ID};
    
    $self->talk(
	{
	    SERVICE_MSG => 'SESSION_ID_ACCEPTED',
	});

    ##! 4: "finished"
    return 1;
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
    # FIXME: dynamically attach serializer
    $serialization{$ident} = OpenXPKI::Serialization::Simple->new();

    ##! 4: "finished"
    return 1;
}

sub __init_service_protocol : PRIVATE {
    my $self = shift;
    my $ident = ident $self;

    ##! 4: "request default service protocol"
    $self->talk('default');
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

=head2 collect

Reads an answer from the OpenXPKI server, deserializes the message and
returns the corresponding data structure.

=head2 init_session

Initialize session. If the named argument SESSION_ID exists, this session
is re-opened, otherwise a new session is created.

=head2 get_session_id

Returns current session ID (or undef if no session is active).

=head2 set_timeout

Set socket read timeout (seconds, default: 30).

=head1 DIAGNOSTICS


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
