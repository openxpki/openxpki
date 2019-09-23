# OpenXPKI::Server::Workflow::Activity::NICE::CheckForRevocation
# Written by Oliver Welter for the OpenXPKI Project 2011
# Copyright (c) 2011 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::NICE::CheckForRevocation;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

use OpenXPKI::Server::NICE::Factory;

use Data::Dumper;

sub execute {
    my $self     = shift;
    my $workflow = shift;

    ##! 32: 'context: ' . Dumper( $workflow->context() )

    my $nice_backend = OpenXPKI::Server::NICE::Factory->getHandler( $self );

    # We do not need an attribute map here
    my $is_revoked = $nice_backend->checkForRevocation( $workflow->context()->param('cert_identifier') );

    if (!defined $is_revoked) {
        ##! 8: 'Backend error - do pause'
        $self->pause('I18N_OPENXPKI_UI_NICE_BACKEND_ERROR');
    } elsif (!$is_revoked) {
        # If the certificate is not revoked, trigger pause
        ##! 32: 'Revocation is pending - going to pause'
        $self->pause('I18N_OPENXPKI_UI_PAUSED_LOCAL_REVOCATION_PENDING');
    }

}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::NICE::CheckForRevocation;

=head1 Description

Activity to check if a former revocation request was processed by the NICE backend.
Pauses the workflow if certificate is not revoked.

See OpenXPKI::Server::NICE::checkForRevocation for details
