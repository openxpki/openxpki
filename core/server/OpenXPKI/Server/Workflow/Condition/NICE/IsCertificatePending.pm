## OpenXPKI::Server::Workflow::Condition::NICE::IsCertificatePending.pm
##
## Written 2011 by Oliver Welter <openxpki@oliwel.de>
## for the OpenXPKI project
## (C) Copyright 2011 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Condition::NICE::IsCertificatePending;

use strict;
use warnings;
use base qw( Workflow::Condition );
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

