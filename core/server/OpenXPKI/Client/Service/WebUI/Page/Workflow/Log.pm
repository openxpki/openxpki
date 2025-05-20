package OpenXPKI::Client::Service::WebUI::Page::Workflow::Log;
use OpenXPKI -class;

extends 'OpenXPKI::Client::Service::WebUI::Page::Workflow';

=head1 UI Methods

=head2 init_log

Load and display the technical log file of the workflow

=cut

sub init_log ($self, $args) {
    my $id = $self->param('wf_id');
    my $view = $self->param('view') || '';

    my $wf_info = $self->send_command_v2( 'get_workflow_info', {
        id => $id,
    }, { nostatus  => 1 });

    $self->set_page(
        label => $self->page_label($wf_info, 'I18N_OPENXPKI_UI_WORKFLOW_LOG'),
        large => 1,
    );

    my $result = $self->send_command_v2( 'get_workflow_log', { id => $id } );

    $result = [] unless($result);

    $self->log->trace( "dumper result: " . Dumper $result) if $self->log->is_trace;

    $self->main->add_section({
        type => 'grid',
        className => 'workflow',
        content => {
            columns => [
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_LOG_TIMESTAMP_LABEL', format => 'timestamp'},
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_LOG_PRIORITY_LABEL'},
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_LOG_MESSAGE_LABEL'},
            ],
            data => $result,
            empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
        }
    });
}

__PACKAGE__->meta->make_immutable;
