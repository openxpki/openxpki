# OpenXPKI::Client::UI::Home
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Home;

use Moose; 
use Data::Dumper;

extends 'OpenXPKI::Client::UI::Result';

sub BUILD {
    
    my $self = shift;
    $self->_page ({'label' => 'Welcome to your OpenXPKI Trustcenter'});    
}

sub init_welcome {
    
    
    my $self = shift;
    my $args = shift;
    
    $self->set_status("You have 5 pending requests.");
    $self->init_index( $args );
    
    return $self;
}

sub init_index {
    
    my $self = shift;
    my $args = shift;
    
    $self->_result()->{main} = [{ 
        type => 'text',
        content => {
            label => 'My little Headline',
            description => 'Hello World'
        }
    }];
        
    return $self;
}

1;