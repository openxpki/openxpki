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

    # TODO - need to make enable filter for own workflows by configuration
    # CSR
    my $search_result = $self->send_command( 'search_workflow_instances', {
        LIMIT => 100,  # Safety barrier
        #ATTRIBUTE => [{ KEY => 'creator', VALUE => $self->_client()->session()->param('user')->{name}, OPERATOR => 'NOT_EQUAL' }],
        TYPE => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST_V2',
        STATE => [ 'PENDING', 'APPROVAL' ],
    });

    my @csr;
    foreach my $item (@{$search_result}) {
        push @csr, [
            $item->{'WORKFLOW.WORKFLOW_SERIAL'},
            $item->{'WORKFLOW.WORKFLOW_LAST_UPDATE'},
            i18nGettext($item->{'WORKFLOW.WORKFLOW_TYPE'}),
            i18nGettext($item->{'WORKFLOW.WORKFLOW_STATE'}),
            i18nGettext($item->{'WORKFLOW.WORKFLOW_PROC_STATE'}),
        ]
    }

    $self->logger()->trace( "dumper result: " . Dumper @csr);

    $self->add_section({
        type => 'grid',
        className => 'workflow',
        processing_type => 'all',
        content => {
            label => 'Certificate requests',
            actions => [{
                path => 'redirect!workflow!load!wf_id!{serial}',
                icon => 'view',
            }],
            columns => [
                { sTitle => "serial" },
                { sTitle => "updated" },
                { sTitle => "type"},
                { sTitle => "state"},
                { sTitle => "procstate"},
            ],
            data => \@csr
        }
    });


    $search_result = $self->send_command( 'search_workflow_instances', {
        LIMIT => 100,  # Safety barrier
        #ATTRIBUTE => [{ KEY => 'creator', VALUE => $self->_client()->session()->param('user')->{name}, OPERATOR => 'NOT_EQUAL' }],
        TYPE => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_REVOCATION_REQUEST_V2',
        STATE => [ 'PENDING', 'ONHOLD' ],
    });

    my @crr = ();
    foreach my $item (@{$search_result}) {
        push @crr, [
            $item->{'WORKFLOW.WORKFLOW_SERIAL'},
            $item->{'WORKFLOW.WORKFLOW_LAST_UPDATE'},
            i18nGettext($item->{'WORKFLOW.WORKFLOW_TYPE'}),
            i18nGettext($item->{'WORKFLOW.WORKFLOW_STATE'}),
            i18nGettext($item->{'WORKFLOW.WORKFLOW_PROC_STATE'}),
        ]
    }

    $self->logger()->trace( "dumper result: " . Dumper @crr);

    $self->add_section({
        type => 'grid',
        className => 'workflow',
        processing_type => 'all',
        content => {
            label => 'Revocation requests',
            actions => [{
                path => 'redirect!workflow!load!wf_id!{serial}',
                icon => 'view',
            }],
            columns => [
                { sTitle => "serial" },
                { sTitle => "updated" },
                { sTitle => "type"},
                { sTitle => "state"},
                { sTitle => "procstate"},
            ],
            data => \@crr
        }
    });


}

1;
