# OpenXPKI Workflow Observer for adding history for every execute action
# Written by Michael Bell & Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Observer::AddExecuteHistory;

use Workflow::History;
use OpenXPKI::Server::Context qw( CTX );
use Workflow::Factory qw( FACTORY );

sub update {
    my ( $class, $workflow, $event, $old_state, $action_name, $autorun ) = @_;

    return if ($event ne "execute");

    my $desc_start = "NEW_STATE: ";
    if ($autorun) {
        $desc_start = "NEW_STATE_AUTORUN: ";
    };
    $workflow->add_history(
        Workflow::History->new({
            action      => $action_name,
            description => $desc_start . $workflow->state(),
            state       => $old_state,
            user        => CTX('session')->data->user,
        })
    );
    ## save this history entry
    $workflow->factory()->save_workflow( $workflow );

    # we need to commit to not loose this
    $workflow->_factory()->_commit_transaction( $workflow );

}

1;
