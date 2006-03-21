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
				  _profile => {
				      accept_from => [ 'context' ],
				      required => 1,
				  },
				  ca => {
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

    my $token = CTX('pki_realm')->{$self->{PKI_REALM}}->{ca}->{id}->{$self->param('ca')}->{crypto};
    if (! defined $token) {
	OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_WORKFLOW_ACTIVITY_CERTIFICATE_ISSUE_TOKEN_UNAVAILABLE",
            );
    }

    my $profile = $self->param('_profile');
    ### $token


    # determine serial number (atomically)
    # FIXME: do this correctly
    $profile->set_serial(2);

    $profile->set_subject($self->param('subject'));

    my $cert = $token->command({COMMAND => "issue_cert",
			        PROFILE => $profile,
			        CSR     => $self->param('pkcs10request'),
                               });

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

Implements the Certificate Issuance workflow activity.

=head2 Context parameters

Expects the following context parameters:

=over 12

=item _profile

Certificate profile object to use for issuance.

=item ca

Issuing CA name to delegate certificate issuance to.

=item pkcs10request

Certificate request (PKCS#10, PEM encoded) to process.

=item subject

Subject DN to use for certificate issuance.

=back

After completion the following context parameters will be set:

=over 12

=item certificate
    
PEM encoded certificate

=back

=head1 Functions

=head2 execute

Executes the action.
