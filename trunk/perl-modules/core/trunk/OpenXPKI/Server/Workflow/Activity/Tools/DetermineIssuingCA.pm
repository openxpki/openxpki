# OpenXPKI::Server::Workflow::Activity::Tools::DetermineIssuingCA
# Written by Martin Bartosch for the OpenXPKI project 2005
# Copyright (c) 2005 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::DetermineIssuingCA;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use DateTime;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::DateTime;
use OpenXPKI::Debug;

use Data::Dumper;

sub execute {
    my $self = shift;
    my $workflow = shift;

    # you may wish to use these shortcuts
    my $context      = $workflow->context();

    my $profilename = $context->param('cert_profile'); # was 'profile'
    ##! 16: 'profilename: ' . $profilename

    my $intca = CTX('api')->determine_issuing_ca(
	{
	    PROFILE => $profilename,
	    CONFIG_ID => $self->config_id(),
	});
    ##! 64: 'issuing ca: ' . $issuing_ca

    $context->param(ca => $intca);
}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::DetermineIssuingCA

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
