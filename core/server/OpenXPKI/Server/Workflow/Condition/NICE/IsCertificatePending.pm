package OpenXPKI::Server::Workflow::Condition::NICE::IsCertificatePending;
use OpenXPKI;

use parent qw( Workflow::Condition );

use Workflow::Exception qw( condition_error configuration_error );


sub evaluate {

    ##! 1: 'start'
    my ( $self, $workflow ) = @_;
    my $context = $workflow->context();

    condition_error("I18N_OPENXPKI_SERVER_CONNECTOR_VICE_CONDITION_CERTIFICATE_NOT_PENDING") unless $context->param('cert_identifier') eq 'pending';

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::NICE::IsCertificatePending

=head1 DESCRIPTION

Check the workflow table for the entry certificate => 'pending'.

