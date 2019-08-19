package OpenXPKI::Server::Workflow::Activity::Tools::GetCertificateIdentifier;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use Workflow::Exception qw(configuration_error);

sub execute {
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    my $certificate = $self->param('certificate') // $context->param('certificate');

    return unless($certificate);

    my $cert_identifier  = CTX('api2')->get_cert_identifier(cert => $certificate);

    CTX('log')->application()->debug('Identifier of certificate is ' . $cert_identifier);

    my $target_key = $self->param('target_key') || 'cert_identifier';
    $context->param( $target_key  => $cert_identifier );

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::GetCertificateIdentifier

=head1 Description

Calculate the certificate's identifier

=head1 Parameters

=over

=item certificate

the PEM encoded certificate, default is context value of certificate

=item target_key

Context parameter to use for certificate identifier output
(default: cert_identifier)

=back
