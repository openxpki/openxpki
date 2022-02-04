package OpenXPKI::Server::Workflow::Activity::Tools::SetCreator;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;


sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    my $creator = $self->param('creator') || CTX('session')->data->user;

    $workflow->attrib({ 'creator' => $creator });
    $context->param({ 'creator' => $creator });

    CTX('log')->workflow()->info("Set creator to $creator");

    return;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::SetCreator

=head1 Description

Assign the workflow to another user by setting the creator attribute
and context value to a new value. The creator to set can be given using
the I<creator> attribute of the class, if no set the username is taken
from the current session.

=head2 Parameter

=over

=item creator

The username to set, default is the current session user

=back


