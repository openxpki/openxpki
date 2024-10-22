package OpenXPKI::Client::Service::WebUI::Page::Workflow::Select;
use OpenXPKI -class;

extends 'OpenXPKI::Client::Service::WebUI::Page::Workflow';

=head1 UI Methods

=head2 action_select

Handle requests to states that have more than one action.
Needs to reference an exisiting workflow either via C<wf_token> or C<wf_id> and
the action to choose with C<wf_action>. If the selected action does not require
any input parameters (has no fields) and does not have an ui override set, the
action is executed immediately and the resulting state is used. Otherwise,
the selected action is preset and the current state is passed to the
__render_from_workflow method.

=cut

sub action_select ($self) {
    my $wf_action =  $self->param('wf_action');
    $self->log->debug("Select workflow activity '$wf_action'");

    # can be either token or id
    my $wf_id = $self->param('wf_id');
    if (not $wf_id) {
        my $wf_args = $self->__resolve_wf_token or return;
        $wf_id = $wf_args->{wf_id};
        if (!$wf_id) {
            $self->log->error('No workflow id given');
            $self->status->error('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION');
            return;
        }
    }

    Log::Log4perl::MDC->put('wfid', $wf_id);
    my $wf_info = $self->send_command_v2( 'get_workflow_info', {
        id => $wf_id,
        with_ui_info => 1,
    });
    $self->log->trace('wf_info ' . Dumper $wf_info) if $self->log->is_trace;

    if (not $wf_info) {
        $self->status->error('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION');
        return;
    }

    my $args;

    # If the activity has no fields and no ui class we proceed immediately
    # FIXME Really a good idea - intentionally stop items without fields?
    my $wf_action_info = $wf_info->{activity}->{$wf_action};
    $self->log->trace('wf_action_info ' . Dumper  $wf_action_info) if $self->log->is_trace;

    if (
        (not $wf_action_info->{field} or scalar $wf_action_info->{field}->@* == 0)
        and not $wf_action_info->{uihandle}
    ) {
        $self->log->debug('Activity has no input - execute');

        # send input data to workflow
        $wf_info = $self->send_command_v2( 'execute_workflow_activity', {
            id => $wf_info->{workflow}->{id},
            activity => $wf_action,
            ui_info => 1
        });

        $args->{wf_action} = $self->__get_next_auto_action($wf_info);
    } else {
        $args->{wf_action} = $wf_action;
    }

    $args->{wf_info} = $wf_info;

    $self->__render_from_workflow( $args );
}

__PACKAGE__->meta->make_immutable;
