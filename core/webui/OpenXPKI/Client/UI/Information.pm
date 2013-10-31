# OpenXPKI::Client::UI::Information
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Information;

use Moose; 
use Data::Dumper;

extends 'OpenXPKI::Client::UI::Result';

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
            label => 'My little Headline',
            description => 'Hello World'
        }
    }];
        
    return $self;
}

sub init_issuer {
    
    my $self = shift;
    my $args = shift;
        
    my $issuers = $self->send_command( 'get_ca_list' );    
    $self->logger()->debug("result: " . Dumper $issuers);
    
    $self->_page({
        label => 'Issuing certificates of this Realm',               
    });
   
   
    my @result;
    foreach my $cert (@{$issuers}) {      
        push @result, [    
            $cert->{SUBJECT}, 
            $cert->{NOTBEFORE},
            $cert->{NOTAFTER},
            $cert->{STATUS},
            $cert->{IDENTIFIER}        
        ];
    } 
    
    $self->add_section({
        type => 'grid',
        processing_type => 'all',
        content => {
            actions => [{   
                path => 'certificate!detail!identifier!{identifier}',                
                target => 'tab',
            }],            
            columns => [                        
                { sTitle => "subject" },
                { sTitle => "notbefore", format => 'timestamp'},
                { sTitle => "notafter", format => 'timestamp'},
                { sTitle => "state"},
                { sTitle => "identifier", bVisible => 0 },                                                
            ],
            data => \@result            
        }
    });
        
    return $self;
}

sub init_crl {
    
    my $self = shift;
    my $args = shift;
        
    my $crl_list = $self->send_command( 'get_crl_list' , { FORMAT => 'HASH', VALID_AT => time() });
        
    $self->logger()->debug("result: " . Dumper $crl_list);
    
    $self->_page({
        label => 'Revocation Lists of this realm',               
    });
      
    my @result;
    foreach my $crl (@{$crl_list}) {      
        push @result, [    
            $crl->{BODY}->{'SERIAL'},
            $crl->{BODY}->{'ISSUER'},                                               
            $crl->{BODY}->{'LAST_UPDATE'},
            $crl->{BODY}->{'NEXT_UPDATE'},
            scalar @{$crl->{LIST}},            
        ];
    } 
    
    $self->add_section({
        type => 'grid',
        processing_type => 'all',
        content => {
            actions => [{   
                label => 'download as Text',
                path => 'crl!download!serial!{serial}',                
                target => 'modal',
            },{   
                label => 'view details in browser',
                path => 'crl!detail!serial!{serial}',                
                target => 'tab',
            }],
            columns => [                        
                { sTitle => "serial" },
                { sTitle => "issuer" },
                { sTitle => "created", format => 'timestamp'},
                { sTitle => "expires", format => 'timestamp'},
                { sTitle => "items"},                                                                             
            ],
            data => \@result            
        }
    });
        
    return $self;
}

sub init_policy {
    
    my $self = shift;
    my $args = shift;
        
    $self->_page({
        label => 'Policy documents',
        description => 'we need to add some logic here to enable easy config outside the pm',               
    });
      
    
}

1;