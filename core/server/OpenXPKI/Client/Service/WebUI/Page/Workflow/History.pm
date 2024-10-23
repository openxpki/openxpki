package OpenXPKI::Client::Service::WebUI::Page::Workflow::History;
use OpenXPKI -class;

extends 'OpenXPKI::Client::Service::WebUI::Page::Workflow';

=head1 UI Methods

=head2 init_history

Render the history as grid view (state/action/user/time)

=cut

sub init_history ($self, $args) {
    my $id = $self->param('wf_id');
    my $view = $self->param('view') || '';

    my $wf_info = $self->send_command_v2( 'get_workflow_info',  {
        id => $id,
    }, { nostatus  => 1 });

    $self->set_page(
        label => $self->page_label($wf_info, 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_TITLE'),
        description => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_DESCRIPTION',
        large => 1,
    );

    my $workflow_history = $self->send_command_v2( 'get_workflow_history', { id => $id } );

    $self->log->trace( "dumper result: " . Dumper $workflow_history) if $self->log->is_trace;

    my $i = 1;
    my @result;
    foreach my $item (@{$workflow_history}) {
        push @result, [
            $item->{'workflow_history_date'},
            $item->{'workflow_state'},
            $item->{'workflow_action'},
            $item->{'workflow_description'},
            $item->{'workflow_user'},
            $item->{'workflow_node'},
        ]
    }

    $self->log->trace( "dumper result: " . Dumper $workflow_history) if $self->log->is_trace;

    $self->main->add_section({
        type => 'grid',
        className => 'workflow',
        content => {
            columns => [
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_EXEC_TIME_LABEL' }, #, format => 'datetime'},
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_STATE_LABEL' },
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_ACTION_LABEL' },
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_DESCRIPTION_LABEL' },
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_USER_LABEL' },
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_NODE_LABEL' },
            ],
            data => \@result,
        },
    });

    return $self;
}

__PACKAGE__->meta->make_immutable;
