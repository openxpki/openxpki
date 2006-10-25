package OpenXPKI::Client::API;

use English;
use strict;
use warnings;

use Class::Std;

use OpenXPKI::Debug 'OpenXPKI::Client::API';
use OpenXPKI::Exception;

# use Smart::Comments;
use Data::Dumper;

my %client : ATTR( :init_arg<CLIENT> );


sub AUTOMETHOD {
    my $self  = shift;
    my $ident = shift;
    my $arg   = shift;

    ### mapping server API call...
    ### $_
    
    my $cmd = $_;
    return sub {
	return $client{$ident}->send_receive_command_msg($cmd, $arg);
    }
}

1;

__END__

=head1 NAME

OpenXPKI::Client::API

=head1 Description

OpenXPKI Server API mirror. This class roughly implements somethin akin
to RPCs. It tries to call a remote command on the server, reads the
response and delivers it to the caller.

See OpenXPKI::Server::API for API documentation.

=head1 Functions

=head2 AUTOMETHOD

Automatically catches undefined method calls and redirects them to the
Server API via the Client.
