# OpenXPKI::Client::UI::Home
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Search;

use Moose; 
use Data::Dumper;

extends 'OpenXPKI::Client::UI::Result';

sub BUILD {    
    my $self = shift;       
}

sub init_certificate {
    
    my $self = shift;
    my $args = shift;
    
    $self->_page({
        label => 'Certificate Search',
        description => 'You can search for certs here.',
    });
    
    $self->_result()->{main} = [        
        {   type => 'form',
            action => 'search!certificate',
            content => {
                title => '',
                submit_label => 'search now',
                fields => [
                { name => 'subject', label => 'Subject', type => 'text', is_optional => 1 },
                { name => 'issuer', label => 'Issuer', type => 'text', is_optional => 1 },
                ]
        }},
        {   type => 'text', content => {
            headline => 'My little Headline',
            paragraphs => [{text=>'Paragraph 1'},{text=>'Paragraph 2'}]
        }},    
    ];
        
    return $self;
}

sub action_certificate {
    
    
    my $self = shift;
    my $args = shift;
    
    my $query = { LIMIT => 100 }; # Safety barrier
    foreach my $key (qw(subject issuer)) {
        my $val = $self->param($key);    
        if (defined $val && $val ne '') {
            $query->{uc($key)} = $val;     
        }
    }
    
    $self->logger()->debug("query : " . Dumper $query);
            
    my $search_result = $self->send_command( 'search_cert', $query );
    return $self unless(defined $search_result);
    
    $self->logger()->debug( "search result: " . Dumper $search_result);

    $self->_page({
        label => 'Certificate Search - Results',
        description => 'Here are the results of the swedish jury:',
    });
    
    my $i = 1;
    my @result;
    foreach my $item (@{$search_result}) {
        push @result, [
            $item->{CERTIFICATE_SERIAL},
            $item->{SUBJECT},
            $item->{EMAIL} || '',
            $item->{NOTBEFORE},
            $item->{NOTAFTER},
            $item->{ISSUER_DN},
            $item->{IDENTIFIER},                
        ]
    }
 
    $self->logger()->trace( "dumper result: " . Dumper @result);
    
    $self->add_section({
        type => 'grid',
        processing_type => 'all',
        content => {
            header => 'Grid-Headline',
            preambel => 'some text before...',
            postambel => 'some text after...',
            columns => [                        
                { sTitle => "serial" },
                { sTitle => "subject" },
                { sTitle => "email"},
                { sTitle => "notbefore"},
                { sTitle => "notafter"},
                { sTitle => "issuer"},
                { sTitle => "identifier"}
            ],
            data => \@result            
        }
    });
    return $self;
    
}
    
sub init_workflow {
    
    my $self = shift;
    my $args = shift;

    $self->_page({
        label => 'Workflow Search',
        description => 'You can search for workflows here.',
    });
    
    
    my $workflows = $self->send_command( 'list_workflow_titles' );
    return $self unless(defined $workflows);
    
    # TODO Sorting / I18
    my @wf_names = keys %{$workflows};
    sort @wf_names;
    
    my @wfl_list = map { $_ = {'value' => $_, 'label' => $workflows->{$_}->{label}} } @wf_names ;
    
    $self->_result()->{main} = [  
        {   type => 'form',
            action => 'workflow!compact',
            content => {
                title => 'Get workflow info by known workflow id',
                submit_label => 'search now',
                fields => [                    
                    { name => 'wfid', label => 'Workflow Id', type => 'text', is_optional => 1 },                                       
                ]
        }},      
        {   type => 'form',
            action => 'search!workflow',
            content => {
                title => 'Search the database',
                submit_label => 'search now',
                fields => [                    
                    { name => 'type', label => 'Type', type => 'select', is_optional => 1, options => \@wfl_list  },
                    { name => 'state', label => 'State', type => 'text', is_optional => 1 },                    
                    { name => 'creator', label => 'Creator', type => 'text', is_optional => 1 },                    
                ]
        }}  
    ];
        
    return $self;
}


sub action_workflow {
    
    
    my $self = shift;
    my $args = shift;
    
    my $query = { LIMIT => 100 }; # Safety barrier
    foreach my $key (qw(type state)) {
        my $val = $self->param($key);    
        if (defined $val && $val ne '') {
            $query->{uc($key)} = $val;     
        }
    }
    
    # creator via context (urgh... - needs change)
    if ($self->param('creator')) {
        $query->{CONTEXT} = [{ creator => $self->param('creator') }];
    }
    
    $self->logger()->debug("query : " . Dumper $query);
            
    my $search_result = $self->send_command( 'search_workflow_instances', $query );
    return $self unless(defined $search_result);
    
    $self->logger()->debug( "search result: " . Dumper $search_result);

    $self->_page({
        label => 'Workflow Search - Results',
        description => 'Here are the results of the swedish jury:',
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
            header => 'Grid-Headline',
            preambel => 'some text before...',
            postambel => 'some text after...',
            columns => [                        
                { sTitle => "serial" },
                { sTitle => "updated" },
                { sTitle => "type"},
                { sTitle => "state"},
                { sTitle => "procstate"},
                { sTitle => "wake up"},                                
            ],
            data => \@result            
        }
    });
    return $self;
    
}
    
1;