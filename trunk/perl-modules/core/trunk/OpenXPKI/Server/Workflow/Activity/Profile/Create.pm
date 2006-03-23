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
				  ca => {
				      accept_from => [ 'context' ], 
				      required => 1,
				  },
				  profile => {
				      accept_from => [ 'context' ], 
				      required => 1,
				  },
			      },
			  });    


    my $context = $workflow->context();


    my $profile = OpenXPKI::Crypto::Profile::Certificate->new (
	DEBUG     => 0,
	CONFIG    => CTX('xml_config'),
	PKI_REALM => $self->{PKI_REALM},
	TYPE      => 'ENDENTITY',
	CA        => $self->param('ca'),
	ID        => $self->param('profile')
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

Implements the Certificate Profile Generation workflow action.

=head2 Context parameters

Expects the following context parameters:

=over 12

=item ca

Issuing CA to use for creating the certificate.

=item profile

Certificate profilename to use for certifiate issuance.

=back

After completion the following context parameters will be set:

=over 12

=item _profile

Certificate profile object to be used for issuance.

=back

=head1 Functions

=head2 execute

Executes the action.
