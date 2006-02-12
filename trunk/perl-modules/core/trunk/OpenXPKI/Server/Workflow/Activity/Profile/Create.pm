# OpenXPKI Workflow Activity
# Written by Martin Bartosch for the OpenXPKI project 2005
# Copyright (c) 2005 by The OpenXPKI Project
# $Revision: 80 $

package OpenXPKI::Server::Workflow::Activity::Profile::Create;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Crypto::Profile::Certificate;
use OpenXPKI::Exception;

# use Smart::Comments;

sub execute {
    my $self = shift;
    my $workflow = shift;

    $self->SUPER::execute($workflow,
			  {
			      ACTIVITYCLASS => 'CA',
			      PARAMS => {
				  pkirealm => {
				      accept_from => [ 'context' ],
				      required => 1,
				  },
				  ca => {
				      accept_from => [ 'context' ], 
				      required => 1,
				  },
				  role => {
				      accept_from => [ 'context' ], 
				      required => 1,
				  },
			      },
			  });    


    my $context = $workflow->context();

    my $profile = OpenXPKI::Crypto::Profile::Certificate->new (
	DEBUG     => 0,
	CONFIG    => CTX('xml_config'),
	PKI_REALM => $self->param('pkirealm'),
	CA        => $self->param('ca'),
	ROLE      => $self->param('role')
	);

    $context->param(_profile => $profile);
    
    $workflow->add_history(
        Workflow::History->new({
            action      => 'Add certificate profile',
            description => sprintf( "Added certificate profile"
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
