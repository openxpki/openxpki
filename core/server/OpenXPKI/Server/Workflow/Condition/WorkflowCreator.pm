# OpenXPKI::Server::Workflow::Condition::WorkflowCreator
# Written by Alexander Klink for the OpenXPKI project 2007
# Copyright (c) 2007 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::WorkflowCreator;

use strict;
use warnings;
use base qw( Workflow::Condition );
use OpenXPKI::Server::Context qw( CTX );
use Workflow::Exception qw( condition_error );
use OpenXPKI::Debug;
use English;

sub evaluate
{
    ##! 1: 'start'
    my ($self, $workflow) = @_;

    my $wf_creator = $workflow->attrib('creator') || '';

    my $current_user      = CTX('session')->data->user;
    ##! 16: 'workflow creator: ' . $wf_creator
    ##! 16: 'current user: ' . $current_user

     CTX('log')->application()->debug("Check workflow creator: $wf_creator ?= $current_user");


    if ($wf_creator ne $current_user) {
        condition_error ('I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_WORKFLOWCREATOR_CREATOR_AND_USER_DIFFER');
    }
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::WorkflowCreator

=head1 SYNOPSIS

   is_workflow_creator"
        class: OpenXPKI::Server::Workflow::Condition::WorkflowCreator


=head1 DESCRIPTION

The condition checks if the currently logged in user is the creator
of the workflow. This can also be used to explicitly _not_ check for
the workflow creator, for example because you do not want to allow
a user to approve his own CSR/CRR.
