package OpenXPKI::Server::Authentication::ClientX509;

use Moose;
extends 'OpenXPKI::Server::Authentication::X509';

use English;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

use DateTime;
use Data::Dumper;

sub handleInput {

    ##! 1: 'start'
    my $self  = shift;
    my $msg   = shift;

    ##! 2: 'login data received'
    ##! 64: $msg
    my $certificate = $msg->{certificate};

    return unless($certificate);

    $self->logger->debug('Incoming auth with x509 handler');
    $self->logger->trace("Login using x509 certificate:\n$certificate") if ($self->logger->is_trace);

    my $trust_anchors = $self->trust_anchors();
    ##! 32: 'trust anchors ' . Dumper $trust_anchors

    $self->logger->trace("Trust Anchors: ". Dumper $trust_anchors) if ($self->logger->is_trace);

    return OpenXPKI::Server::Authentication::Handle->new(
        error_message => 'No trustanchors defined',
        error => OpenXPKI::Server::Authentication::Handle::UNKNOWN_ERROR,
    ) unless($trust_anchors);

    my $validate = CTX('api2')->validate_certificate(
        pem => $msg->{certificate},
        chain => $msg->{chain} // [],
        anchor => $trust_anchors,
    );

    return $self->_validation_result( $validate );

}

__PACKAGE__->meta->make_immutable;

__END__

=head1 OpenXPKI::Server::Authentication::ClientX509

Leaves the SSL negotation to the client, requires the certificate chain
of the authenticated client to be passed.

See OpenXPKI::Server::Authentication::X509 for configuration and options.

