package OpenXPKI::Server::Authentication::ClientX509;

use strict;
use warnings;
use English;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

use DateTime;
use Data::Dumper;

use Moose;

extends 'OpenXPKI::Server::Authentication::X509';

sub login_step {

    ##! 1: 'start'
    my $self    = shift;
    my $arg_ref = shift;

    my $msg     = $arg_ref->{MESSAGE};
    my $params = $msg->{PARAMS};

    if (! $params->{certificate} ) {
        ##! 4: 'no login data received (yet)'
        return (undef, undef, {
            SERVICE_MSG => "GET_CLIENT_X509_LOGIN",
            PARAMS      => {
                NAME        => $self->label(),
                DESCRIPTION => $self->description(),
            },
        });
    }

    ##! 2: "credentials ... present"

    my $trust_anchors = $self->trust_anchors();
    ##! 32: 'trust anchors ' . Dumper $trust_anchors

    my $validate = CTX('api2')->validate_certificate(
        pem => $params->{certificate},
        anchor => $trust_anchors,
    );

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

