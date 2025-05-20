package OpenXPKI::Client::Service::WebUI::Page::Workflow::Handle;
use OpenXPKI -class;

extends 'OpenXPKI::Client::Service::WebUI::Page::Workflow';

=head1 UI Methods

=head2 action_handle

Execute a workflow internal action (fail, resume, wakeup, archive). Requires
the workflow and action to be set in the wf_token info.

=cut

sub action_handle ($self) {
    my $wf_info;
    my $wf_args = $self->resolve_wf_token or return;

    if (not $wf_args->{wf_id}) {
        $self->status->error('I18N_OPENXPKI_UI_WORKFLOW_INVALID_REQUEST_HANDLE_WITHOUT_ID');
        return;
    }

    my $handle = $wf_args->{wf_handle};

    if (not $wf_args->{wf_handle}) {
        $self->status->error('I18N_OPENXPKI_UI_WORKFLOW_INVALID_REQUEST_HANDLE_WITHOUT_ACTION');
        return;
    }

    Log::Log4perl::MDC->put('wfid', $wf_args->{wf_id});

    if ('fail' eq $handle) {
        $self->log->info(sprintf "Workflow #%s set to failure by operator", $wf_args->{wf_id} );
        $wf_info = $self->send_command_v2( 'fail_workflow', {
            id => $wf_args->{wf_id},
        });
    }
    elsif ('wakeup' eq $handle) {
        $self->log->info(sprintf "Workflow #%s trigger wakeup", $wf_args->{wf_id} );
        $wf_info = $self->send_command_v2( 'wakeup_workflow', {
            id => $wf_args->{wf_id}, async => 1, wait => 1
        });
    }
    elsif ('resume' eq $handle) {
        $self->log->info(sprintf "Workflow #%s trigger resume", $wf_args->{wf_id} );
        $wf_info = $self->send_command_v2( 'resume_workflow', {
            id => $wf_args->{wf_id}, async => 1, wait => 1
        });
    }
    elsif ('reset' eq $handle) {
        $self->log->info(sprintf "Workflow #%s trigger reset", $wf_args->{wf_id} );
        $wf_info = $self->send_command_v2( 'reset_workflow', {
            id => $wf_args->{wf_id}
        });
    }
    elsif ('archive' eq $handle) {
        $self->log->info(sprintf "Workflow #%s trigger archive", $wf_args->{wf_id} );
        $wf_info = $self->send_command_v2( 'archive_workflow', {
            id => $wf_args->{wf_id}
        });
    }

    $self->render_from_workflow({ wf_info => $wf_info });

    return;
}

__PACKAGE__->meta->make_immutable;
