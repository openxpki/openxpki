# OpenXPKI::Server::Workflow::Activity::SmartCard::Initialize
# Written by Scott Hardin for the OpenXPKI project 2010
#
# Based on OpenXPKI::Server::Workflow::Activity::Skeleton,
# written by Martin Bartosch for the OpenXPKI project 2005
#
# Copyright (c) 2009 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SmartCard::Initialize;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;

use Data::Dumper;

sub execute {
	##! 1: 'Entered Initialize::execute()'
	my $self = shift;
	my $workflow = shift;
	my $context = $workflow->context();
#	my $token_id = $context->param('token_id');

	# Initialize other relevant params (effectively, we can now reset
	# the workflow instance with this)
	# Note: do this _before_ we start setting individual params
	# to make sure we don't accidentally clobber something.
	foreach my $k ( qw( user_id login_id certs_on_card ) )
{
		$context->param($k, '');
	}

#	if ( $token_owner ) {
#		$context->param('token_owner', $token_owner);
#		$context->param('creator', $token_owner);
#	}

	##! 1: 'Leaving Initialize::execute()'
	return $self;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartCard::Initialize

=head1 Description

Implements the <I>initialize</I> workflow action.

=head2 Context parameters

Expects the following context parameters:

=over 12

=item token_id

The Token ID read from the Smartcard.

=back

=head1 Functions

=head2 execute

Executes the action.
