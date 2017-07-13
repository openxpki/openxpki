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

use OpenXPKI::Server::Workflow::NICE::Factory;

use Data::Dumper;

sub execute {
    my $self     = shift;
    my $workflow = shift;

    ##! 32: 'context: ' . Dumper( $workflow->context() )

    my $nice_backend = OpenXPKI::Server::Workflow::NICE::Factory->getHandler( $self );

    # We do not need an attribute map here
    $nice_backend->checkForRevocation();

}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::NICE::CheckForRevocation;

=head1 Description

Activity to check if a former revocation request was processed by the NICE backend.

See OpenXPKI::Server::Workflow::NICE::checkForRevocation for details