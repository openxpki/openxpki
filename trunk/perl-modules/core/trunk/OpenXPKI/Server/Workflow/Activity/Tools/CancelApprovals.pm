# OpenXPKI::Server::Workflow::Activity::Tools::CancelApprovals.pm
# Written by Michael Bell for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision: 320 $

package OpenXPKI::Server::Workflow::Activity::Tools::CancelApprovals;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Serialization::Simple;

sub execute
{
    my $self     = shift;
    my $workflow = shift;
    my $context = $workflow->context();
    my $serializer = OpenXPKI::Serialization::Simple->new();

    ## delete approvals (set to a serialized empty hashref)
    $context->param('approvals' => $serializer->serialize({})) ;
}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::CancelApprovals

=head1 Description

This class implements the deletion of all approvals which were stored
with OpenXPKI::Server::Workflow::Activity::Tools::Approve in the related
workflow. This is done by storing an empty hash reference in the
variable approvals.

The activity uses no parameters. All parameters will be taken from the
session and the context of the workflow directly. Please note that you
should never allow the configuration of the context parameter
approvals if you use these modules.
