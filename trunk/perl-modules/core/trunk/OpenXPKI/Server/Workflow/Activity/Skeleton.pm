# OpenXPKI Workflow Activity
# Written by Martin Bartosch for the OpenXPKI project 2005
# Copyright (c) 2005 by The OpenXPKI Project
# $Revision: 80 $

package OpenXPKI::Server::Workflow::Activity::Skeleton;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;


sub execute {
    my $self = shift;
    my $workflow = shift;

    $self->SUPER::execute($workflow,
			  {
			      # CHOOSE one of the following:
			      # CA: CA operation (default)
			      # RA: RA operation
			      # PUBLIC: publicly available operation
			      #ACTIVITYCLASS => 'CA',
			      PARAMS => {
# 				  _myvolatile => {
# 				      # default => '',
# 				      # required => 1,
# 				  },
# 				  mypersistent => {
# 				      # default => '',
# 				      # required => 1,
# 				  },
			      },
			  });    


    my $context = $workflow->context();


    $workflow->add_history(
        Workflow::History->new({
            action      => 'My action description',
            description => sprintf( "My log message"
		),
            user        => $self->param('creator'),
			       })
	);
    
}


1;

=head1 Description

Implements the FIXME workflow action.

=head2 Context parameters

Expects the following context parameters:

=over 12

=item ...

Description...

=item ...

Description...

=back

=head1 Functions

=head2 execute

Executes the action.
