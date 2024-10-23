package OpenXPKI::Client::Service::WebUI::Page::Workflow::Load;
use OpenXPKI -class;

extends 'OpenXPKI::Client::Service::WebUI::Page::Workflow';

=head1 UI Methods

=head2 action_load

Load a workflow given by wf_id, redirects to init_load

=cut

sub action_load ($self) {
    $self->redirect->to('workflow!load!wf_id!'.$self->param('wf_id').'!_seed!'.time());
    return $self;
}

=head2 init_load

Requires parameter I<wf_id> which is the id of an existing workflow.
It loads the workflow at the current state and tries to render it
using the render_from_workflow method. In states with multiple actions
I<wf_action> can be set to select one of them. If those arguments are not
set from the CGI environment, they can be passed as method arguments.

=cut

sub init_load ($self, $args) {
    # re-instance existing workflow
    my $id = $self->param('wf_id') || $args->{wf_id} || 0;
    $id =~ s/[^\d]//g;

    my $wf_action = $self->param('wf_action') || $args->{wf_action} || '';
    my $view = $self->param('view') || '';

    my $wf_info = $self->send_command_v2( 'get_workflow_info',  {
        id => $id,
        with_ui_info => 1,
    }, { nostatus  => 1 });

    if (not $wf_info) {
        $self->status->error('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION') unless $self->status->is_set;
        return $self->internal_redirect('workflow!search' => {
            preset => { wf_id => $id },
        });
    }

    # Set single action if no special view is requested and only single action is avail
    if (!$view && !$wf_action && $wf_info->{workflow}->{proc_state} eq 'manual') {
        $wf_action = $self->get_next_auto_action($wf_info);
    }

    $self->render_from_workflow({ wf_info => $wf_info, wf_action => $wf_action, view => $view });

    return $self;
}

__PACKAGE__->meta->make_immutable;
