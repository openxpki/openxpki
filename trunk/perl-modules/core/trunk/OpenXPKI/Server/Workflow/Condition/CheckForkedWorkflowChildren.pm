# OpenXPKI::Server::Workflow::Condition::CheckForkedWorkflowChildren
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
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

    my $workflow_id = $workflow->id();
    ##! 64: 'workflow ID: ' . $workflow_id

    my $serializer = OpenXPKI::Serialization::Simple->new();

    ##! 16: 'accessing shared mem with key: ' . $OpenXPKI::Server::Context::who_forked_me
    if (! defined $OpenXPKI::Server::Context::who_forked_me{$workflow->id()}){
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CHECKFORKEDWORKFLOWCHILDREN_PARENT_UNKNOWN',
        );
    }

    my $my_forker = $OpenXPKI::Server::Context::who_forked_me{$workflow->id()}->[0];
    my $my_forked = $OpenXPKI::Server::Context::who_forked_me{$workflow->id()}->[1];

    my $share=0;
    eval {
        $share = new IPC::ShareLite( -key     => $my_forker,
                                     -create  => 'no',
                                     -destroy => 'no' 
                     );
    };
    if ($EVAL_ERROR){
        undef $share;
    };

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
    ##! 16: 'my PID: ' . $PID
    # FIXME - maybe delete $pids->{$workflow_id}->{$PID} is enough?
    if ( !defined  $pids->{$workflow_id}->{$my_forked} ){
        $share->unlock();
        undef $share;
        condition_error(
            "I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CHECKFORKEDWORKFLOWCHILDREN_FALSE_CALL"
        );
    };

    foreach my $key (keys %{ $pids }) {
        delete $pids->{$key}->{$my_forked};
    }

    ##! 16: 'new pids: ' . Dumper $pids
    $share->store(OpenXPKI::Serialization::Simple->new()->serialize($pids));
    $share->unlock();

    if (scalar keys %{ $pids->{$workflow_id} } != 0) {
        # the workflow still has more than this child
        ##! 16: 'still more than one child left, throwing exception'
        ##! 32: 'pids->{workflow_id}: ' . Dumper $pids->{$workflow_id}
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CHECKFORKEDWORKFLOWCHILDREN_INCORRECT_NUMBER_OF_FORKED_CHILDREN',
            params  => {
                NR_OF_CHILDREN => scalar keys %{ $pids },
            },
        );
    }
    else {
        # clean up
        ##! 16: 'this was the last child for this workflow, entry deleted, condition returns true'
        delete $pids->{$workflow_id};
        ##! 32: 'pids after delete: ' . Dumper $pids
    }
    if (scalar keys %{ $pids } == 0) {
        ##! 16: 'everything is done, destroying shared memory'
        # we are done, destroy shared memory
        $share=0;
        eval {
            $share = new IPC::ShareLite(
                             -key     => $my_forker,
                             -create  => 'no',
                             -destroy => 'yes'
                         );
        };
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
