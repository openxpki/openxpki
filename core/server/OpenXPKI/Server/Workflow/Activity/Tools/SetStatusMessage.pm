package OpenXPKI::Server::Workflow::Activity::Tools::SetStatusMessage;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;

sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    my $status_message = $self->param('message') || undef;

    $context->param({'status_message' => $status_message});

    if ($status_message) {
        CTX('log')->application()->debug("Set user message $status_message");
    } else {
        CTX('log')->application()->debug("Delete user message");
    }

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::SetStatusMessage

=head1 Description

This activity sets the status_message context parameter, which is
taken from the activity definition. This is a compagnion to
SetErrorCode to add non-crititcal status information to the context
to be displayed in reports or overview lists.
