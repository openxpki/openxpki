package OpenXPKI::Service::SCEP;

use base qw( OpenXPKI::Service::LibSCEP );

use strict;
use warnings;
use English;

use Class::Std;

## used modules

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Service::SCEP::Command;

sub __init_encryption_alg : PROTECTED {
    ##! 4: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $arg_ref = shift;

    my $message = $self->collect();
    ##! 16: "message collected: " . Dumper($message)
    my $requested_encryption_alg;
    if ( $message =~ /^SELECT_ENCRYPTION_ALGORITHM (.*)/ ) {
        $requested_encryption_alg = $1;
        ##! 16: "requested encryption_alg: $requested_encryption_alg"
    } else {
        OpenXPKI::Exception->throw( message =>
                "I18N_OPENXPKI_SERVICE_SCEP_NO_SELECT_ENCRYPTION_ALGORITHM_RECEIVED",
        );
        # this is an uncaught exception
    }

    if (   $requested_encryption_alg eq 'DES'
        || $requested_encryption_alg eq '3DES' )
    {
        # the encryption_alg is valid
        $self->talk('OK');
        return $requested_encryption_alg;
    }

    $self->talk('NOTFOUND');
    OpenXPKI::Exception->throw(
        message =>
            "I18N_OPENXPKI_SERVICE_SCEP_INVALID_ALGORITHM_REQUESTED",
        params => { REQUESTED_ALGORITHM => $requested_encryption_alg },
    );

}


sub __get_command {

    my $self = shift;
    my $ident = ident $self;
    my $command = shift;
    my $params = shift;

    return OpenXPKI::Service::SCEP::Command->new({
        COMMAND => $command,
        PARAMS  => $params,
    });

}

1;
__END__

=head1 Name

OpenXPKI::Service::SCEP - SCEP service implementation

=head1 Description

This is the Service implementation which is used by SCEP clients.
The protocol is simpler than in the Default implementation, as it
does not use user authentication and session handling.

=head1 Protocol Definition

The protocol starts with the client sending a "SELECT_PKI_REALM" message
indicating which PKI realm the clients wants to use. Depending on whether
this realm is available at the server or not, the server responds with
either "OK" or "NOTFOUND".

