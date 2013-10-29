# OpenXPKI::Client::UI::Home
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Home;

use Moose; 
use Data::Dumper;
use OpenXPKI::i18n qw( i18nGettext );

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

sub init_certificate {
    
    my $self = shift;
    my $args = shift;
    
    my $search_result = $self->send_command( 'list_my_certificates' );
    return $self unless(defined $search_result);
    
    $self->_page({
        label => 'My Certificates',        
    });
    
    my $i = 1;
    my @result;
    foreach my $item (@{$search_result}) {
        push @result, [
            $item->{'CERTIFICATE.SUBJECT'},
            $item->{'CERTIFICATE.NOTBEFORE'},
            $item->{'CERTIFICATE.NOTAFTER'},
            $item->{'CERTIFICATE.STATUS'},
            $item->{'CERTIFICATE.CERTIFICATE_SERIAL'},
            $item->{'CERTIFICATE.IDENTIFIER'},
            $item->{'CERTIFICATE.STATUS'},                
        ]
    }
 
    $self->logger()->trace( "dumper result: " . Dumper @result);
    
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
                { sTitle => "not before", format => 'timestamp'},
                { sTitle => "not after", format => 'timestamp'},
                { sTitle => "status"},
                { sTitle => "serial"},
                { sTitle => "identifier"},                   
                { sTitle => "_status"},                                                               
            ],
            data => \@result            
        }
    });
    return $self;
    
}

sub init_workflow {
    
    my $self = shift;
    my $args = shift;
    
    my $query = {
        CONTEXT => [{ KEY => 'creator', VALUE => $self->_client()->session()->param('user')->{user} }],
        LIMIT => 100
    }; 
    
    $self->logger()->debug("query : " . Dumper $query);
            
    my $search_result = $self->send_command( 'search_workflow_instances', $query );
    return $self unless(defined $search_result);
    
    $self->logger()->debug( "search result: " . Dumper $search_result);

    $self->_page({
        label => 'My Workflows',        
    });
    
    my $i = 1;
    my @result;
    foreach my $item (@{$search_result}) {
        push @result, [
            $item->{'WORKFLOW.WORKFLOW_SERIAL'},            
            $item->{'WORKFLOW.WORKFLOW_LAST_UPDATE'},
            $item->{'WORKFLOW.WORKFLOW_TYPE'},
            $item->{'WORKFLOW.WORKFLOW_STATE'},
            $item->{'WORKFLOW.WORKFLOW_PROC_STATE'},
            $item->{'WORKFLOW.WORKFLOW_WAKEUP_AT'},                
        ]
    }
 
    $self->logger()->trace( "dumper result: " . Dumper @result);
    
    $self->add_section({
        type => 'grid',
        processing_type => 'all',
        content => {
            actions => [{   
                path => 'workflow!load!wf_id!{serial}',
                target => 'tab',
            }],            
            columns => [                        
                { sTitle => "serial" },
                { sTitle => "updated" },
                { sTitle => "type"},
                { sTitle => "state"},
                { sTitle => "procstate"},
                { sTitle => "wake up", format => 'timestamp'},                                
            ],
            data => \@result            
        }
    });
    return $self;
    
}
1;