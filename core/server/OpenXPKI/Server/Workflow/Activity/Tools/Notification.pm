# OpenXPKI::Server::Workflow::Activity::Tools::Notification
# Written by Alexander Klink for the OpenXPKI project 2007
# Copyright (c) 2007 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::Notification;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

sub execute {
    ##! 1: 'start'
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();
    my $ser      = OpenXPKI::Serialization::Simple->new();

    my $message    = $self->param('message');
    ##! 16: 'message: ' . $message

    if (! defined $message) {
        OpenXPKI::Exception->throw(
            'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_NOTIFICATION_MESSAGE_UNDEFINED',
        );
    }

    my $bulk = $context->param('bulk');
    # send notifaction
    if (! $bulk && $workflow->type() ne 'I18N_OPENXPKI_WF_TYPE_SCEP_REQUEST') {
        ##! 16: 'bulk not set and WF type is not SCEP request, notifying'
        # only notify if this is not part of a bulk request - otherwise
        # the user would get a huge number of tickets
        my $ticket = CTX('notification')->notify({
            MESSAGE  => $message,
            WORKFLOW => $workflow,
        });
        if (defined $ticket) {
            my $do_update;
          CHECK_TICKET_IDS_DEFINED:
            foreach my $key (keys %{ $ticket }) {
                if (defined $ticket->{$key}) {
                    $do_update = 1;
                    last CHECK_TICKET_IDS_DEFINED;
                }
            }
            # if notify returns anything in the hashref,
            # it is the ticket ID of a newly created ticket,
            # thus save it to the context
            if ($do_update) {
                $context->param('ticket' => $ser->serialize($ticket));
            }
        }
    }

    ##! 1: 'end'
    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::Notification

=head1 Description

This activity sends the message configured in the workflow
configuration (parameter 'message') to the user via the
notification system. If ticket IDs are returned, they are saved
in the serialized hash reference context parameter 'ticket'.
