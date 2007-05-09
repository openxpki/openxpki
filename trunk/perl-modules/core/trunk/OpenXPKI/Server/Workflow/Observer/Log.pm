# OpenXPKI::Server::Workflow::Observer::Log
# Written by Alexander Klink and Martin Bartosch for the OpenXPKI project 2007
# Copyright (c) 2007 by The OpenXPKI Project
# $Revision: 320 $

package OpenXPKI::Server::Workflow::Observer::Log;

use strict;

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;

sub update {
    my ($class, $workflow, $action, $old_state, $action_name) = @_;

    CTX('log')->log(
	MESSAGE => "Workflow observer triggered, action: $action, workflow id: " . $workflow->id() . ', workflow type: ' . $workflow->type() . ', workflow state: ' . $workflow->state() . ', old state: ' . $old_state . ', action name: ' . $action_name,
	PRIORITY => 'debug',
	FACILITY => 'system',
	);
    
    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Observer::Log

=head1 Description

This class implements a workflow observer that just logs anything
that happens to our log system.
