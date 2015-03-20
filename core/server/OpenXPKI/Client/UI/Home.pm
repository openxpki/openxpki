# OpenXPKI::Client::UI::Home
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Home;

use Moose;
use Template;
use Data::Dumper;

extends 'OpenXPKI::Client::UI::Result';

sub BUILD {

    my $self = shift;
    $self->_page ({'label' => 'Welcome to your OpenXPKI Trustcenter'});
}

sub init_welcome {


    my $self = shift;
    my $args = shift;


    # check if there are custom landmarks for this user
    my $landmark = $self->_client->session()->param('landmark');    
    if ($landmark && $landmark->{welcome}) {
        $self->logger()->debug('Found welcome landmark - redirecting user to ' . $landmark->{welcome});
        $self->redirect($landmark->{welcome});
        $self->reload(1);
    } else {
        $self->init_index();        
    }
    
    return $self;
}
    

sub init_index {

    my $self = shift;
    my $args = shift;

    $self->add_section({
        type => 'text',
        content => {
            label => '',
            description => 'This page was left blank.'
        }
    });

    return $self;
}
 
=head2 init_task

Outstanding tasks, for now pending approvals on CRR and CSR

=cut

sub init_task {

    my $self = shift;
    my $args = shift;

    $self->_page({
        label => 'Outstanding tasks'
    });

    my $tasklist = $self->_client->session()->param('tasklist');
    
    if (!$tasklist) {
        return $self->_redirect('home');
    }
    
    $self->logger()->debug( "got tasklist: " . Dumper $tasklist);
    
    foreach my $item (@$tasklist) {
        
        my $query = $item->{query};
        if (!$query->{LIMIT} || $query->{LIMIT} > 100) {
            $query->{LIMIT} = 100;
        }
         
        # Default columns
        if (!$item->{cols}) {
            $item->{cols} = [
                { label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SERIAL_LABEL', field => 'WORKFLOW_SERIAL', },
                { label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_UPDATED_LABEL', field => 'WORKFLOW_LAST_UPDATE', },
                { label => 'I18N_OPENXPKI_UI_WORKFLOW_TYPE_LABEL', field => 'WORKFLOW_TYPE', },
                { label => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_LABEL', field => 'WORKFLOW_STATE', },                
            ];
        }
            
        # create the header from the columns spec
        my @columns;
        my $wf_info_required = 0;
        my $tt;
        for (my $ii = 0; $ii < scalar @{$item->{cols}}; $ii++) {
            my $col = $item->{cols}->[$ii];
            push @columns, { sTitle => $col->{label} };
            
            if ($col->{template}) {
                $wf_info_required = 1;
                $tt = Template->new() unless($tt);                
            } elsif ($col->{field} =~ m{\A (context|attribute)\.(\S+) }xi) {
                $wf_info_required = 1;
                # we use this later to avoid the pattern match
                $col->{source} = $1;
                $col->{field} = $2; 
            } else {
                $col->{source} = 'workflow';
                $col->{field} = uc($col->{field}) 
            }
        }
        push @columns, { sTitle => 'serial', bVisible => 0 };
        push @columns, { sTitle => "_className"}; 
         
        $self->logger()->debug( "columns : " . Dumper $item);
         
        my @data;        
        my $search_result = $self->send_command( 'search_workflow_instances', $query);
        foreach my $wf_item (@{$search_result}) {
            
            my $wf_info; my $context; my $attrib;
            if ($wf_info_required) {
                $wf_info = $self->send_command( 'get_workflow_info', { ID => $wf_item->{'WORKFLOW.WORKFLOW_SERIAL'} });
                $self->logger()->debug( "columns : " . Dumper $wf_info);
                $context = $wf_info->{WORKFLOW}->{CONTEXT};
                $attrib = $wf_info->{WORKFLOW}->{ATTRIBUTE};  
            } 
            
            my @line;
            foreach my $col (@{$item->{cols}}) {
                
                if ($col->{template}) {
                    my $out;                    
                    my $ttp = { 
                        context => $context, 
                        attribute => $attrib, 
                        workflow => $wf_info->{WORKFLOW} 
                    };
                    if (!$tt->process( \$col->{template}, $ttp, \$out )) {
                        $out = 'template error!';
                        $self->logger()->error('Error processing template ->'.$col->{template}.'<- in workflow '. $wf_info->{WORKFLOW}->{ID});
                    }
                    push @line, $out;
                } elsif ($col->{source} eq 'workflow') {
                    push @line, $wf_item->{ 'WORKFLOW.'.$col->{field} };
                } elsif ($col->{source} eq 'context') {
                    push @line, $context->{ $col->{field} };
                } elsif ($col->{source} eq 'attribute') {
                    # to be implemented if required                    
                } else {
                    # hu ?
                }
            }    
            
            # special color for workflows in final failure            
            my $status = $wf_item->{'WORKFLOW.WORKFLOW_PROC_STATE'};                    
            if ($status eq 'finished' && $wf_item->{'WORKFLOW.WORKFLOW_STATE'} eq 'FAILURE') {
                $status  = 'failure';
            }
            
            push @line, $wf_item->{'WORKFLOW.WORKFLOW_SERIAL'};
            push @line, $status;
            
            push @data, \@line; 
        }
        
        $self->logger()->trace( "dumper result: " . Dumper @data);

        $self->add_section({
            type => 'grid',
            className => 'workflow',
            processing_type => 'all',
            content => {
                label => $item->{label},
                description => $item->{description},
                actions => [{
                    path => 'redirect!workflow!load!wf_id!{serial}',
                    icon => 'view',
                }],
                columns => \@columns,
                data => \@data
            }
        });
    }

}

1;
