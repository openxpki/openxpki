# OpenXPKI::Server::Workflow::Condition::WorkflowCreator
# Written by Alexander Klink for the OpenXPKI project 2007
# Copyright (c) 2007 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::WorkflowCreator;

use strict;
use warnings;
use base qw( Workflow::Condition );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use English;

sub evaluate
{
    ##! 1: 'start'
    my ($self, $workflow) = @_;
    my $context           = $workflow->context();

    my $wf_creator        = $context->param('creator');
    my $current_user      = CTX('session')->get_user();
    ##! 16: 'workflow creator: ' . $wf_creator
    ##! 16: 'current user: ' . $current_user

    if ($wf_creator ne $current_user) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_WORKFLOWCREATOR_CREATOR_AND_USER_DIFFER',
            params  => {
                USER    => $current_user,
                CREATOR => $wf_creator,
            },
        );
    }
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::WorkflowCreator

=head1 SYNOPSIS

<action name="do_something">
  <condition name="workflow_creator"
             class="OpenXPKI::Server::Workflow::Condition::WorkflowCreator">
  </condition>
</action>

=head1 DESCRIPTION

The condition checks if the currently logged in user is the creator
of the workflow. This can also be used to explicitly _not_ check for
the workflow creator, for example because you do not want to allow
a user to approve his own CSR/CRR.
