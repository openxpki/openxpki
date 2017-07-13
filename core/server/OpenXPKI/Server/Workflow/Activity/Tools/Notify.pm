# OpenXPKI::Server::Workflow::Activity::Tools::Notify
# Written by Oliver Welter for the OpenXPKI project 2013
# Copyright (c) 2013 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::Notify;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Server::Notification::Handler;
use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self     = shift;
    my $workflow = shift;

    my $context  = $workflow->context();
    my $params = $self->param();

    my $ser  = OpenXPKI::Serialization::Simple->new();

    my $message  = $params->{'message'};
    delete $params->{'message'};
    ##! 16: 'message: ' . $message

    if (! defined $message) {
        OpenXPKI::Exception->throw(
            'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_NOTIFY_MESSAGE_UNDEFINED',
        );
    }

    my $target_key;
    if (!defined $params->{'target_key'}) {
        $target_key = 'wfl_notify';
    } elsif ($params->{'target_key'}) {
        $target_key = $params->{'target_key'};
    }

    ##! 16: 'Extended vars: ' . Dumper $params

    # Look if there are stored notification handles
    my $handles;

    if ($target_key) {
        my $notify = $context->param($target_key);
        $handles = $ser->deserialize( $notify  ) if ($notify);
        ##! 32: 'Found persisted data: ' . Dumper $handles
    }

    CTX('log')->application()->info('Trigger notification message ' .$message);


    # Re-Assign the handles from the return value
    $handles = CTX('notification')->notify({
        MESSAGE => $message,
        WORKFLOW => $workflow,
        TOKEN => $handles,
        DATA => $params
    });

    if ($target_key && defined $handles) {
        ##! 32: 'Write back persisted data: ' . Dumper $handles
        $context->param( 'wfl_notify' => $ser->serialize( $handles ) );
    }

}

1;


__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::Notify

=head1 Description

Trigger notifications using the configured notification backends.

The workflow context is used to persist information from the handlers
over mulitple workflow steps. This is required e.g. with  the RT/ServiceNow
backend to hold the session/ticket reference or to hold the receipient
information for emails. You must turn off this behaviour if you do e.g.
bulk notifications to multiple receipients from one worklflow!

=head2 Activity Parameters

=over

=item message

The name of the message template to use.

=item target_key

The context key to use for the persister, default is wfl_notify.

Set this to an empty string to turn of persistance - this is required
if you want to communicate with different  tickets/receipients during
the workflow, as it is the case e.g. when doing bulk notifications.

=back

=head2 Pass information to the notifier

To make arbitrary values available in the templates, you can specify
additional  parameters to be mapped into the notififer:

    send_notification:
        class: OpenXPKI::Server::Workflow::Activity::Tools::Notify
        param:
            _map_notify_to: $value_from_context
            fixed_value: This can be used in the template as I<data.fixed_value>
            message: cert_expiry

