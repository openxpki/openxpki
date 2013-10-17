# OpenXPKI::Client::UI::Workflow::Metadata
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Workflow::Metadata;

use Moose; 
use Data::Dumper;
use English;
use OpenXPKI::Serialization::Simple;

extends 'OpenXPKI::Client::UI::Workflow';
    
    
# Note - when using the generic worklfow wrapper, the class is called in a 
# static context an self is a ref to the workflow result and not to this class!    
sub render_update_form {
    
    # allow static and real method call
    my $self = shift;
    $self = shift unless (ref $self);
    my $args = shift;
    
    $self->logger()->debug(  'self: ' . Dumper $args );
        
    $self->_page({
        label => 'Update meta information',
        description => 'do we need some more here?'
    });
    
    my $wf_info = $args->{WF_INFO};    
    
                
    my $current_metadata_ser = $wf_info->{WORKFLOW}->{CONTEXT}->{metadata_update}   
        || $wf_info->{WORKFLOW}->{CONTEXT}->{current_metadata};
    
    # Serialization 
    my $ser = OpenXPKI::Serialization::Simple->new();
    my $current_metadata  = $ser->deserialize($current_metadata_ser);
    $self->logger()->debug( "current_metadata: " . Dumper $current_metadata );
    
    my @fields;
    foreach my $field (keys %{$current_metadata}) {
       push @fields, { name => "metadata_update{$field}", label => $field, value => $current_metadata->{$field}, type => 'text' }; 
    }
    
    # record the workflow info in the session
    push @fields, $self->__register_wf_token($wf_info, {
        wf_action =>  (keys %{$wf_info->{ACTIVITY}})[0],         
        wf_fields => \@fields,
    });
    
    $self->_result()->{main} = [{   
        type => 'form',
        action => 'workflow',
        content => {           
        submit_label => 'update',
            fields => \@fields
        }},
    ]; 
    
    return $self;
    
}

sub render_current_data {
    
    # allow static and real method call
    my $self = shift;
    $self = shift unless (ref $self);
    my $args = shift;
    
    $self->logger()->debug(  'self: ' . Dumper $args );
        
    $self->_page({
        label => 'Update meta information',
        description => 'do we need some more here?'
    });
    
    my $wf_info = $args->{WF_INFO};    
            
    my $current_metadata_ser = $wf_info->{WORKFLOW}->{CONTEXT}->{current_metadata};
    # Serialization 
    my $ser = OpenXPKI::Serialization::Simple->new();
    my $current_metadata  = $ser->deserialize($current_metadata_ser);
    $self->logger()->debug( "current_metadata: " . Dumper $current_metadata );
    
    my @fields;
    foreach my $field (keys %{$current_metadata}) {
       push @fields, { label => $field, value => $current_metadata->{$field} }; 
    }
    
    my $button_section = $self->__get_action_buttons( $wf_info );
    
    $self->_result()->{main} = [{
        type => 'keyvalue',
        content => {
            label => '',
            description => '',
            data => \@fields,
        }},           
        @{$button_section}
    ]; 
    
    
    return $self;
    
}

