# OpenXPKI::Server::Workflow::Activity::SmartCard::CreateCSRData:
# Written by Scott Hardin for the OpenXPKI project 2010
# Copyright (c) 2010 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SmartCard::CreateCSRData;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

use Data::Dumper;

sub execute {
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();

    OpenXPKI::Exception->throw( message =>
            'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_ACTIVITY_STUB',
    );

    return;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartCard::CreateCSRData

=head1 Description

This is a stub and needs to be implemented!
