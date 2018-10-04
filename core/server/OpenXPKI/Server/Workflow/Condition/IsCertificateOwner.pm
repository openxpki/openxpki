
package OpenXPKI::Server::Workflow::Condition::IsCertificateOwner;

use strict;
use warnings;
use base qw( OpenXPKI::Server::Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;

use Data::Dumper;

sub evaluate {
    ##! 1: 'start'
    my ( $self, $workflow ) = @_;

    my $context  = $workflow->context();
    ##! 64: 'context: ' . Dumper($context)

    my $cert_identifier = $self->param('cert_identifier');
    $cert_identifier = $context->param('cert_identifier') unless($cert_identifier);

    if (!defined $cert_identifier ) {
        configuration_error('You need to have cert_identifier in context or set it via the parameters');
    }

    my $user = $self->param('cert_owner') || '';

    my $res = CTX('api')->is_certificate_owner({ IDENTIFIER => $cert_identifier , USER => $user });

    if (!defined $res) {
        ##! 16: 'owner is not defined'
        CTX('log')->application()->warn("IsCertificateOwner condition failed - no owner found");

        condition_error('I18N_OPENXPKI_UI_USER_IS_CERTIFICATE_OWNER_NO_OWNER_FOUND');
    }

    if (!$res) {
        ##! 16: 'owner does not match'
        CTX('log')->application()->debug("IsCertificateOwner condition failed - owner not matches");

        condition_error('I18N_OPENXPKI_UI_USER_IS_CERTIFICATE_OWNER_FAILED');
    }

    return 1;
    ##! 16: 'end'
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::IsCertificateOwner

=head1 SYNOPSIS


=head1 DESCRIPTION

This condition checks whether a given user (or the session user) is the
owner of the given certificate.
