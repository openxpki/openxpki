# OpenXPKI Workflow Activity
# Written by Martin Bartosch for the OpenXPKI project 2005
# Copyright (c) 2005 by The OpenXPKI Project
# $Revision: 80 $

package OpenXPKI::Server::Workflow::Activity::Certificate::Issue;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;

# use Smart::Comments;

sub execute {
    my $self = shift;
    my $workflow = shift;

    $self->SUPER::execute($workflow,
			  {
			      ACTIVITYCLASS => 'CA',
			      PARAMS => {
				  _token => {
				      accept_from => [ 'context' ],
				      required => 1,
				  },
				  _profile => {
				      accept_from => [ 'context' ],
				      required => 1,
				  },
				  pkcs10request => {
				      accept_from => [ 'context' ],
				      required => 1,
				  },
				  subject => {
				      accept_from => [ 'context' ], 
				      required => 1,
				  }
			      },
			  });    
    

    my $context = $workflow->context();

    my $token   = $self->param('_token');
    my $profile = $self->param('_profile');
    ### $token


    # determine serial number (atomically)
    # FIXME: do this correctly
    $profile->set_serial(2);

    $profile->set_subject($self->param('subject'));

    my $cert = $token->command("issue_cert",
			       PROFILE => $profile,
			       CSR     => $self->param('pkcs10request'),
	);

    $context->param(certificate => $cert),

    $workflow->add_history(
        Workflow::History->new({
            action      => 'Issue certificate',
            description => sprintf( "Issued certificate"
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
