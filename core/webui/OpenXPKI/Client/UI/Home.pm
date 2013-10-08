# OpenXPKI::Client::UI::Home
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Home;

use Moose; 
use Data::Dumper;

extends 'OpenXPKI::Client::UI::Result';

my $meta = __PACKAGE__->meta;

sub BUILD {
    
    my $self = shift;
    $self->_page ({'label' => 'Welcome to your OpenXPKI Trustcenter'});    
}

sub init_index {
    
    my $self = shift;
    my $args = shift;
    
    $self->_result()->{main} = [{ 
        type => 'text',
        content => {
            headline => 'My little Headline',
            paragraphs => [{text=>'Paragraph 1'},{text=>'Paragraph 2'}]
        }
    }];
    
    # Initial login
    if ($args->{initial}) {
        $self->reload(1);
        #$self->set_status("You have 5 pending requests.");
    }
        
    return $self;
}

1;