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
    ##! 16: "identifier: $cert_identifier, user $user"
    my $res = CTX('api2')->is_certificate_owner(
        identifier => $cert_identifier,
        user => $user
    );

    if (!defined $res) {
        ##! 16: 'owner is not defined'
        CTX('log')->application()->warn("IsCertificateOwner condition failed - no owner found");

        condition_error('user is certificate owner no owner found');
    }

    if (!$res) {
        ##! 16: 'owner does not match'
        CTX('log')->application()->debug("IsCertificateOwner condition failed - owner not matches");

        condition_error('user is certificate owner failed');
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
