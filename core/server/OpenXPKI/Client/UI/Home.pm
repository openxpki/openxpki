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
        
        my $search_result = $self->send_command( 'search_workflow_instances', $query);
 
        my @data;
        foreach my $item (@{$search_result}) {
            # special color for workflows in final failure            
            my $status = $item->{'WORKFLOW.WORKFLOW_PROC_STATE'};                    
            if ($status eq 'finished' && $item->{'WORKFLOW.WORKFLOW_STATE'} eq 'FAILURE') {
                $status  = 'failure';
            }
            push @data, [
                $item->{'WORKFLOW.WORKFLOW_SERIAL'},
                $item->{'WORKFLOW.WORKFLOW_LAST_UPDATE'},
                i18nGettext($item->{'WORKFLOW.WORKFLOW_TYPE'}),
                i18nGettext($item->{'WORKFLOW.WORKFLOW_STATE'}),
                $status
            ]
        }
        
        $self->logger()->trace( "dumper result: " . Dumper @data);

        $self->add_section({
            type => 'grid',
            className => 'workflow',
            processing_type => 'all',
            content => {
                label => i18nGettext($item->{label}),
                description => i18nGettext($item->{description}),
                actions => [{
                    path => 'redirect!workflow!load!wf_id!{serial}',
                    icon => 'view',
                }],
                columns => [
                    { sTitle => "serial" },
                    { sTitle => "updated" },
                    { sTitle => "type"},
                    { sTitle => "state"},
                    { sTitle => "_className"},
                ],
                data => \@data
            }
        });
    }

}

1;
