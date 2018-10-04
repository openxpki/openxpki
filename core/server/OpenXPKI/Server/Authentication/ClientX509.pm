## OpenXPKI::Server::Authentication::ClientX509
##
## Written in 2007 by Alexander Klink
## (C) Copyright 2007 by The OpenXPKI Project

#FIXME-MIG: Need testing

package OpenXPKI::Server::Authentication::ClientX509;

use strict;
use warnings;
use English;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Crypto::X509;

use DateTime;
use Data::Dumper;

use Moose;

extends 'OpenXPKI::Server::Authentication::X509';

sub login_step {

    ##! 1: 'start'
    my $self    = shift;
    my $arg_ref = shift;

    my $name    = $arg_ref->{HANDLER};
    my $msg     = $arg_ref->{MESSAGE};
    my $answer  = $msg->{PARAMS};

    if (! exists $msg->{PARAMS}->{LOGIN}) {
        ##! 4: 'no login data received (yet)'
        return (undef, undef,
            {
        SERVICE_MSG => "GET_CLIENT_X509_LOGIN",
        PARAMS      => {
                    NAME        => $self->{NAME},
                    DESCRIPTION => $self->{DESC},
            },
            },
        );
    }

    ##! 16: 'Service Answer ' . Dumper $answer
    my $username = $answer->{LOGIN};
    my $certificate = $answer->{CERTIFICATE};

    ##! 2: "credentials ... present"
    ##! 2: "username: $username"
    ##! 2: "certificate: " . Dumper $certificate

    my $validate = CTX('api')->validate_certificate({
        PEM => $certificate,
        ANCHOR => $self->trust_anchors(),
    });

    return $self->_validation_result( $validate );

}

1;
__END__

=head1 Name

OpenXPKI::Server::Authentication::ClientX509 - support for client based X509 authentication.

=head1 Description

Leaves the SSL negotation to the client, requires the certificate chain of the authenticated
client to be passed.

See OpenXPKI::Server::Authentication::X509 for configuration and options.

