# OpenXPKI Workflow Observer for adding history for every execute action
# Written by Michael Bell for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision: 477 $

package OpenXPKI::Server::Workflow::Observer::AddExecuteHistory;

use Workflow::History;
use OpenXPKI::Server::Context qw( CTX );
use Workflow::Factory qw( FACTORY );

sub update {
    my ( $class, $workflow, $event, $old_state, $action_name ) = @_;

    return if ($event ne "execute");

    $workflow->add_history(
        Workflow::History->new({
            action      => $action_name,
            description => "NEW_STATE: ".$workflow->state(),
            state       => $old_state,
            user        => CTX('session')->get_user(),
        })
    );
    ## save this history entry
    FACTORY->save_workflow ($workflow);
}

1;
