package OpenXPKI::Client::UI::Home;
use Moose;

extends 'OpenXPKI::Client::UI::Result';

use Template;
use Data::Dumper;


sub BUILD {

    my $self = shift;
    $self->page->label('I18N_OPENXPKI_UI_HOME_WELCOME_HEAD');
}

sub init_welcome {

    my $self = shift;
    my $args = shift;

    # check for redirect
    my $redirect = $self->_client->session()->param('redirect') || '';
    $self->_client->session()->param('redirect','');
    if ($redirect =~ /welcome/) {
        # redirect to myself causes the UI to loop
        $redirect = "";
    }

    if ($redirect) {
        $self->log->debug('Found redirect - redirecting user to ' . $redirect);
        $self->redirect->to($redirect);
    } else {
        # check if there are custom landmarks for this user
        my $landmark = $self->_client->session()->param('landmark');
        if ($landmark && $landmark->{welcome}) {
            $self->log->debug('Found welcome landmark - redirecting user to ' . $landmark->{welcome});
            $self->redirect->to($landmark->{welcome});
        } else {
            $self->init_index();
        }
    }

    return $self;
}

sub init_index {

    my $self = shift;
    my $args = shift;

    $self->main->add_section({
        type => 'text',
        content => {
            label => '',
            description => 'I18N_OPENXPKI_UI_WELCOME_PAGE'
        }
    });

    return $self;
}

=head2 init_task

Redirect to workflow!task

=cut

sub init_task {

    my $self = shift;
    $self->redirect->to('workflow!task');

}

__PACKAGE__->meta->make_immutable;
