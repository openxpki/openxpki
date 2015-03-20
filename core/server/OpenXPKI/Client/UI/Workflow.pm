# OpenXPKI::Client::UI::Workflow
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Workflow;

use Moose;
use Data::Dumper;
use Date::Parse;

extends 'OpenXPKI::Client::UI::Result';

=head1 OpenXPKI::Client::UI::Workflow

Generic UI handler class to render a workflow into gui elements.
It first present a description of the workflow generated from the initial
states description and a start button which creates the instance. Due to the
workflow internals we are unable to fetch the field info from the initial
state and therefore a workflow must not require any input fields at the
time of creation. A brief description is given at the end of this document.

=cut

sub BUILD {
    my $self = shift;
}

=head1 UI Methods

=head2 init_index

Requires parameter I<wf_type> and shows the intro page of the workflow.
The headline is the value of type followed by an intro text as given
as workflow description. At the end of the page a button names "start"
is shown.

This is usually used to start a workflow from the menu or link, e.g.

    workflow!index!wf_type!I18N_OPENXPKI_WF_TYPE_CHANGE_METADATA

=cut

sub init_index {

    my $self = shift;
    my $args = shift;

    my $wf_info = $self->send_command( 'get_workflow_info', {
        TYPE => $self->param('wf_type'), UIINFO => 1
    });

    if (!$wf_info) {
        $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION','error');
        return $self;
    }

    # Pass the initial activity so we get the form right away
    my $wf_action = (keys %{$wf_info->{ACTIVITY}})[0];

    $self->__render_from_workflow({ WF_INFO => $wf_info, WF_ACTION => $wf_action });
    return $self;

}

=head2 init_start

Same as init_index but directly creates the workflow and displays the result
of the initial action. Normal workflows will result in a redirect using the
workflow id, volatile workflows are displayed directly. This works only with
workflows that do not require any initial parameters.

=cut
sub init_start {

    my $self = shift;
    my $args = shift;

    my $wf_info = $self->send_command( 'create_workflow_instance', {
       WORKFLOW => $self->param('wf_type'), PARAMS   => {}, UIINFO => 1
    });

    if (!$wf_info) {
        # todo - handle errors
        $self->logger()->error("Create workflow failed");
        return $self;
    }

    $self->logger()->trace("wf info on create: " . Dumper $wf_info );

    $self->logger()->info(sprintf "Create new workflow %s, got id %01d",  $wf_info->{WORKFLOW}->{TYPE}, $wf_info->{WORKFLOW}->{ID} );

    # this duplicates code from action_index
    if ($wf_info->{WORKFLOW}->{ID} > 0) {

        my $redirect = 'workflow!load!wf_id!'.$wf_info->{WORKFLOW}->{ID};
        my @activity = keys %{$wf_info->{ACTIVITY}};
        if (scalar @activity == 1) {
            $redirect .= '!wf_action!'.$activity[0];
        }
        $self->redirect($redirect);

    } else {
        # one shot workflow
        $self->__render_from_workflow({ WF_INFO => $wf_info });
    }

    return $self;

}


=head2 init_load

Requires parameter I<wf_id> which is the id of an existing workflow.
It loads the workflow at the current state and tries to render it
using the __render_from_workflow method.

=cut

sub init_load {

    my $self = shift;
    my $args = shift;

    # re-instance existing workflow
    my $id = $self->param('wf_id');
    my $wf_action = $self->param('wf_action') || '';
    my $view = $self->param('view') || '';

    my $wf_info = $self->send_command( 'get_workflow_info', {
        ID => $id,
        UIINFO => 1,
    });

    if (!$wf_info) {
        $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION','error') unless($self->_status());
        return $self;
    }


    # Set single action if not in result view and only single action is avail
    if (($view ne 'result') && !$wf_action) {
        my @activities = @{$wf_info->{STATE}->{option}};
        if (scalar @activities == 1) {
            $wf_action = $activities[0];
        }
    }

    $self->__render_from_workflow({ WF_INFO => $wf_info, WF_ACTION => $wf_action, VIEW => $view });

    return $self;

}

=head2

Render form for the workflow search.
#TODO: Preset parameters

=cut
sub init_search {

    my $self = shift;
    my $args = shift;

    $self->_page({
        label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_TITLE',
        description => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_DESCRIPTION',
    });

    my $workflows = $self->send_command( 'get_workflow_instance_types' );
    return $self unless(defined $workflows);
    
    $self->logger()->debug('Workflows ' . Dumper $workflows);
    
    my $preset;
    if ($args->{preset}) {
        $preset = $args->{preset};    
    } elsif (my $queryid = $self->param('query')) {
        my $result = $self->_client->session()->param('query_wfl_'.$queryid);
        $preset = $result->{input};
    }
    
    $self->logger()->debug('Preset ' . Dumper $preset);

    # TODO Sorting / I18
    my @wf_names = keys %{$workflows};
    my @wfl_list = map { $_ = {'value' => $_, 'label' => $workflows->{$_}->{label}} } @wf_names ;
    @wfl_list = sort { lc($a->{'label'}) cmp lc($b->{'label'}) } @wfl_list;

    my @proc_states = (        
        { label => 'I18N_OPENXPKI_UI_WORKFLOW_PROC_STATE_MANUAL', value => 'manual' },
        { label => 'I18N_OPENXPKI_UI_WORKFLOW_PROC_STATE_EXCEPTION', value => 'exception' },
        { label => 'I18N_OPENXPKI_UI_WORKFLOW_PROC_STATE_PAUSE', value => 'pause' },
        { label => 'I18N_OPENXPKI_UI_WORKFLOW_PROC_STATE_FINISHED', value => 'finished' },        
    );    
    
    my @fields = (
        { name => 'wf_type',
          label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_TYPE_LABEL',
          type => 'select',
          is_optional => 1,
          options => \@wfl_list,
          value => $preset->{wf_type} 
        },
        { name => 'wf_proc_state',
          label => 'I18N_OPENXPKI_UI_WORKFLOW_PROC_STATE_LABEL', 
          type => 'select',
          is_optional => 1,
          prompt => '',
          options => \@proc_states,
          value => $preset->{wf_proc_state}
        },
        { name => 'wf_state',
          label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_STATE_LABEL',
          type => 'text',
          is_optional => 1,
          prompt => '',
          value => $preset->{wf_state}
        },
        { name => 'wf_creator',
          label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_CREATOR_LABEL',
          type => 'text',
          is_optional => 1,
          value => $preset->{wf_creator}
        }
    );   

    # Searchable attributes are read from the menu bootstrap
    
    my $attributes = $self->_client->session()->param('wfsearch');    
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

    $self->_result()->{main} = [
        {   type => 'form',
            action => 'workflow!load',
            content => {
                title => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SEARCH_BY_ID_TITLE',
                submit_label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SUBMIT_LABEL',
                fields => [
                    { name => 'wf_id', label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_WORKFLOW_ID_LABEL', type => 'text' },
                ]
        }},
        {   type => 'form',
            action => 'workflow!search',
            content => {
                title => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SEARCH_DATABASE_TITLE',
                submit_label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SUBMIT_LABEL',
                fields => \@fields         
            }
        }
    ];

    return $self;
}


=head2 init_result

Load the result of a query, based on a query id and paging information
 
=cut
sub init_result {

    my $self = shift;
    my $args = shift;
        
    my $queryid = $self->param('id');
    my $limit = sprintf('%01d', $self->param('limit'));
    my $startat = sprintf('%01d', $self->param('startat')); 
    
    # Safety rule
    if (!$limit) { $limit = 50; }
    elsif ($limit > 500) {  $limit = 500; }

    # Load query from session
    my $result = $self->_client->session()->param('query_wfl_'.$queryid);

    # result expired or broken id
    if (!$result || !$result->{count}) {        
        $self->set_status('Search result expired or empty!','error');
        return $self->init_search();               
    }

    # Add limits
    my $query = $result->{query};    
    $query->{LIMIT} = $limit;
    $query->{START} = $startat;

    $self->logger()->debug( "persisted query: " . Dumper $result);

    my $search_result = $self->send_command( 'search_workflow_instances', $query );
    
    $self->logger()->trace( "search result: " . Dumper $search_result);

    $self->_page({
        label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_RESULTS_TITLE',
        description => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_RESULTS_DESCRIPTION',
    });
    
    my @result = $self->__render_result_list( $search_result ); 
        
    $self->logger()->trace( "dumper result: " . Dumper @result);

    $self->add_section({
        type => 'grid',
        className => 'workflow',
        processing_type => 'all',
        content => {
            header => 'Grid-Headline',
            actions => [{
                path => 'workflow!load!wf_id!{serial}!view!result',
                label => 'I18N_OPENXPKI_UI_WORKFLOW_OPEN_WORKFLOW_LABEL',
                icon => 'view',
                target => 'tab',
            }],
            columns => [
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SERIAL_LABEL' },
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_UPDATED_LABEL' },
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_TYPE_LABEL' },
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_LABEL' },
                { sTitle => 'serial', bVisible => 0 },
                { sTitle => "_className"},
            ],
            data => \@result,
            pager => { startat => ($startat*1), limit => ($limit*1), count => ($result->{count}*1), 
                pagesizes => [25,50,100,250,500], pagersize => 20 },
            buttons => [
                { label => 'reload search form', page => 'workflow!search!query!' .$queryid },
                { label => 'new search', page => 'workflow!search'},
                #{ label => 'bulk edit', action => 'workflow!bulk', select => 'serial' }, # Draft for Bulk Edit
            ]            
        }
    });
    
    return $self;

}


sub init_history {

    my $self = shift;
    my $args = shift;

    my $id = $self->param('wf_id');

    $self->_page({
        label => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_TITLE',
        description => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_DESCRIPTION',
    });

    my $workflow_history = $self->send_command( 'get_workflow_history', { ID => $id } );

    $self->logger()->debug( "dumper result: " . Dumper $workflow_history);

    my $i = 1;
    my @result;
    foreach my $item (@{$workflow_history}) {
        push @result, [
            $item->{'WORKFLOW_HISTORY_DATE'},
            $item->{'WORKFLOW_STATE'},
            $item->{'WORKFLOW_ACTION'},
            $item->{'WORKFLOW_DESCRIPTION'},
            $item->{'WORKFLOW_USER'}
        ]
    }

    $self->logger()->trace( "dumper result: " . Dumper $workflow_history);

    $self->add_section({
        type => 'grid',
        className => 'workflow',
        processing_type => 'all',
        content => {
            columns => [
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_EXEC_TIME_LABEL' }, #, format => 'datetime'},
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_STATE_LABEL' },
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_ACTION_LABEL' },
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_DESCRIPTION_LABEL' },
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_USER_LABEL' },
            ],
            data => \@result,
        },
    });

    # add continue button if workflow is not in a final state
    my $last_state = pop @{$workflow_history};
    if ($last_state->{'WORKFLOW_STATE'} !~ /(SUCCESS|FAILURE)/) {
        $self->add_section({
            type => 'text',
            content => {
                buttons => [{
                    'action' => 'redirect!workflow!load!wf_id!'.$id,
                    'label' => 'I18N_OPENXPKI_UI_WORKFLOW_OPEN_WORKFLOW_LABEL', #'open workflow',
                }]
            }
        });
    }

    return $self;

}


sub init_mine {
    
    my $self = shift;
    my $args = shift;
            
    my $limit = sprintf('%01d', $self->param('limit'));
    my $startat = sprintf('%01d', $self->param('startat')); 
    
    # Safety rule
    if (!$limit) { $limit = 50; }
    elsif ($limit > 500) {  $limit = 500; }

    my $query = {
        ATTRIBUTE => [{ KEY => 'creator', VALUE => $self->_client()->session()->param('user')->{name} }]
    };

    my $search_result = $self->send_command( 'search_workflow_instances', 
        { %{$query}, ( LIMIT => $limit, START => $startat ) } );
    
    # if size of result is equal to limit, check for full result count
    my $result_count = scalar @{$search_result};
    if ($result_count == $limit) {        
        $result_count = $self->send_command( 'search_workflow_instances_count', $query );        
    } 
    
    $self->logger()->trace( "search result: " . Dumper $search_result);

    $self->_page({
        label => 'I18N_OPENXPKI_UI_MY_WORKFLOW_TITLE',
        description => 'I18N_OPENXPKI_UI_MY_WORKFLOW_DESCRIPTION',
    });

    my $i = 1;
    my @result = $self->__render_result_list( $search_result ); 
        
    $self->logger()->trace( "dumper result: " . Dumper @result);

    $self->add_section({
        type => 'grid',
        className => 'workflow',
        processing_type => 'all',
        content => {
            header => 'Grid-Headline',
            actions => [{
                path => 'workflow!load!wf_id!{serial}!view!result',
                label => 'I18N_OPENXPKI_UI_WORKFLOW_OPEN_WORKFLOW_LABEL',
                icon => 'view',
                target => 'tab',
            }],
            columns => [
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SERIAL_LABEL' },
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_UPDATED_LABEL' },
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_TYPE_LABEL' },
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_LABEL' },
                { sTitle => 'serial', bVisible => 0 },
                { sTitle => "_className"},                
            ],
            data => \@result,
            pager => { startat => ($startat*1), limit => ($limit*1), count => ($result_count*1), 
                pagesizes => [25,50,100,250,500], pagersize => 20 }                       
        }
    });

    return $self;
    
}

=head2 action_index

=head3 instance creation

If you pass I<wf_type>, a new workflow instance of this type is created,
the inital action is executed and the resulting state is passed to
__render_from_workflow.

=head3 generic action

The generic action is the default when sending a workflow generated form back
to the server. You need to setup the handler from the rendering step, direct
posting is not allowed. The cgi environment must present the key I<wf_token>
which is a reference to a session based config hash. The config can be created
using __register_wf_token, recognized keys are:

=over

=item wf_fields

An arrayref of fields, that are accepted by the handler. This is usually a copy
of the field list send to the browser but also allows to specify additional
validators. At minimum, each field must be a hashref with the name of the field:

    [{ name => fieldname1 }, { name => fieldname2 }]

Each input field is mapped to the contextvalue of the same name. Keys ending
with empty square brackets C<fieldname[]> are considered to form an array,
keys having curly brackets C<fieldname{subname}> are merged into a hash.
Non scalar values are serialized before they are submitted.

=item wf_action

The name of the workflow action that should be executed with the input
parameters.

=item wf_handler

Can hold the full name of a method which is called to handle the current
request instead of running the generic handler. See the __delegate_call
method for details.

=back

If there are errors, an error message is send back to the browser, if the
workflow execution succeeds, the new workflow state is rendered using
__render_from_workflow.

=cut

sub action_index {

    my $self = shift;
    my $args = shift;

    my $wf_token = $self->param('wf_token') || '';

    my $wf_info;
    # wf_token found, so its a real action
    if (!$wf_token) {
        $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_INVALID_REQUEST_ACTION_WITHOUT_TOKEN!','error');
        return $self;
    }

    my $wf_args = $self->__fetch_wf_token( $wf_token );

    $self->logger()->debug( "wf args: " . Dumper $wf_args);

    # check for delegation
    if ($wf_args->{wf_handler}) {
        return $self->__delegate_call($wf_args->{wf_handler}, $args);
    }


    my %wf_param;

    if ($wf_args->{wf_fields}) {
        my @fields = map { $_->{name} } @{$wf_args->{wf_fields}};
        my $fields = $self->param( \@fields );
        %wf_param = %{ $fields } if ($fields);
        $self->logger()->debug( "wf fields: " . Dumper $fields );
    }

    # take over params from token, if any
    if($wf_args->{wf_param}) {
        %wf_param = (%wf_param, %{$wf_args->{wf_param}});
    }

    # Apply serialization
    foreach my $key (keys %wf_param) {
        $wf_param{$key} = $self->serializer()->serialize($wf_param{$key}) if (ref $wf_param{$key});
    }

    $self->logger()->debug( "wf params: " . Dumper \%wf_param );

    if ($wf_args->{wf_id}) {

        if (!$wf_args->{wf_action}) {
            $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_INVALID_REQUEST_NO_ACTION!','error');
            return $self;
        }

        $self->logger()->info(sprintf "Run %s on workflow #%01d", $wf_args->{wf_action}, $wf_args->{wf_id} );

        # send input data to workflow
        $wf_info = $self->send_command( 'execute_workflow_activity', {
            ID       => $wf_args->{wf_id},
            ACTIVITY => $wf_args->{wf_action},
            PARAMS   => \%wf_param,
            UIINFO => 1
        });

        if (!$wf_info) {
            # todo - handle workflow errors
            $self->logger()->error("workflow acton failed!");
            return $self;
        }
        $self->logger()->trace("wf info after execute: " . Dumper $wf_info );
        $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_WORKFLOW_WAS_UPDATED','success');
        # purge the workflow token
        $self->__purge_wf_token( $wf_token );

    } elsif($wf_args->{wf_type}) {

        $wf_info = $self->send_command( 'create_workflow_instance', {
            WORKFLOW => $wf_args->{wf_type}, PARAMS   => \%wf_param, UIINFO => 1
        });
        if (!$wf_info) {
            # todo - handle workflow errors
            $self->logger()->error("Create workflow failed");
            return $self;
        }
        $self->logger()->trace("wf info on create: " . Dumper $wf_info );

        $self->logger()->info(sprintf "Create new workflow %s, got id %01d",  $wf_args->{wf_type}, $wf_info->{WORKFLOW}->{ID} );

        # purge the workflow token
        $self->__purge_wf_token( $wf_token );

        # always redirect after create to have the url pointing to the created workflow
        # do not redirect for "one shot workflows"
        $wf_args->{redirect} = ($wf_info->{WORKFLOW}->{ID} > 0);

    } else {
        $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_INVALID_REQUEST_NO_ACTION!','error');
        return $self;
    }

    # If we call the token action from within a result list we want
    # to "break out" and set the new url instead rendering the result inline
    if ($wf_args->{redirect}) {
        # Check if we can auto-load the next available action
        my $redirect = 'workflow!load!wf_id!'.$wf_info->{WORKFLOW}->{ID};
        my @activity = keys %{$wf_info->{ACTIVITY}};
        if (scalar @activity == 1) {
            $redirect .= '!wf_action!'.$activity[0];
        }
        $self->redirect($redirect);
        return $self;
    }

    # TODO - we need to refetch the ui info until we change the api
    #$wf_info = $self->send_command( 'get_workflow_info', {
    #    ID => $wf_info->{WORKFLOW}->{ID},
    #    UIINFO => 1
    #});

    # Check if we can auto-load the next available action
    my $wf_action;
    my @activity = keys %{$wf_info->{ACTIVITY}};
    if (scalar @activity == 1) {
        $wf_action = $activity[0];
    }

    $self->__render_from_workflow({ WF_INFO => $wf_info, WF_ACTION => $wf_action });

    return $self;

}

=head2 action_load

Load a workflow given by wf_id, redirects to init_load

=cut

sub action_load {

    my $self = shift;
    my $args = shift;

    $self->redirect('workflow!load!wf_id!'.$self->param('wf_id') );
    return $self;

}

=head2 action_select

Handle requests to states that have more than one action.
Needs to reference an exisiting workflow either via C<wf_token> or C<wf_id> and
the action to choose with C<wf_action>. If the selected action does not require
any input parameters (has no fields) and does not have an ui override set, the
action is executed immediately and the resulting state is used. Otherwise,
the selected action is preset and the current state is passed to the
__render_from_workflow method.

=cut

sub action_select {

    my $self = shift;
    my $args = shift;

    my $wf_action =  $self->param('wf_action');
    $self->logger()->debug('activity select ' . $wf_action);

    # can be either token or id
    my $wf_id = $self->param('wf_id');
    if (!$wf_id) {
        my $wf_token = $self->param('wf_token');
        my $wf_args = $self->__fetch_wf_token( $wf_token );
        $wf_id = $wf_args->{wf_id};
    }

    my $wf_info = $self->send_command( 'get_workflow_info', {
        ID => $wf_id, UIINFO => 1
    });
    $self->logger()->debug('wf_info ' . Dumper  $wf_info);

    if (!$wf_info) {
        $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION','error');
        return $self;
    }

    # If the activity has no fields and no ui class we proceed immediately
    # FIXME - really a good idea - intentional stop items without fields?
    my $wf_action_info = $wf_info->{ACTIVITY}->{$wf_action};
    $self->logger()->trace('wf_action_info ' . Dumper  $wf_action_info);
    if ((!$wf_action_info->{field} || (scalar @{$wf_action_info->{field}}) == 0) &&
        !$wf_action_info->{uihandle}) {

        $self->logger()->debug('activity has no input - execute');

        # send input data to workflow
        $wf_info = $self->send_command( 'execute_workflow_activity', {
            WORKFLOW => $wf_info->{WORKFLOW}->{TYPE},
            ID       => $wf_info->{WORKFLOW}->{ID},
            ACTIVITY => $wf_action,
            UIINFO => 1
        });
 
        my @activity = keys %{$wf_info->{ACTIVITY}};
        if (scalar @activity == 1) {
            $args->{WF_ACTION} = $activity[0];
        }

    } else {
        $args->{WF_ACTION} = $wf_action;
    }

    $args->{WF_INFO} = $wf_info;

    $self->__render_from_workflow( $args );

    return $self;
}

=head2 action_search

Handler for the workflow search dialog, consumes the data from the
search form and displays the matches as a grid.

=cut

sub action_search {


    my $self = shift;
    my $args = shift;

    my $query = { };
    my $input;
    
    if ($self->param('wf_type')) {
        $query->{TYPE} = $self->param('wf_type');
        $input->{wf_type} = $self->param('wf_type');                                
    }
    
    if ($self->param('wf_state')) {
        $query->{STATE} = $self->param('wf_state');
        $input->{wf_state} = $self->param('wf_state');                                
    }
    
    if ($self->param('wf_proc_state')) {
        $query->{PROC_STATE} = $self->param('wf_proc_state');
        $input->{wf_proc_state} = $self->param('wf_proc_state');                                
    }
    
    my @attr;
    if ($self->param('wf_creator')) {
        $input->{wf_creator} = $self->param('wf_creator');
        push @attr, { KEY => 'creator', VALUE => ~~ $self->param('wf_creator') };                         
    }
    
    # Read the query pattern for extra attributes from the session 
    my $attributes = $self->_client->session()->param('wfsearch');        
    foreach my $item (@{$attributes}) {
        my $key = $item->{key};
        my $pattern = $item->{pattern} || '';
        my $operator = $item->{operator} || 'EQUAL';
        my @val = $self->param($key.'[]');
        while (my $val = shift @val) {
            # embed into search pattern from config
            $val = sprintf($pattern, $val) if ($pattern);
            # replace asterisk as wildcard
            $val =~ s/\*/%/g;
            push @attr,  { KEY => $key, VALUE => $val, OPERATOR => uc($operator) };
        }
    }
    
    $query->{ATTRIBUTE} = \@attr;

    $self->logger()->debug("query : " . Dumper $query);
 
    my $result_count = $self->send_command( 'search_workflow_instances_count', $query );
    
    # No results founds
    if (!$result_count) {
        $self->set_status('Your query did not return any matches.','error');
        return $self->init_search({ preset => $input });
    }
    
    my $queryid = $self->__generate_uid();
    $self->_client->session()->param('query_wfl_'.$queryid, {
        'count' => $result_count,
        'query' => $query,
        'input' => $input 
    });
 
    $self->redirect( 'workflow!result!id!'.$queryid  );
    
    return $self;

}

=head1 internal methods

=head2 __render_from_workflow ( { WF_ID, WF_INFO, WF_ACTION }  )

Internal method that renders the ui components from the current workflow state.
The info about the current workflow can be passed as a workflow info hash as
returned by the get_workflow_info api method or simply the workflow
id. In states with multiple action, the WF_ACTION parameter can tell
the method to proceed with this state.

=head3 activity selection

If a state has multiple available activities, and no activity is given via
WF_ACTION, the page includes the content of the description tag of the state
(or the workflow) and a list of buttons rendered from the description of the
available actions. For actions without a description tag, the action name is
used. If a user clicks one of the buttons, the call gets dispatched to the
action_select method.

=head3 activity rendering

If the state has only one available activity or WF_ACTION is given, the method
loads the list of input fields from the workflow definition and renders one
form field per parameter, exisiting context values are filled in.

The type attribute tells how to render the field, accepted basic html types are

    text, hidden, password, textarea, select, checkbox


TODO: stuff below not implemented yet!

For select and checkbox you need to pass suitable options using the source_list
or source_class attribute as described in the Workflow manual.

TODO: Meta definitons, custom config

=head3 custom handler

You can override the default rendering by setting the uihandle attribute either
in the state or in the action defintion. A handler on the state level will
always be called regardless of the internal workflow state, a handler on the
action level gets called only if the action is selected by above means.



=cut
sub __render_from_workflow {

    my $self = shift;
    my $args = shift;

    $self->logger()->debug( "render args: " . Dumper $args);

    my $wf_info = $args->{WF_INFO} || undef;
    my $view = $args->{VIEW} || '';

    if (!$wf_info && $args->{WF_ID}) {
        $wf_info = $self->send_command( 'get_workflow_info', {
            ID => $args->{WF_ID}, UIINFO => 1
        });
        $args->{WF_INFO} = $wf_info;
    }

    $self->logger()->debug( "wf_info: " . Dumper $wf_info);
    if (!$wf_info) {
        $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION','error');
        return $self;
    }

    # delegate handling to custom class
    if ($wf_info->{STATE}->{uihandle}) {
        return $self->__delegate_call($wf_info->{STATE}->{uihandle}, $args);
    }

    my $wf_action;
    if($args->{WF_ACTION}) {
        $wf_action = $args->{WF_ACTION};
        if (!$wf_info->{ACTIVITY}->{$wf_action}) {
            $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_REQUESTED_ACTION_NOT_AVAILABLE','error');
            return $self;
        }
    }

    # Check if the workflow is under control of the watchdog
    if ($wf_info->{WORKFLOW}->{PROC_STATE} && $wf_info->{WORKFLOW}->{PROC_STATE} eq 'pause') { 
        
        my $wf_action = $wf_info->{WORKFLOW}->{CONTEXT}->{wf_current_action};
        my $wf_action_info = $wf_info->{ACTIVITY}->{ $wf_action };

        my $label =  $wf_action_info->{label} || $wf_info->{STATE}->{label} ;
        if ($label) {
            $label .= ' / ' .  $wf_info->{WORKFLOW}->{label};
        } else {
            $label =  $wf_info->{WORKFLOW}->{label} ;
        }
        
        $self->_page({
            label => $label,
            shortlabel => $wf_info->{WORKFLOW}->{ID},
            description =>  $wf_action_info->{description} ,
        });

        $self->add_section({
            type => 'keyvalue',
             content => {
                label => '',
                description => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_WATCHDOG_PAUSED_DESCRIPTION',
                data => [
                    { label => 'I18N_OPENXPKI_UI_WORKFLOW_LAST_UPDATE_LABEL', 
                        value => str2time($wf_info->{WORKFLOW}->{LAST_UPDATE}.' GMT'), 'format' => 'timestamp' },
                    { label => 'I18N_OPENXPKI_UI_WORKFLOW_WAKEUP_AT_LABEL', 
                        value => $wf_info->{WORKFLOW}->{WAKE_UP_AT}, 'format' => 'timestamp' },                    
                    { label => 'I18N_OPENXPKI_UI_WORKFLOW_COUNT_TRY_LABEL', 
                        value => $wf_info->{WORKFLOW}->{COUNT_TRY} },
                    { label => 'I18N_OPENXPKI_UI_WORKFLOW_PAUSE_REASON_LABEL',
                        value => $wf_info->{WORKFLOW}->{CONTEXT}->{wf_pause_msg} },
                ]
        }});

        $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_STATE_WATCHDOG_PAUSED','info');
                
        # this should be available to raop only
        if (0) {
            my @fields;
            push @fields, $self->__register_wf_token( $wf_info, {
                wf_action => $wf_action            
            });
    
            $self->add_section({
                type => 'form',
                action => 'workflow',
                content => {
                    submit_label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_WAKEUP_BUTTON',
                    fields => \@fields
            }});
        }

    # if there is one activity selected (or only one present), we render it now
    } elsif ($wf_action) {
        my $wf_action_info = $wf_info->{ACTIVITY}->{$wf_action};

        # Headline from action or state + Workflow Label, description from action if set
        my $label =  $wf_action_info->{label} || $wf_info->{STATE}->{label} ;
        if ($label) {
            $label .= ' / ' .  $wf_info->{WORKFLOW}->{label} ;
        } else {
            $label =  $wf_info->{WORKFLOW}->{label} ;
        }
        $self->_page({
            label => $label,
            shortlabel => $wf_info->{WORKFLOW}->{ID},
            description =>  $wf_action_info->{description} ,
        });

        # delegation based on activity
        if ($wf_action_info->{uihandle}) {
            return $self->__delegate_call($wf_action_info->{uihandle}, $args, $wf_action);
        }

        $self->logger()->debug('activity info ' . Dumper $wf_action_info );

        # we allow prefill of the form if the workflow is started
        my $do_prefill = $wf_info->{WORKFLOW}->{STATE} eq 'INITIAL';

        my $context = $wf_info->{WORKFLOW}->{CONTEXT};
        my @fields;
        my @fielddesc;
        foreach my $field (@{$wf_action_info->{field}}) {

            my $name = $field->{name};
            next if ($name =~ m{ \A workflow_id }x);
            next if ($name =~ m{ \A wf_ }x);
            next if ($field->{type} && $field->{type} eq "server");

            my $val = $self->param($name);
            if ($do_prefill && defined $val) {
                # XSS prevention - very rude, but if you need to pass something
                # more sophisticated use the wf_token technique
                $val =~ s/[^A-Za-z0-9_=,-\. ]//;
            } elsif (defined $context->{$name}) {
                $val = $context->{$name};
            } else {
                $val = undef;
            }

            my $item = $self->__render_input_field( $field, $val );
            push @fields, $item;

            # if the field has a description text, push it to the @fielddesc list
            if ($field->{description} !~ /^\s*$/) {
                my $descr = $field->{description};
                push @fielddesc, { label => $item->{label}, value => $descr } if ($descr);
            }

        }

        # record the workflow info in the session
        push @fields, $self->__register_wf_token( $wf_info, {
            wf_action => $wf_action,
            wf_fields => \@fields,
        });

        $self->add_section({
            type => 'form',
            action => 'workflow',
            content => {
                #label => $wf_action_info->{label},
                #description => $wf_action_info->{description},
                submit_label => 'I18N_OPENXPKI_UI_WORKFLOW_LABEL_CONTINUE',
                fields => \@fields
        }});

        if (@fielddesc) {
            $self->add_section({
                type => 'keyvalue',
                content => {
                    label => 'I18N_OPENXPKI_UI_WORKFLOW_FIELD_HINT_LIST',
                    description => '',
                    data => \@fielddesc
            }});
        }

    } else {

        # more than one action available, so we offer some buttons to choose how to continue

        # Headline from state + workflow
        my $label =  $wf_info->{STATE}->{label};
        if ($label) {
            $label .= ' / ' .  $wf_info->{WORKFLOW}->{label};
        } else {
            $label =  $wf_info->{WORKFLOW}->{label};
        }

        $self->_page({
            label => $label,
            shortlabel => $wf_info->{WORKFLOW}->{ID},
            description =>  $wf_info->{STATE}->{description},
        });

        my @fields;
        my $context = $wf_info->{WORKFLOW}->{CONTEXT};
        
        # in case we have output format rules, we just show the defined fields
        # can be overriden with view = context
        my $output = $wf_info->{STATE}->{output};
        my @fields_to_render;
        if ($view eq 'context') {
            foreach my $field (sort keys %{$context}) {                              
                push @fields_to_render, { name => $field };
            }
        } elsif ($output) {
            @fields_to_render = @{$wf_info->{STATE}->{output}};
            $self->logger()->debug('Render output rules: ' . Dumper  \@fields_to_render  );                        
        } else {
            foreach my $field (sort keys %{$context}) {                 
                next if ($field =~ m{ \A (wf_|_|workflow_id|sources) }x);
                push @fields_to_render, { name => $field };
            }
            $self->logger()->debug('No output rules, render plain context: ' . Dumper  \@fields_to_render  );            
        }
        
        foreach my $field (@fields_to_render) {
        
            my $key = $field->{name};            
            my $item = { 
                value => ($context->{$key} || ''), 
                type => '', 
                format =>  $field->{format} || ''  
            };
        
            # Always suppress key material
            if ($item->{value} =~ /-----BEGIN[^-]*PRIVATE KEY-----/) {
                $item->{value} = 'I18N_OPENXPKI_UI_WORKFLOW_SENSITIVE_CONTENT_REMOVED_FROM_CONTEXT';                
            }
            
            # Label, Description, Tooltip
            foreach my $prop (qw(label description tooltip)) {
                if ($field->{$prop}) {
                    $item->{$prop} = $field->{$prop};
                }
            }
            
            if (!$item->{label}) {
                $item->{label} = $key;
            }
                 
            # assign autoformat based on some assumptions if no format is set
            if (!$item->{format}) {                
                # create a link on cert_identifier fields
                if ( $key =~ m{ cert_identifier \z }x || 
                    $item->{type} eq 'cert_identifier') {
                
                    $item->{format} = 'cert_identifier';    
                }
                
                # Code format any PEM blocks
                if ( $key =~ m{ \A (pkcs10|pkcs7) \z }x  ||
                    $item->{value} =~ m{ \A -----BEGIN([A-Z ]+)-----.*-----END([A-Z ]+)---- }xms) {
                    $item->{format} = 'code';
                }                
            }

            # convert format cert_identifier into a link             
            if ($item->{format} eq 'cert_identifier') {        
                $item->{format} = 'link';
                $item->{value}  = { label => $item->{value}, page => 'certificate!detail!identifier!'. $item->{value}, target => 'modal' };
            }

            # Auto detect serializes content
            # FIXME - will not work once we change serialization format
            if (ref $item->{value} eq '' && $item->{value} && $item->{value} =~ m{ \A (HASH|ARRAY) }x) {
                $item->{value} = $self->serializer()->deserialize( $context->{$key} );
                if (ref $item->{value} eq 'HASH' && !$item->{format}) {
                    # Sort by label
                    my @val = map { { label => $_, value => $item->{value}->{$_}} } sort keys %{$item->{value}};
                    $item->{value} = \@val; 
                    $item->{format} = 'deflist';
                }
            }

            # todo - i18n labels
            push @fields, $item;
        }

        # Add action buttons only if we are not in result view
        my $buttons;
        $buttons = $self->__get_action_buttons( $wf_info ) if ($view ne 'result');

        $self->add_section({
            type => 'keyvalue',
            content => {
                label => '',
                description => '',
                data => \@fields,
                buttons => $buttons
        }});

        # set status decorator on final states, use proc state
        my $desc = $wf_info->{STATE}->{description};
                
        if ($wf_info->{WORKFLOW}->{PROC_STATE} eq 'finished') {
            # add special colors for success and failure       
            if ( $wf_info->{WORKFLOW}->{STATE} eq 'SUCCESS') {
                $self->set_status( 'I18N_OPENXPKI_UI_WORKFLOW_STATE_SUCCESS','success');
            } elsif ( $wf_info->{WORKFLOW}->{STATE} eq 'FAILURE') {
                $self->set_status( 'I18N_OPENXPKI_UI_WORKFLOW_STATE_FAILURE','error');
            } elsif ( $wf_info->{WORKFLOW}->{STATE} eq 'CANCELED') {
                $self->set_status( 'I18N_OPENXPKI_UI_WORKFLOW_STATE_CANCELED','warn');                
            } else {
                $self->set_status( 'I18N_OPENXPKI_UI_WORKFLOW_STATE_MISC_FINAL','warn');
            }
        } elsif ($wf_info->{WORKFLOW}->{PROC_STATE} eq 'exception') {            
            $self->set_status( 'I18N_OPENXPKI_UI_WORKFLOW_STATE_EXCEPTION','error');
        }

    }
    
    if ($wf_info->{WORKFLOW}->{ID} ) {

        my @buttons;        
        if (($view eq 'result' && $wf_info->{WORKFLOW}->{STATE} !~ /(SUCCESS|FAILURE)/)
            || $view eq 'context') {
            @buttons = ({
                'action' => 'redirect!workflow!load!wf_id!'.$wf_info->{WORKFLOW}->{ID},
                'label' => 'I18N_OPENXPKI_UI_WORKFLOW_OPEN_WORKFLOW_LABEL', #'open workflow',
            });
        }

        if ($view ne 'context') {
            push @buttons, {
                'action' => 'redirect!workflow!load!view!context!wf_id!'.$wf_info->{WORKFLOW}->{ID},
                'label' => 'I18N_OPENXPKI_UI_WORKFLOW_CONTEXT_LABEL',
            };
        }
        
        push @buttons, {
            'action' => 'redirect!workflow!history!wf_id!'.$wf_info->{WORKFLOW}->{ID},
            'label' => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_LABEL',
        };
        

        $self->_result()->{right} = [{
            type => 'keyvalue',
            content => {
                label => '',
                description => '',
                data => [
                # todo - i18n for values
                    { label => 'I18N_OPENXPKI_UI_WORKFLOW_ID_LABEL', value => $wf_info->{WORKFLOW}->{ID} },
                    { label => 'I18N_OPENXPKI_UI_WORKFLOW_TYPE_LABEL', value => $wf_info->{WORKFLOW}->{TYPE} },
                    { label => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_LABEL', value => $wf_info->{WORKFLOW}->{STATE} },
                    { label => 'I18N_OPENXPKI_UI_WORKFLOW_PROC_STATE_LABEL', value => $wf_info->{WORKFLOW}->{PROC_STATE} },
                    { label => 'I18N_OPENXPKI_UI_WORKFLOW_CREATOR_LABEL', value => $wf_info->{WORKFLOW}->{CONTEXT}->{creator} },
                ],
                buttons => \@buttons,
        }}];
    }



    return $self;

}

=head2 __get_action_buttons

For states having multiple actions, this helper renders a set of buttons to
dispatch to the next action. It expects a workflow info structure as single
parameter and returns a ref to a list to be put in the buttons field.

=cut

sub __get_action_buttons {

    my $self = shift;
    my $wf_info = shift;

    # The text hints for the action is encoded in the state
    my $hint = $wf_info->{STATE}->{hint} || {};

    my @buttons;
    foreach my $wf_action (@{$wf_info->{STATE}->{option}}) {
        my $wf_action_info = $wf_info->{ACTIVITY}->{$wf_action};

        my %extra;
        # TODO - we should add some configuration option for this
        if ($wf_action =~ /global_cancel/) {
            $extra{confirm} = {
                label => 'Cancel Request',
                description => 'Press the confirm button to cancel this workflow. 
                This will immediatley stop all actions on this workflow and 
                mark it as canceled. <b>This action can not be undone!</b><br/><br/>  
                If you want to keep this workflow, press the abort button to 
                close this window without touching the workflow.',
            };
        }

       push @buttons, {
            label => $wf_action_info->{label} || $wf_action,
            action => sprintf ('workflow!select!wf_action!%s!wf_id!%01d', $wf_action, $wf_info->{WORKFLOW}->{ID}),
            description => $hint->{$wf_action},
            %extra
        };
    }

    $self->logger()->debug('Buttons are ' . Dumper \@buttons);

    return \@buttons;
}

=head2 __render_input_field

Render the UI code for a input field from the server sided definition.
Does translation of labels and mangles values for multi-valued componentes.

=cut

sub __render_input_field {

    my $self = shift;
    my $field = shift;
    my $value = shift;

    my $name = $field->{name};
    next if ($name =~ m{ \A workflow_id }x);
    next if ($name =~ m{ \A wf_ }x);

    my $type = $field->{type} || 'text';

    # fields to be filled only by server sided workflows
    next if ($type eq "server");

    my $item = {
        name => $name,
        label => $field->{label} || $name,
        type => $type
    };

    $item->{placeholder} = $field->{placeholder} if ($field->{placeholder});
    $item->{tooltip} = $field->{tooltip} if ($field->{tooltip});

    if ($field->{option}) {
        $item->{options} = $field->{option};
        map {  $_->{label} = $_->{label} } @{$item->{options}};
    }

    if ($field->{clonable}) {
        $item->{clonable} = 1;
        $item->{name} .= '[]';
    }

    if (!$field->{required}) {
        $item->{is_optional} = 1;
        $item->{label} .= '*';
    }

    if (defined $value) {
        # clonables need array as value
        if ($item->{clonable}) {
            if (ref $value) {
                $item->{value} = $value;
            } elsif($value =~ /^ARRAY/) {
                my $val = $self->serializer()->deserialize($value);
                # The UI crashes on empty lists
                $item->{value} = $val if (scalar @{$val} && defined $val->[0]);
            } elsif ($value) {
                $item->{value} = [ $value ];
            }
        } else {
            $item->{value} = $value;
        }
    } elsif ($field->{default}) {
        $item->{value} = $field->{default};
    }

    return $item;

}

=head2 __delegate_call

Used to delegate the rendering to another class, requires the method
to dispatch to as string (class + method using the :: notation) and
a ref to the args to be passed. If called from within an action, the
name of the action is passed as additonal parameter.

=cut
sub __delegate_call {

    my $self = shift;
    my $call = shift;
    my $args = shift;
    my $wf_action = shift || '';

    my ($class, $method) = $call =~ /(.+)::([^:]+)/;
    $self->logger()->debug("deletegating render to $class, $method" );
    eval "use $class; 1;";
    $class->$method( $self, $args, $wf_action );
    return $self;

}


=head2 __render_result_list

Helper to render the output result list from a sql query result.
adds exception/paused label to the state column and status class based on
proc and wf state. 

=cut
sub __render_result_list {

    my $self = shift;
    my $search_result = shift;

    $self->logger()->debug("search result " . Dumper $search_result);

    my @result;
    foreach my $item (@{$search_result}) {
        
        # Build state info from watchdog state and process state
        my $state = $item->{'WORKFLOW.WORKFLOW_STATE'}; # TODO - translate
                
        # I18N_OPENXPKI_UI_WORKFLOW_PROC_STATE_EXCEPTION
        # I18N_OPENXPKI_UI_WORKFLOW_PROC_STATE_FINISHED
        # I18N_OPENXPKI_UI_WORKFLOW_PROC_STATE_MANUAL
        # I18N_OPENXPKI_UI_WORKFLOW_PROC_STATE_PAUSE
        if ($item->{'WORKFLOW.WORKFLOW_PROC_STATE'} eq 'exception') {
            
            $state .= " ( I18N_OPENXPKI_UI_WORKFLOW_PROC_STATE_EXCEPTION )";
            
        } elsif ($item->{'WORKFLOW.WORKFLOW_PROC_STATE'} eq 'pause') {
           
           $state .= " ( I18N_OPENXPKI_UI_WORKFLOW_PROC_STATE_PAUSE )";
                  
        }
        
        my $status = $item->{'WORKFLOW.WORKFLOW_PROC_STATE'};        
        # special color for workflows in final failure
        if ($status eq 'finished' && $item->{'WORKFLOW.WORKFLOW_STATE'} eq 'FAILURE') {
            $status  = 'failure';
        }
        
        push @result, [
            $item->{'WORKFLOW.WORKFLOW_SERIAL'},
            $item->{'WORKFLOW.WORKFLOW_LAST_UPDATE'},
            $item->{'WORKFLOW.WORKFLOW_TYPE'}, # todo - translate
            $state,            
            $item->{'WORKFLOW.WORKFLOW_SERIAL'},
            $status,
        ];
    }
    
    return @result;
    
}


=head1 example workflow config

=head2 State with default rendering

    <state name="DATA_LOADED">
        <description>I18N_OPENXPKI_WF_STATE_CHANGE_METADATA_LOADED</description>
        <action name="changemeta_update" resulting_state="DATA_UPDATE"/>
        <action name="changemeta_persist" resulting_state="SUCCESS"/>
    </state>
    ...
    <action name="changemeta_update"
        class="OpenXPKI::Server::Workflow::Activity::Noop"
        description="I18N_OPENXPKI_ACTION_UPDATE_METADATA">
        <field name="metadata_update" />
    </action>
    <action name="changemeta_persist"
        class="OpenXPKI::Server::Workflow::Activity::PersistData">
    </action>

When reached first, a page with the text from the description tag and two
buttons will appear. The update button has I18N_OPENXPKI_ACTION_UPDATE_METADATA
as label an after pushing it, a form with one text field will be rendered.
The persist button has no description and will have the action name
changemeta_persist as label. As it has no input fields, the workflow will go
to the next state without further ui interaction.

=head2 State with custom rendering

    <state name="DATA_LOADED" uihandle="OpenXPKI::Client::UI::Workflow::Metadata::render_current_data">
    ....
    </state>

Regardless of what the rest of the state looks like, as soon as the state is
reached, the render_current_data method is called.


=head2 Action with custom rendering

    <state name="DATA_LOADED">
        <description>I18N_OPENXPKI_WF_STATE_CHANGE_METADATA_LOADED</description>
        <action name="changemeta_update" resulting_state="DATA_UPDATE"/>
        <action name="changemeta_persist" resulting_state="SUCCESS"/>
    </state>

    <action name="changemeta_update"
        class="OpenXPKI::Server::Workflow::Activity::Noop"
        uihandle="OpenXPKI::Client::UI::Workflow::Metadata::render_update_form"
        description="I18N_OPENXPKI_ACTION_UPDATE_METADATA_ACTION">
        <field name="metadata_update"/>
    </action>


While no action is selected, this will behave as the default rendering and show
two buttons. After the changemeta_update button was clicked, it calls the
render_update_form method. Note: The uihandle does not affect the target of
the form submission so you either need to properly setup the environment to
use the default action (see action_index) or set the wf_handler to a custom
method for parsing the form data.

1;
