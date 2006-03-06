# OpenXPKI Workflow Activity
# Written by Martin Bartosch for the OpenXPKI project 2005
# Copyright (c) 2005 by The OpenXPKI Project
# $Revision$

package OpenXPKI::Server::Workflow::Activity::Passphrase::Generate;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );
use Log::Log4perl       qw( get_logger );

# use Smart::Comments;

use OpenXPKI::Exception;
use OpenXPKI::Crypto::TokenManager;  


sub execute {
    my $self = shift;
    my $workflow = shift;

    $self->SUPER::execute($workflow,
			  {
			      ACTIVITYCLASS => 'PUBLIC',
			      PARAMS => {
				  _token => {
				      accept_from => [ 'context' ],
				      required => 1,
				  },
				  passphrase => {
				  },
			      },
			  });
    
    my $context = $workflow->context();
    my $log = get_logger(); 

    # NOP if already in context
    if (defined $self->param('passphrase')) {
	# FIXME: should we log this?
	return 1;
    }
    
    my $token = $self->param('_token');
    
    # generate a random pass phrase
    $self->param('passphrase',
		 $token->command({COMMAND => "create_random", RANDOM_LENGTH => 16}));
    
    # export
    $context->param(passphrase => $self->param('passphrase'));

    $workflow->add_history(
        Workflow::History->new({
            action      => 'Generate pass phrase pair',
            description => sprintf( "Generated random pass phrase" ),
	    user        => $self->param('creator'),
			       })
	);
}


1;

=head1 Description

Implements the 'pass phrase generation' workflow activity.


=head2 Context parameters

Expects the following context parameters:

=over 12

=item _token

Cryptographic token to use for pass phrase generation. The default token is
sufficient for this purpose. Required. Volatile.

=item passphrase

If undefined in the context the activity will generate a new 16 character
random passphrase and set the context accordingly.
If the parameter is already present the activity does nothing and leaves
the parameter untouched.

=back

After completion the following context parameters will be set:

=over 12

=item passphrase

Original value (if it was set in the context on entry in this activity)
or set to a random pass phrase if it was not set in context before.

=back

=head1 Functions

=head2 execute

Executes the activity.

