## OpenXPKI::Server::Workflow::Condition::NICE::IsCertificateIssued.pm
##
## Written 2011 by Oliver Welter <openxpki@oliwel.de>
## for the OpenXPKI project
## (C) Copyright 2011 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Condition::NICE::IsCertificateIssued;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );

sub evaluate {

    ##! 1: 'start'
    my ( $self, $workflow ) = @_;
    my $context = $workflow->context();

    condition_error("I18N_OPENXPKI_SERVER_CONNECTOR_NICE_CONDITION_CERTIFICATEISSUED_NOENTRY") unless $context->param('cert_identifier');

    condition_error("I18N_OPENXPKI_SERVER_CONNECTOR_NICE_CONDITION_CERTIFICATEISSUED_STILLPENDING") if $context->param('cert_identifier') eq 'pending';

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::NICE::IsCertificateIssued

=head1 DESCRIPTION

Check the workflow table for a certificate.
Necessary to loop on pending request.
