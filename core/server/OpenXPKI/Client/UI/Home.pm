# OpenXPKI::Client::UI::Home
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Home;

use Moose;
use Template;
use Data::Dumper;

extends 'OpenXPKI::Client::UI::Result';

sub BUILD {

    my $self = shift;
    $self->_page ({'label' => 'Welcome to your OpenXPKI Trustcenter'});
}

sub init_welcome {


    my $self = shift;
    my $args = shift;


    # check if there are custom landmarks for this user
    my $landmark = $self->_client->session()->param('landmark');    
    if ($landmark && $landmark->{welcome}) {
        $self->logger()->debug('Found welcome landmark - redirecting user to ' . $landmark->{welcome});
        $self->redirect($landmark->{welcome});
        $self->reload(1);
    } else {
        $self->init_index();        
    }
    
    return $self;
}
    

sub init_index {

    my $self = shift;
    my $args = shift;

    $self->add_section({
        type => 'text',
        content => {
            label => '',
            description => 'This page was left blank.'
        }
    });

    return $self;
}
 
=head2 init_task

Redirect to workflow!task

=cut

sub init_task {

    my $self = shift; 
    $self->redirect('workflow!task');
    $self->reload(1);

}

1;
