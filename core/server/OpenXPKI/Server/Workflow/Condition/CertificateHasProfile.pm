package OpenXPKI::Server::Workflow::Condition::CertificateHasProfile;

use strict;
use warnings;
use base qw( OpenXPKI::Server::Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Debug;
use English;
use OpenXPKI::Exception;


sub _evaluate {
    ##! 1: 'start'
    my ( $self, $workflow ) = @_;
    my $context     = $workflow->context();
    my $pki_realm   = CTX('session')->data->pki_realm;

    my $identifier = $self->param('cert_identifier') // $context->param('cert_identifier');

    configuration_error('No identifier passed to CertificateHasProfile');

    my $expected_profile = $self->param('expected_profile');
    configuration_error('You must set expected_profile') unless($expected_profile);

    my $profile = CTX('api2')->get_profile_for_cert( identifier => $identifier );
    condition_error('No profile was found') unless ($profile);

    ##! 16: "Is: $profile - expect: $expected_profile"
    if ($expected_profile ne $profile) {
        CTX('log')->application()->debug("Cert profile check failed: $profile != $expected_profile");
        condition_error 'Profiles dont match in CertificateHasProfile';
    }

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::CertificateHasProfile

=head1 DESCRIPTION

The condition checks if the certificate identified by cert_identifier
has the profile given in the parameter expected_profile. Certificatea are
checked over all realms.

=head1 Configuration

    is_tls_serveR_profile:
        class: OpenXPKI::Server::Workflow::Condition::CertificateHasProfile
        param:
          expected_profile: tls-server

=head2 Parameters

=over

=item expected_profile

=item cert_identifier

The certificate to check, if not present as explicit parameter the context
value with same key will be used.

=back

