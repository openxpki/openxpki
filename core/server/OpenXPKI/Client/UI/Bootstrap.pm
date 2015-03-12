# OpenXPKI::Client::UI::Bootstrap
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Bootstrap;

use Moose;
use Data::Dumper;
use OpenXPKI::i18n qw( i18nGettext i18nTokenizer );

extends 'OpenXPKI::Client::UI::Result';

sub init_structure {

    my $self = shift;
    my $session = $self->_client()->session();
    my $user = $session->param('user') || undef;

    if ($session->param('is_logged_in') && $user) {
        $self->_result()->{user} = $user;
        my $menu = $self->send_command( 'get_menu' );
        $self->logger()->trace('Menu ' . Dumper $menu);

        # We need to translate the labels
        my $nav = $menu->{main};        
        for (my $ii = 0; $ii < scalar (@{$nav}); $ii++) {
                        
            if ($nav->[$ii]->{label}) {
                $nav->[$ii]->{label} = i18nGettext($nav->[$ii]->{label});
            }
            
            if (ref $nav->[$ii]->{entries}) {
                for (my $jj = 0; $jj < scalar (@{$nav->[$ii]->{entries}}); $jj++) {
                    $nav->[$ii]->{entries}->[$jj]->{label} 
                        = i18nGettext($nav->[$ii]->{entries}->[$jj]->{label});
                }                
            }           
        }
        
        $self->_result()->{structure} = $nav;
        
        # persist the optional parts of the menu hash (landmark, tasklist, search attribs)
        $self->_client->session()->param('landmark', $menu->{landmark} || {});
        $self->_client->session()->param('tasklist', $menu->{tasklist} || []);
        $self->_client->session()->param('wfsearch', $menu->{wfsearch} || []);
        $self->_client->session()->param('certsearch', $menu->{certsearch} || []);
        $self->logger->debug('Got landmarks: ' . Dumper $menu->{landmark});
        $self->logger->debug('Got tasklist: ' . Dumper $menu->{tasklist});
        $self->logger->debug('Got wfsearch: ' . Dumper $menu->{wfsearch});
        $self->logger->debug('Got wfsearch: ' . Dumper $menu->{certsearch});
        
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
