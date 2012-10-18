# OpenXPKI::Server::Workflow::Activity::SmartcardPINUnblock::Initialize
# Written by Scott Hardin for the OpenXPKI project 2005
#
# Based on OpenXPKI::Server::Workflow::Activity::Skeleton,
# written by Martin Bartosch for the OpenXPKI project 2005
#
# Copyright (c) 2009 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SmartcardPINUnblock::Initialize;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;

use Data::Dumper;
#require '/etc/openxpki/local/bogus-data.cfg';

sub execute {
	##! 1: 'Entered Initialize::execute()'
	my $self = shift;
	my $workflow = shift;
	my $context = $workflow->context();
	my $token_id = $context->param('token_id');
#	my $token_owner = $dbg::cfg->{token_owners}->{$token_id};

	# Initialize other relevant params (effectively, we can now reset
	# the workflow instance with this)
	# Note: do this _before_ we start setting individual params
	# to make sure we don't accidentally clobber something.
	foreach my $k ( qw( auth1_id auth2_id auth1_hash auth2_hash
		auth1_salt auth2_salt
		_auth1_code _auth2_code _new_pin1 _new_pin2 ) ) {
		$context->param($k, '');
	}

#	dbg::init();
#	if ( $token_owner ) {
	##! 1: 'WARN - using LDAP info from /tmp/bogus-data.cfg'
#		$context->param('token_owner', $token_owner);
#		$context->param('creator', $token_owner);
#	}

	##! 1: 'Leaving Initialize::execute()'
	return $self;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartcardPINUnblock::Initialize

=head1 Description

Implements the <I>initialize</I> workflow action.

Using the given Token ID, the user that is assigned to this card is
fetched from LDAP.

=head2 Context parameters

Expects the following context parameters:

=over 12

=item token_id

The Token ID read from the Smartcard.

=back

After completion the following context parameters will be set:

=over 12

=item token_owner

The owner of the given Token ID, as listed in LDAP.

=back

=head1 Functions

=head2 execute

Executes the action.
