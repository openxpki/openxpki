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
    
    # Spec holds additional search attributes and list definition
    my @bulklist = @{$self->_session->param('bulk')->{default}};
    
    BULKITEM: 
    foreach my $bulk (@bulklist) {
    
        my @fields = ({
            name => 'wf_creator',
              label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_CREATOR_LABEL',
              type => 'text',
              is_optional => 1,          
            }
        );
                
        if ($bulk->{attributes}) {
            my @attrib;
            foreach my $item (@{$bulk->{attributes}}) {
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
     
        my $id = $self->__generate_uid();
        $self->_client->session()->param('bulk_'.$id, $bulk );
        push @fields, {
            name => 'formid', 
            type => 'hidden',
            value => $id
        };
    
        $self->add_section({
            type => 'form',
            action => 'bulk!result',
            content => {
                label => $bulk->{label},
                description => $bulk->{description},
                submit_label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SUBMIT_LABEL',
                fields => \@fields
            }
        }); 
    } # end bulkitem
  
    return $self;
}

sub action_result {
    
    my $self = shift;
    my $args = shift;

    # Read query pattern and list info from persisted data    
    my $spec = $self->_client->session()->param('bulk_'.$self->param('formid'));
    if (!$spec) {
        return $self->redirect('bulk!index');
    }
        
    my @attr;
    my @fielddesc;
    my $attributes = $spec->{attributes};    
    @attr = @{$self->__build_attribute_subquery( $attributes )} if ($attributes);

    my $query = $spec->{query};
    my $limit = 25;

    if ($self->param('wf_creator')) {        
        push @attr, { KEY => 'creator', VALUE => ~~ $self->param('wf_creator') };
    }
    
    if ($query->{LIMIT}) {
        $limit = $query->{LIMIT};
        delete $query->{LIMIT};
    }
        
    if (!$query->{ORDER}) {
        $query->{ORDER} = 'WORKFLOW.WORKFLOW_SERIAL';
        if (!defined $query->{REVERSE}) {
            $query->{REVERSE} = 1;
        }
    }

    $query->{ATTRIBUTE} = \@attr;

    $self->logger()->debug("query : " . Dumper $query);
    
    my $search_result = $self->send_command( 'search_workflow_instances', $query );

    # No results founds
    if (!$search_result) {
        $self->set_status('I18N_OPENXPKI_UI_SEARCH_HAS_NO_MATCHES','error');
        return $self->init_index();
    }
    
    $self->_page({
        label => $spec->{label} || 'I18N_OPENXPKI_UI_WORKFLOW_BULK_TITLE',
        description =>  $spec->{description},
    });
    
    # check if there is a custom column set defined
    my ($header,  $body);    
    if ($spec->{cols} && ref $spec->{cols} eq 'ARRAY') {
        ($header, $body) = $self->__render_list_spec( $spec->{cols} );
    } else {
         $body = $self->__default_grid_row;
         $header = self->__default_grid_head;
    }
    
    my @result = $self->__render_result_list( $search_result, $body ); 
        
    $self->logger()->trace( "dumper result: " . Dumper @result);

    my @buttons;
    foreach my $btn (@{$spec->{buttons}}) {
        # Copy required to not change the data in the session!
        my %btn = %{$btn};
        if ($btn{format}) {
            $btn{className} = $btn{format}; 
            delete $btn{format};
        }
        push @buttons, \%btn;
    }
    
    push @buttons, {
        label => 'back to list',
        page => 'bulk!index!' . $self->__generate_uid(), 
    };

    $self->add_section({
        type => 'grid',
        className => 'workflow',        
        content => {
            actions => [{
                path => 'workflow!load!wf_id!{serial}!view!result',
                label => 'I18N_OPENXPKI_UI_WORKFLOW_OPEN_WORKFLOW_LABEL',
                icon => 'view',
                target => 'tab',
            }],
            columns => $header,
            data => \@result,
            empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
            buttons => \@buttons         
        }
    });
    
    if (@fielddesc) {
        $self->add_section({
            type => 'keyvalue',
            content => {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_FIELD_HINT_LIST',
                description => '',
                data => \@fielddesc
        }});
    }
        
}


1; 
         
                     