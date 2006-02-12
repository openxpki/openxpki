# OpenXPKI Workflow Activity
# Written by Martin Bartosch for the OpenXPKI project 2005
# Copyright (c) 2005 by The OpenXPKI Project
# $Revision$

package OpenXPKI::Server::Workflow::Activity::Token::Get;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );
use Log::Log4perl       qw( get_logger );

# use Smart::Comments;

use OpenXPKI::Crypto::TokenManager;  
use OpenXPKI::Server::Context qw( CTX );

sub execute {
    my ($self,
	$workflow) = @_;

    $self->SUPER::execute($workflow,
			  {
			      ACTIVITYCLASS => 'PUBLIC',
			      PARAMS => {
				  tokentype => {
				      accept_from => [ 'config', 'default' ],
				      default => 'DEFAULT',
				  },
				  ca => {
				      accept_from => [ 'context' ],
				  },
				  pkirealm => {
				      accept_from => [ 'context' ],
				      required => 1,
				  },
			      },
			  });
    
    my $context = $workflow->context();
    
    my $config = CTX('xml_config');

    my $log = get_logger(); 
    

    my $mgmt = OpenXPKI::Crypto::TokenManager->new(DEBUG => 0, 
						   CONFIG => $config,
	);

    ### tokentype: $self->param('tokentype')

    my $token = $mgmt->get_token(TYPE => $self->param('tokentype'), 
				 # FIXME: can we imply here that
				 # tokenname == internal CA name? Does this
				 # work for multiple tokens for one
				 # CA?
				 NAME => $self->param('ca'), 
				 PKI_REALM => $self->param('pkirealm'),
	);
    
    $context->param(_token => $token);

    $workflow->add_history(
        Workflow::History->new({
            action      => 'Get Token',
            description => sprintf( "Instantiated %s crypto token '%s' for PKI realm '%s'",
                                    $self->param('tokentype'), 
				    (defined $self->param('tokenname')) ? $self->param('tokenname') : "<n/a>",
				    $self->param('pkirealm'),
		),
            user        => $self->param('creator'),
			       })
	);
}


1;

=head1 Description

Implements the 'get token' workflow activity.

=head2 Context parameters

Expects the following context parameters:

=over 12

=item configcache

Configuration object reference. Required.

=item tokentype

Token type to use. Default: 'DEFAULT'

=item tokenname

Token name to use.

=item pkirealm

PKI realm to use. Required.

=back

After completion the following context parameters will be set:

=over 12

=item _token

Cryptographic token. Volatile.
    
=back

=head1 Functions

=head2 execute

Executes the activity.
