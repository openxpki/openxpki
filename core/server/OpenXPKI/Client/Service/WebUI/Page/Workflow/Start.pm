package OpenXPKI::Client::Service::WebUI::Page::Workflow::Start;
use OpenXPKI -class;

extends 'OpenXPKI::Client::Service::WebUI::Page::Workflow';

=head1 UI Methods

=head2 init_start

Same as init_index but directly creates the workflow and displays the result
of the initial action. Normal workflows will result in a redirect using the
workflow id, volatile workflows are displayed directly. This works only with
workflows that do not require any initial parameters.

=cut
sub init_start ($self, $args) {
    my $wf_type = $self->param('wf_type');
    if (!$wf_type) {
        # todo - handle errors
        $self->log->error("No workflow given to init_start");
        return $self;
    }

    my $wf_info = $self->send_command_v2( 'create_workflow_instance', {
        workflow => $wf_type,
        params => $self->secure_param('wf_params') // {},
        ui_info => 1,
        $self->__tenant_param(),
    });

    if (!$wf_info) {
        # todo - handle errors
        $self->log->error("Create workflow failed");
        return $self;
    }

    $self->log->trace("wf info on create: " . Dumper $wf_info ) if $self->log->is_trace;

    my $wf_id = $wf_info->{workflow}->{id};
    $self->log->info(sprintf "Create new workflow %s, got id %s",  $wf_info->{workflow}->{type}, $wf_id );

    # this duplicates code from action_index
    if (
        OpenXPKI::Util->is_regular_workflow($wf_id)
        and not (grep { $_ =~ m{\A_} } keys %{$wf_info->{workflow}->{context}})
    ) {
        my $redirect = 'workflow!load!wf_id!'.$wf_id;
        my @activity = keys %{$wf_info->{activity}};
        if (scalar @activity == 1) {
            $redirect .= '!wf_action!'.$activity[0];
        }
        $self->redirect->to($redirect);

    } else {
        # one shot workflow
        $self->__render_from_workflow({ wf_info => $wf_info });
    }

    return $self;

}

__PACKAGE__->meta->make_immutable;
