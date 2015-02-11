# OpenXPKI::Client::UI::Bootstrap
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Bootstrap;

use Moose;
use Data::Dumper;

extends 'OpenXPKI::Client::UI::Result';

sub init_structure {

    my $self = shift;
    my $session = $self->_client()->session();
    my $user = $session->param('user') || undef;

    if ($session->param('is_logged_in') && $user) {
        $self->_result()->{user} = $user;
        my $menu = $self->send_command( 'get_menu' );
        $self->logger()->trace('Menu ' . Dumper $menu);
        $self->_result()->{structure} = $menu->{main};
        
        # persist the landmark part of the menu, if any
        $self->_client->session()->param('landmark', $menu->{landmark} || {});
        $self->logger->debug('Got landmarks: ' . Dumper $menu->{landmark});
        
    }
    
    if (!$self->_result()->{structure}) {
        $self->_result()->{structure} =
        [{
            key => 'logout',
            label =>  'Clear Login',
            entries =>  []
        }]
    }

    return $self;

}


sub init_error {

    my $self = shift;
    my $args = shift;

    $self->_result()->{main} = [{
        type => 'text',
        content => {
            headline => 'Ooops - something went wrong',
            paragraphs => [{text=>'Something is wrong here'}]
        }
    }];

    return $self;
}
1;
