package OpenXPKI::Client::Service::WebUI::Page::Workflow::Info;
use OpenXPKI -class;

extends 'OpenXPKI::Client::Service::WebUI::Page::Workflow';

=head1 UI Methods

=head2 init_info

Requires parameter I<wf_id> which is the id of an existing workflow.
It loads the process information to be displayed in a modal popup, used
mainly from the workflow search / result lists.

=cut

sub init_info ($self, $args) {
    # re-instance existing workflow
    my $id = $self->param('wf_id') || $args->{wf_id} || 0;
    $id =~ s/[^\d]//g;

    my $wf_info = $self->send_command_v2( 'get_workflow_info', {
        id => $id,
        with_ui_info => 1,
    }, { nostatus  => 1 });

    if (not $wf_info) {
        $self->set_page(label => '');
        $self->main->add_section({
            type => 'text',
            content => {
                description => 'I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION',
            }
        });
        $self->log->warn('Unable to load workflow info for id ' . $id);
        return;
    }

    my $fields = $self->__render_workflow_info( $wf_info, $self->session_param('wfdetails') );

    push @{$fields}, {
        label => "I18N_OPENXPKI_UI_FIELD_ERROR_CODE",
        name => "error_code",
        value => $wf_info->{workflow}->{context}->{error_code},
    } if (
        $wf_info->{workflow}->{context}->{error_code}
        and $wf_info->{workflow}->{proc_state} =~ m{(manual|finished|failed)}
    );

    # The workflow info contains info about all control actions that
    # can be done on the workflow -> render appropriate buttons.
    my @buttons_handle = ({
        href => '#/openxpki/redirect!workflow!load!wf_id!'.$wf_info->{workflow}->{id},
        label => 'I18N_OPENXPKI_UI_WORKFLOW_OPEN_WORKFLOW_LABEL',
        format => 'primary',
    });

    # The workflow info contains info about all control actions that
    # can be done on the workflow -> render appropriate buttons.
    if ($wf_info->{handles} && ref $wf_info->{handles} eq 'ARRAY') {
        my @handles = @{$wf_info->{handles}};
        if (grep /context/, @handles) {
            push @buttons_handle, {
                'page' => 'workflow!context!view!result!wf_id!'.$wf_info->{workflow}->{id},
                'label' => 'I18N_OPENXPKI_UI_WORKFLOW_CONTEXT_LABEL',
            };
        }

        if (grep /attribute/, @handles) {
            push @buttons_handle, {
                'page' => 'workflow!attribute!view!result!wf_id!'.$wf_info->{workflow}->{id},
                'label' => 'I18N_OPENXPKI_UI_WORKFLOW_ATTRIBUTE_LABEL',
            };
        }

        if (grep /history/, @handles) {
            push @buttons_handle, {
                'page' => 'workflow!history!view!result!wf_id!'.$wf_info->{workflow}->{id},
                'label' => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_LABEL',
            };
        }

        if (grep /techlog/, @handles) {
            push @buttons_handle, {
                'page' => 'workflow!log!view!result!wf_id!'.$wf_info->{workflow}->{id},
                'label' => 'I18N_OPENXPKI_UI_WORKFLOW_LOG_LABEL',
            };
        }

        if (@buttons_handle) {
            $buttons_handle[-1]->{break_after} = 1;
        }
        push @buttons_handle, $self->__get_global_action_handles($wf_info)->@*;

    }

    $self->set_page(
        label => $self->__page_label($wf_info),
        large => 1,
    );

    my $proc_state = $wf_info->{workflow}->{proc_state};

    $self->main->add_section({
        type => 'keyvalue',
        content => {
            label => $self->__get_proc_state_label($proc_state),
            description => $self->__get_proc_state_desc($proc_state),
            data => $fields,
            buttons => \@buttons_handle,
        },
    });
}

__PACKAGE__->meta->make_immutable;
