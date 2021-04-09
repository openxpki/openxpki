package OpenXPKI::Server::Workflow::Condition::CertificateIsLocalEntity;

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
    my $pki_realm   = $self->param('pki_realm') || CTX('session')->data->pki_realm;

    my $identifier = defined $self->param('cert_identifier') ? $self->param('cert_identifier') : $context->param('cert_identifier');

    if (!$identifier) {
        if ($self->param('empty_ok')) {
            condition_error('No identifier passed to CertificateIsLocalEntity');
        } else {
            configuration_error('No identifier passed to CertificateIsLocalEntity');
        }
    }

    if (!CTX('api2')->is_local_entity( identifier => $identifier, pki_realm => $pki_realm )) {
        CTX('log')->application()->debug("Cert is not a local entity");
        condition_error 'cert is not a local entity';
    }

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::CertificateIsLocalEntity

=head1 DESCRIPTION

The condition checks if the certificate identified by cert_identifier is
an entity in the given realm.

=head1 Configuration

    is_local_entity:
        class: OpenXPKI::Server::Workflow::Condition::CertificateIsLocalEntity
        param:
          expected_profile: tls-server

=head2 Parameters

=over

=item expected_profile

=item cert_identifier

The certificate to check, if not present as explicit parameter the context
value with same key will be used.

=item pki_realm

Optional, the default is to check the entity against the current realm, can
be another realm name or I<_any> to accept entities from all realms.

=item empty_ok

Boolean, if true the condition will silently be false if cert_identifier
is not set. If not set, a configuration_error is thrown.

=back

