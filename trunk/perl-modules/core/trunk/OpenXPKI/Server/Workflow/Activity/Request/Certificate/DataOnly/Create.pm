# OpenXPKI Workflow Activity
# Written by Martin Bartosch for the OpenXPKI project 2005
# Copyright (c) 2005 by The OpenXPKI Project
# $Revision: 80 $

package OpenXPKI::Server::Workflow::Activity::Request::Certificate::DataOnly::Create;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context;
use Log::Log4perl       qw( get_logger );

# use Smart::Comments;

sub execute {
    my $self = shift;
    my $workflow = shift;

    $self->setparams($workflow, 
		     {
			 creator => {
			     required => 1,
			 },
		     });

    my $context = $workflow->context;
    my $log = get_logger(); 
    

    $workflow->add_history(
        Workflow::History->new({
            action      => 'Create dataonly request',
            description => sprintf( "Created dataonly request"
		),
            user        => $self->param('creator'),
			       })
	);
 
}


1;

=head1 Description

Implements the 'data only request creation' workflow action.

=head2 Context parameters

Expects the following context parameters:

=over 12

=item creator

User id of creator

=back

FIXME: This activity is the entry point as seen from the web interface. 
We should list and require all parameters that have to be queried from
the user.

=head1 Functions

=head2 execute

Executes the action.
