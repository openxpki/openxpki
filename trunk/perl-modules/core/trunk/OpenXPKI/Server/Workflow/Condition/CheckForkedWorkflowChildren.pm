# OpenXPKI::Server::Workflow::Condition::CheckForkedWorkflowChildren
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision$
package OpenXPKI::Server::Workflow::Condition::CheckForkedWorkflowChildren;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

use English;
use IPC::ShareLite;
use Data::Dumper;

sub evaluate {
    ##! 16: 'start'
    my ( $self, $workflow ) = @_;

    my $serializer = OpenXPKI::Serialization::Simple->new();

    ##! 16: 'accessing shared mem with key: ' . $OpenXPKI::Server::Context::who_forked_me
    if (! defined $OpenXPKI::Server::Context::who_forked_me) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CHECKFORKEDWORKFLOWCHILDREN_PARENT_UNKNOWN',
        );
    }

    my $share = new IPC::ShareLite( -key     => $OpenXPKI::Server::Context::who_forked_me,
                                    -create  => 'no',
                                    -destroy => 'no' );
    if (! defined $share) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CHECKFORKEDWORKFLOWCHILDREN_IPC_SHARE_DOES_NOT_EXIST',
        );
    }
    # first, delete oneself from the shared memory
    $share->lock();
    my $shared_content = $share->fetch();
    ##! 16: 'shared content: ' . $shared_content
    my $pids = {};
    if ($shared_content) {
        $pids = $serializer->deserialize($shared_content);
    }
    ##! 16: 'pids: ' . Dumper $pids
    delete $pids->{$PID};
    ##! 16: 'new pids: ' . Dumper $pids
    $share->store(OpenXPKI::Serialization::Simple->new()->serialize($pids));
    $share->unlock();

    if (scalar keys %{ $pids } != 0) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CHECKFORKEDWORKFLOWCHILDREN_INCORRECT_NUMBER_OF_FORKED_CHILDREN',
            params  => {
                NR_OF_CHILDREN => scalar keys %{ $pids },
            },
        );
    }
    else {
        # we are done, destroy shared memory
        $share = new IPC::ShareLite( -key     => getppid(),
                                     -create  => 'no',
                                     -destroy => 'yes',
        );
        undef $share;
    }

    ##! 16: 'end'
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::CheckForkedWorkflowChildren

=head1 SYNOPSIS

<action name="do_something">
  <condition name="workflow_child_instances_finished"
             class="OpenXPKI::Server::Workflow::Condition::CheckForkedWorkflowChildren">
  </condition>
</action>

=head1 DESCRIPTION

The condition checks if the workflow children instances (instantiated using
the CreateWorkflowInstance or ForkWorkflowInstance activity classes) are
in state 'SUCCESS' already.
It does this by accessing the shared memory indexed by the parent PID
(as this condition is called by a forked workflow child itself),
deleting itself from the serialized hashref (if the condition is called,
the child is as good as finished). If no children remain, this condition
returns true.
