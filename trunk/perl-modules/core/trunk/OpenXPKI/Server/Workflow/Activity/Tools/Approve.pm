# OpenXPKI::Server::Workflow::Activity::Tools::Approve.pm
# Written by Michael Bell for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision: 320 $

package OpenXPKI::Server::Workflow::Activity::Tools::Approve;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Serialization::Simple;

sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $serializer = OpenXPKI::Serialization::Simple->new();

    ## get needed information
    my $context = $workflow->context();
    my $user    = CTX('session')->get_user();
    my $role    = CTX('session')->get_role();

    ## get already present approvals
    my $approvals = $context->param ('approvals');
    $approvals = $serializer->deserialize($approvals)
        if ($approvals);

    ## set new approval
    $approvals->{$user} = $role;
    $approvals = $serializer->serialize($approvals);
    $context->param ('approvals' => $approvals);

    CTX('log')->log(
	MESSAGE => 'Approval for workflow ' . $workflow->id() . " by user $user, role $role",
	PRIORITY => 'info',
	FACILITY => 'audit',
	);

    ## enforce context persistence
    return 1;
}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::Approve

=head1 Description

This class implements simple possibility to store approvals from
different persons together with informations about the actively used
role. This way of storing approvals makes it possible to evaluate the
approvals on a role and a number per role base. Please see the class
OpenXPKI::Server::Workflow::Condition::Approved for more details.

The activity uses no parameters. All parameters will be taken from the
session and the context of the workflow directly. Please note that you
should never allow the configuration of the context parameter
approvals if you use this module and the referenced condition.
