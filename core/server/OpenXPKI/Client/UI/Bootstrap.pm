# OpenXPKI::Client::UI::Bootstrap
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Bootstrap;

use Moose;
use Data::Dumper;
use OpenXPKI::i18n qw( i18nTokenizer );

extends 'OpenXPKI::Client::UI::Result';

sub init_structure {

    my $self = shift;
    my $session = $self->_session;
    my $user = $session->param('user') || undef;

    if ($session->param('is_logged_in') && $user) {
        $self->_result()->{user} = $user;
        my $menu = $self->send_command( 'get_menu' );
        $self->logger()->trace('Menu ' . Dumper $menu);

        $self->_result()->{structure} = $menu->{main};
        
        # persist the optional parts of the menu hash (landmark, tasklist, search attribs)
        $session->param('landmark', $menu->{landmark} || {});
        $self->logger->debug('Got landmarks: ' . Dumper $menu->{landmark});
        
        # tasklist, wfsearch, certsearch and bulk can have multiple branches
        # using named keys. If a list is returned, we map this as "default"
        foreach my $key (qw(wfsearch certsearch tasklist bulk)) {
            
            if (ref $menu->{$key} eq 'ARRAY') {
                $session->param($key, { 'default' => $menu->{$key} });
            } elsif (ref $menu->{$key} eq 'HASH') {
                $session->param($key, $menu->{$key} );
            } else {
                $session->param($key, { 'default' => [] });
            }
            $self->logger->debug("Got $key: " . Dumper $menu->{$key});    
        }
        
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
