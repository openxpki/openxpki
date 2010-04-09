# OpenXPKI::Server::Workflow::Activity::SmartcardPINUnblock::StoreAuthIDs
# Written by Scott Hardin for the OpenXPKI project 2005
#
# Based on OpenXPKI::Server::Workflow::Activity::Skeleton,
# written by Martin Bartosch for the OpenXPKI project 2005
#
# Copyright (c) 2009 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SmartcardPINUnblock::StoreAuthIDs;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;

use Data::Dumper;

sub execute {
	##! 1: 'SCOTTY - entered StoreAuthIDs::execute'
    my $self = shift;
    my $workflow = shift;
	my $context = $workflow->context();
	##! 1: 'SCOTTY - params' . join(', ', @_)

    # TODO: Validate data in LDAP


	return $self;

}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartcardPINUnblock::StoreAuthIDs

=head1 Description

Implements the store_auth_ids workflow action.

=head2 Context parameters

Expects the following context parameters:

=over 12

=item auth1_id, auth2_id

ID of first and second authorizing persons

=back

After completion the following context parameters will be set:

=over 12

=item ...

Description...

=back

=head1 Functions

=head2 execute

Executes the action.
