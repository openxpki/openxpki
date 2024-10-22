package OpenXPKI::Client::Service::WebUI::Page::Workflow::Attribute;
use OpenXPKI -class;

extends 'OpenXPKI::Client::Service::WebUI::Page::Workflow';

=head1 UI Methods

=head2 init_attribute

Requires parameter I<wf_id> which is the id of an existing workflow.
Shows the assigned attributes as plain key/value pairs - usually called in a popup.

=cut

sub init_attribute ($self, $args) {
    # re-instance existing workflow
    my $id = $self->param('wf_id');

    my $wf_info = $self->send_command_v2( 'get_workflow_info',  {
        id => $id,
        with_attributes => 1,
        with_ui_info => 1,
    }, { nostatus  => 1 });

    if (!$wf_info) {
        $self->status->error('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION') unless $self->status->is_set;
        return $self;
    }

    $self->set_page(
        label => $self->__page_label($wf_info, 'I18N_OPENXPKI_UI_WORKFLOW_ATTRIBUTE_LABEL'),
        large => 1,
    );

    $self->main->add_section({
        type => 'keyvalue',
        content => {
            label => '',
            data => $self->__render_fields( $wf_info, 'attribute'),
        },
    });

    return $self;

}

__PACKAGE__->meta->make_immutable;
