# OpenXPKI::Client::UI::Bulk
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Bulk;

use Moose;
use Template;
use Data::Dumper;
use Date::Parse;

extends 'OpenXPKI::Client::UI::Workflow';

=head1 OpenXPKI::Client::UI::Bulk

Inherits from workflow, offers methods for workflow bulk processing.
This is experimental, most parameters are hardcoded.

=cut

sub init_index {

    my $self = shift;
    my $args = shift;

    $self->_page({
        label => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_TITLE',
        description => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_DESCRIPTION',
    });
    
    my @fields = ({ name => 'wf_creator',
      label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_CREATOR_LABEL',
      type => 'text',
      is_optional => 1,
      value => ''
    });
            
    # Searchable attributes are read from the menu bootstrap   
    my $attributes = $self->_session->param('wfsearch')->{default};    
    if ($attributes) {
        my @attrib;
        foreach my $item (@{$attributes}) {
            push @attrib, { value => $item->{key}, label=> $item->{label} };                    
        }
        push @fields, {
            name => 'attributes', 
            label => 'Metadata', 
            'keys' => \@attrib,                  
            type => 'text',
            is_optional => 1, 
            'clonable' => 1
        };                            
    }

    $self->add_section({
        type => 'form',
        action => 'bulk!csr',
        content => {
            label => 'Bulk process certification requests',
            submit_label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SUBMIT_LABEL',
            fields => \@fields         
        }
    }); 
 
    $self->add_section({
        type => 'form',
        action => 'bulk!crr',
        content => {
            label => 'Bulk process revocation requests',
            submit_label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SUBMIT_LABEL',
            fields => \@fields         
        }
    });

    return $self;
}

sub action_csr {
    
    my $self = shift;
    my $args = shift;

    # Read the query pattern for extra attributes from the session
    my $attributes = $self->_session->param('wfsearch')->{default};
    my @attr = @{$self->__build_attribute_subquery( $attributes )};

    my $query = {
        TYPE => 'certificate_signing_request_v2',
        STATE => 'PENDING',
        ATTRIBUTE => \@attr,
        LIMIT => 500
    };

    my $search_result = $self->send_command( 'search_workflow_instances', $query );

    # No results founds
    if (!$search_result) {
        $self->set_status('Your query did not return any matches.','error');
        return $self->init_index();
    }
    
    $self->_page({
        label => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_TITLE',
        description => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_DESCRIPTION',
    });
    
    my @result = $self->__render_result_list( $search_result, $self->__default_grid_row ); 
        
    $self->logger()->trace( "dumper result: " . Dumper @result);

    $self->add_section({
        type => 'grid',
        className => 'workflow',
        processing_type => 'all',
        content => {
            actions => [{
                path => 'workflow!load!wf_id!{serial}!view!result',
                label => 'I18N_OPENXPKI_UI_WORKFLOW_OPEN_WORKFLOW_LABEL',
                icon => 'view',
                target => 'tab',
            }],
            columns => $self->__default_grid_head,
            data => \@result,
            buttons => [
                { 
                    label => 'approve selected items', 
                    action => 'workflow!bulk!wf_action!csr_approve_csr', 
                    select => 'serial', 
                    'selection' => 'wf_id' 
                },
                { 
                    label => 'reject selected items', 
                    action => 'bulk!execute!action!csr_reject', 
                    select => 'serial',
                    'selection' => 'serial'
                }
            
            ]            
        }
    });
    
}


1;
