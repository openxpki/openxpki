package OpenXPKI::Client::Service::WebUI::Page::Home;
use OpenXPKI -class;

extends 'OpenXPKI::Client::Service::WebUI::Page';

sub BUILD ($self, $args) {
    $self->page->label('I18N_OPENXPKI_UI_HOME_WELCOME_HEAD');
}

sub init_welcome ($self, $args) {
    # check for redirect
    my $redirect = $self->session_param('redirect') || '';
    $self->session_param('redirect','');
    if ($redirect =~ /welcome/) {
        # redirect to myself causes the UI to loop
        $redirect = '';
    }

    if ($redirect) {
        $self->log->debug('Found redirect - redirecting user to ' . $redirect);
        $self->redirect->to($redirect);
    } else {
        # check if there are custom landmarks for this user
        my $landmark = $self->session_param('landmark');
        if ($landmark && $landmark->{welcome}) {
            $self->log->debug('Found welcome landmark - redirecting user to ' . $landmark->{welcome});
            $self->redirect->to($landmark->{welcome});
        } else {
            $self->init_index();
        }
    }
}

sub init_index ($self, $args = {}) {
    $self->main->add_section({
        type => 'text',
        content => {
            label => '',
            description => 'I18N_OPENXPKI_UI_WELCOME_PAGE'
        }
    });
}

=head2 init_task

Redirect to workflow!task

=cut

sub init_task ($self, $args) {
    $self->redirect->to('workflow!task');
}

__PACKAGE__->meta->make_immutable;
