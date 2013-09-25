# OpenXPKI::Client::UI::Result
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Result;

use Moose; 

# ref to the cgi frontend session
has _error => (       
    is => 'rw',
    isa => 'HashRef|Undef',
);

has _page => (
    is => 'rw',      
    isa => 'HashRef|Undef',
    lazy => 1,
    default => undef        
);

has _status => (    
    is => 'rw',   
    isa => 'HashRef|Undef',
);

has _result => (
    is => 'rw',       
    isa => 'HashRef|Undef',
    default => sub { return {}; }
);

sub set_status {
    
    my $self = shift;
    my $message = shift;
    my $level = shift || 'info';
    
    $self->_status({ level => $level, message => $message });
    
    return $self;
    
}

sub set_status_from_error_reply {
    
    my $self = shift;
    my $reply = shift;
    
    my $message = 'unknown error'; 
    if ($reply->{'LIST'} 
        && ref $reply->{'LIST'} eq 'ARRAY'
        && $reply->{'LIST'}->[0]->{LABEL}) {    
        $message = $reply->{'LIST'}->[0]->{LABEL};            
    }   
    $self->_status({ level => 'error', message => $message });
    
    return $self;
}

sub render {
    
    my $self = shift;
    
    my $result = $self->_result();

    $result->{error} = $self->_error() if $self->_error();
    $result->{status} = $self->_status() if $self->_status();    
    $result->{page} = $self->_page() if $self->_page();
    
    return $result;
}

1;