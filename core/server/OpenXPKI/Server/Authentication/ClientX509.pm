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


sub handleInput {

    ##! 1: 'start'
    my $self  = shift;
    my $msg   = shift;

    ##! 2: 'login data received'
    ##! 64: $msg
    my $certificate = $msg->{certificate};

    return unless($certificate);

    my $trust_anchors = $self->trust_anchors();
    ##! 32: 'trust anchors ' . Dumper $trust_anchors

    my $validate = CTX('api2')->validate_certificate(
        pem => $msg->{certificate},
        chain => $msg->{chain} // [],
        anchor => $trust_anchors,
    );

    return $self->_validation_result( $validate );

}

1;
__END__

=head1 OpenXPKI::Server::Authentication::ClientX509

Leaves the SSL negotation to the client, requires the certificate chain
of the authenticated client to be passed.

See OpenXPKI::Server::Authentication::X509 for configuration and options.

