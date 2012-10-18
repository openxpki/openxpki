# OpenXPKI::Server::Workflow::Activity::SmartcardPINUnblock::NotifyViaRT
# Written by Scott Hardin for the OpenXPKI project 2005
#
# Based on OpenXPKI::Server::Workflow::Activity::Skeleton,
# written by Martin Bartosch for the OpenXPKI project 2005
#
# Copyright (c) 2009 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SmartcardPINUnblock::NotifyViaRT;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;

use Data::Dumper;

sub execute {
	##! 1: 'start'
    my $self = shift;
    my $workflow = shift;
	my $context = $workflow->context();

	warn "HEY!!! USING 1234 AS HARD-CODED RT TICKET";
	$context->param('ticket', '1234');

	##! 1: 'stubbing execute()'
	return $self;


}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Skeleton

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

After completion the following context parameters will be set:

=over 12

=item ...

Description...

=back

=head1 Functions

=head2 execute

Executes the action.
