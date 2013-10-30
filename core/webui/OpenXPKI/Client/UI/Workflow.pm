# OpenXPKI::Client::UI::Workflow
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Workflow;

use Moose; 
use Data::Dumper;
use Digest::SHA1 qw(sha1_base64);
use OpenXPKI::i18n qw( i18nGettext );

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
     
    my $wf_info = $self->send_command( 'get_workflow_ui_info', {
        WORKFLOW => $self->param('wf_type') 
    }); 
    
    if (!$wf_info) {
        $self->set_status(i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION'),'error');
        return $self;
    }
        
    $self->_page({
        label => i18nGettext($wf_info->{WORKFLOW}->{TYPE}),
        description => i18nGettext($wf_info->{WORKFLOW}->{DESCRIPTION}),
    });
    
    $self->_result()->{main} = [{   
        type => 'form',
        action => 'workflow',
        content => {           
        submit_label => 'start',
            fields => [ { type => 'hidden', 'name' => 'wf_type', value => $self->param('wf_type') } ]
        }}
    ];
    
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
    
    my $wf_info = $self->send_command( 'get_workflow_ui_info', {
        ID => $id 
    }); 
    
    if (!$wf_info) {        
        $self->set_status(i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION'),'error') unless($self->_status());
        return $self;
    }
    
    $self->__render_from_workflow({ WF_INFO => $wf_info });
     
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
        label => 'Workflow Search',
        description => 'You can search for workflows here.',
    });
    
    my $workflows = $self->send_command( 'list_workflow_titles' );
    return $self unless(defined $workflows);
    
    # TODO Sorting / I18
    my @wf_names = keys %{$workflows};
    @wf_names = sort @wf_names;
    
    my @wfl_list = map { $_ = {'value' => $_, 'label' => $workflows->{$_}->{label}} } @wf_names ;
    
    my @states = (
        { label => 'SUCCESS', value => 'SUCCESS' },
        { label => 'FAILURE', value => 'FAILURE' },
        { label => 'PENDING', value => 'PENDING' },
        { label => 'APPROVAL', value => 'APPROVAL' },
    );
    
    $self->_result()->{main} = [  
        {   type => 'form',
            action => 'workflow!load',
            content => {
                title => 'Get workflow info by known workflow id',
                submit_label => 'search now',
                fields => [                    
                    { name => 'wf_id', label => 'Workflow Id', type => 'text', is_optional => 1 },                                       
                ]
        }},      
        {   type => 'form',
            action => 'workflow!search',
            content => {
                title => 'Search the database',
                submit_label => 'search now',
                fields => [                    
                    { name => 'wf_type', label => 'Type', type => 'select', is_optional => 1, prompt => ' ', options => \@wfl_list  },
                    { name => 'wf_state', label => 'State', type => 'select', is_optional => 1, freetext => 'other', options => \@states },                    
                    { name => 'wf_creator', label => 'Creator', type => 'text', is_optional => 1 },                    
                ]
        }}  
    ];
        
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
    if ($wf_token) {
    
        my $wf_args = $self->__fetch_wf_token( $wf_token );
            
        $self->logger()->debug( "wf args: " . Dumper $wf_args);
        
        # check for delegation
        if ($wf_args->{wf_handler}) {
            return $self->__delegate_call($wf_args->{wf_handler}, $args);
        }
        
        if (!$wf_args->{wf_action}) {           
            $self->set_status(i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_INVALID_REQUEST_NO_ACTION!'),'error');
            return $self;
        }
        
        my %wf_param;
        # Get the list of accepted fields and try to fetch the data from cgi
        my @fields = @{$wf_args->{wf_fields}};
        foreach my $field (@fields) {
            my $name = $field->{name};            
            # strip internal fields (start with wf_)
            next if ($name =~ m{ \A wf_ }xms);            
            # TODO - validation
            my $val = $self->param($name);
            # autodetection of array and hashes
            if ($name =~ m{ \A (\w+)\[\] }xms) {
                push @{$wf_param{$1}}, $val; 
            } elsif ($name =~ m{ \A (\w+){(\w+)} }xms) {
                $wf_param{$1}->{$2} = $val;
            } else {          
                $wf_param{$name} = $val;
            }
        }
        
        # purge the workflow token
        $self->__purge_wf_token( $wf_token );
        
        # Apply serialization        
        foreach my $key (keys %wf_param) {            
            $wf_param{$key} = $self->serializer()->serialize($wf_param{$key}) if (ref $wf_param{$key});                        
        }

        $self->logger()->debug( "wf params: " . Dumper %wf_param );
           
        # send input data to workflow                
        $wf_info = $self->send_command( 'execute_workflow_activity', {
            WORKFLOW => $wf_args->{wf_type}, 
            ID       => $wf_args->{wf_id},
            ACTIVITY => $wf_args->{wf_action},
            PARAMS   => \%wf_param,
        }); 
        
        $self->set_status(i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_WORKFLOW_WAS_UPDATED'),'success');
        
        
    # no token, might be an initial request
    } elsif(my $wf_type = $self->param('wf_type')) {
                
        $wf_info = $self->send_command( 'create_workflow_instance', {
            WORKFLOW => $wf_type, 
        }); 
    }   
    
    # TODO - we need to fetch the ui info until we change the api 
    $wf_info = $self->send_command( 'get_workflow_ui_info', {
        ID => $wf_info->{WORKFLOW}->{ID},
        WORKFLOW => $wf_info->{WORKFLOW}->{TYPE} 
    });
    $self->__render_from_workflow({ WF_INFO => $wf_info });
    
          
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
    
    my $wf_info = $self->send_command( 'get_workflow_ui_info', {
        ID => $wf_id 
    }); 
    
    if (!$wf_info) {
        $self->set_status(i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION'),'error');
        return $self;
    }
    
    # If the activity has no fields and no ui class we proceed immediately
    my $wf_action_info = $wf_info->{ACTIVITY}->{$wf_action};   
    if ((!$wf_action_info->{FIELD} || (scalar keys %{$wf_action_info->{FIELD}}) == 0) &&
        !$wf_action_info->{UIHANDLE}) {
    
        $self->logger()->debug('activity has no input - execute');
        
        # send input data to workflow                
        $wf_info = $self->send_command( 'execute_workflow_activity', {
            WORKFLOW => $wf_info->{WORKFLOW}->{TYPE},
            ID       => $wf_info->{WORKFLOW}->{ID},
            ACTIVITY => $wf_action,            
        });
        # TODO - change API
        $wf_info = $self->send_command( 'get_workflow_ui_info', {
            ID => $wf_id 
        });      
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
    
    my $query = { LIMIT => 100 }; # Safety barrier
    foreach my $key (qw(type state)) {
        my $val = $self->param("wf_$key");    
        if (defined $val && $val ne '') {
            $query->{uc($key)} = $val;     
        }
    }
    
    # creator via context (urgh... - needs change)
    if ($self->param('wf_creator')) {
        $query->{CONTEXT} = [{ KEY => 'creator', VALUE => ~~ $self->param('wf_creator') }];
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
            actions => [{   
                path => 'workflow!load!wf_id!{serial}',
                label => 'Open Workflow',
                icon => 'view',
                target => 'tab',
            }],            
            columns => [                        
                { sTitle => "serial" },
                { sTitle => "updated" },
                { sTitle => "type"},
                { sTitle => "state"},
                { sTitle => "procstate"},
                { sTitle => "wake up", format => 'timestamp' },                                
            ],
            data => \@result            
        }
    });
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
    
    my $wf_info = $args->{WF_INFO} || undef;

    if (!$wf_info && $args->{WF_ID}) {
        $wf_info = $self->send_command( 'get_workflow_ui_info', {
            ID => $args->{WF_ID}, 
        }); 
        $args->{WF_INFO} = $wf_info;
    }
    
    $self->logger()->debug( "wf_info: " . Dumper $wf_info);
    if (!$wf_info) {
        $self->set_status(i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION'),'error');
        return $self;
    }
    
    # delegate handling to custom class
    if ($wf_info->{STATE}->{UIHANDLE}) {
        return $self->__delegate_call($wf_info->{STATE}->{UIHANDLE}, $args);
    }
    
    my @activities = keys %{$wf_info->{ACTIVITY}};
    
    my $wf_action;
    
    if (scalar @activities == 1) {
        $wf_action = $activities[0];
    } elsif($args->{WF_ACTION}) {
        $wf_action = $args->{WF_ACTION};                
        if (!$wf_info->{ACTIVITY}->{$wf_action}) {
            $self->set_status(i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_REQUESTED_ACTION_NOT_AVAILABLE'),'error');
            return $self;            
        }        
    }
    
    # if there is one activity selected (or only one present), we render it now
    if ($wf_action) {
        my $wf_action_info = $wf_info->{ACTIVITY}->{$wf_action};
        # delegation based on activity
        if ($wf_action_info->{UIHANDLE}) {
            return $self->__delegate_call($wf_action_info->{UIHANDLE}, $args);            
        }
        
        $self->logger()->debug('activity info ' . Dumper $wf_action_info );
     
        # we allow prefill of the from if the workflow is in the initial state
        my $do_prefill = $wf_info->{WORKFLOW}->{STATE} eq 'INITIALIZED';
     
     
        my $context = $wf_info->{WORKFLOW}->{CONTEXT};
        my @fields;
        foreach my $field (keys %{$wf_action_info->{FIELD}}) {
            
            next if ($field =~ m{ \A workflow_id }x);
            next if ($field =~ m{ \A wf_ }x);
            next if ($field =~ m{ \A _ }x);     
            
            my $type = $wf_action_info->{FIELD}->{$field}->{TYPE} || 'text';
            
            # special handling of workflows internal default type
            $type = 'text' if ($type eq 'basic');
            
            # TODO - map field types, required, etc            
            
            my $item = {
                name => $field, 
                label => i18nGettext($field), 
                type => $type
            };
            if ($do_prefill && defined $self->param($field)) {
                # TODO - XSS Checks / Escaping / Validation!
                $item->{value} = $self->param($field);
            } elsif (defined $context->{$field}) {
                $item->{value} = $context->{$field};
            }
            
            if ($wf_action_info->{FIELD}->{$field}->{REQUIRED} ne 'yes') {
                $item->{is_optional} = 1;
            }
            
            push @fields, $item;    
           
        }
        
        # record the workflow info in the session
        push @fields, $self->__register_wf_token( $wf_info, {
            wf_action => $wf_action,             
            wf_fields => \@fields,
        });
        
        $self->_page({
            label => i18nGettext($wf_info->{WORKFLOW}->{TYPE}),
            shortlabel => i18nGettext($wf_info->{WORKFLOW}->{ID}),
            description => i18nGettext($wf_info->{STATE}->{DESCRIPTION} || $wf_info->{WORKFLOW}->{DESCRIPTION}),
        });
        
        $self->_result()->{main} = [{   
            type => 'form',
            action => 'workflow',
            content => {           
            submit_label => i18nGettext($wf_action_info->{LABEL} || 'I18N_OPENXPKI_UI_WORKFLOW_LABEL_CONTINUE'),
                fields => \@fields
            }},
        ];
    } else {
        
        # more than one action available, so we offer some buttons to choose how to continue
        
         $self->_page({
            label => i18nGettext($wf_info->{WORKFLOW}->{TYPE}),
            shortlabel => i18nGettext($wf_info->{WORKFLOW}->{ID}),
            description => i18nGettext($wf_info->{STATE}->{DESCRIPTION} || $wf_info->{WORKFLOW}->{DESCRIPTION}),
        });
        
        my @fields;
        my $context = $wf_info->{WORKFLOW}->{CONTEXT};
        foreach my $key (keys %{$context}) {
            next if ($key =~ m{ \A workflow_id }x);
            next if ($key =~ m{ \A wf_ }x);
            next if ($key =~ m{ \A _ }x);
            # todo - i18n labels            
            push @fields, { label => $key, value => $context->{$key} };
        }
        
        my @section = {
            type => 'keyvalue',
            content => {
                label => '',
                description => '',
                data => \@fields,
                buttons => $self->__get_action_buttons( $wf_info )
        }};           
        
        $self->_result()->{main} = \@section;
        
        # set status decorator on final states
        my $desc = $wf_info->{STATE}->{DESCRIPTION};
        if ( $wf_info->{WORKFLOW}->{STATE} eq 'SUCCESS') {
            $self->set_status( i18nGettext($desc || 'I18N_OPENXPKI_UI_WORKFLOW_STATE_SUCCESS'),'success');
        } elsif ( $wf_info->{WORKFLOW}->{STATE} eq 'SUCCESS') { 
            $self->set_status( i18nGettext($desc || 'I18N_OPENXPKI_UI_WORKFLOW_STATE_FAILURE'),'error');
        } elsif ( $wf_info->{WORKFLOW}->{PROC_STATE} eq 'pause') {
            $self->set_status(i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_STATE_WATCHDOG_PAUSED'),'warning');             
        }
        
    }
        
    unshift @{$self->_result()->{main}}, {   
        type => 'keyvalue',
        content => {
            label => '',
            description => '',
            data => [
                { label => 'Workflow Id', value => $wf_info->{WORKFLOW}->{ID} },
                { label => 'Workflow State', value => $wf_info->{WORKFLOW}->{STATE} },
                { label => 'Run State', value => $wf_info->{WORKFLOW}->{PROC_STATE} },                
            ],
    }};           
    
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
     
    my @buttons;
    foreach my $wf_action (keys %{$wf_info->{ACTIVITY}}) {
       my $wf_action_info = $wf_info->{ACTIVITY}->{$wf_action};            
       push @buttons, {   
            label => i18nGettext($wf_action_info->{LABEL} || $wf_action),
            action => sprintf 'workflow!select!wf_action!%s!wf_id!%01d', $wf_action, $wf_info->{WORKFLOW}->{ID},            
        };
    }
                
    return \@buttons;
}

=head2 __delegate_call

Used to delegate the rendering to another class, requires the method
to dispatch to as string (class + method using the :: notation) and 
a ref to the args to be passed.

=cut
sub __delegate_call {
        
    my $self = shift;
    my $call = shift;
    my $args = shift;
    
    my ($class, $method) = $call =~ /(.+)::([^:]+)/;
    $self->logger()->debug("deletegating render to $class, $method" );
    eval "use $class;1";
    return $class->$method( $self, $args );
    
}

=head2 __register_wf_token( wf_info, token ) 

Generates a new random id and stores the passed workflow info, expects
a wf_info hash and the token info to store as parameter, returns a hashref
with the definiton of a hidden field which can be directly
pushed onto the field list.

=cut
sub __register_wf_token {
    
    my $self = shift;
    my $wf_info = shift;
    my $token = shift;

    $token->{wf_id} = $wf_info->{WORKFLOW}->{ID};
    $token->{wf_type} = $wf_info->{WORKFLOW}->{TYPE};
    $token->{wf_last_update} = $wf_info->{WORKFLOW}->{LAST_UPDATE};

    # poor mans random id  
    my $id = sha1_base64(time.$token.rand().$$);  
    $id = 'wfl_12345';      
    $self->logger()->debug('wf token id ' . $id);        
    $self->_client->session()->param($id, $token);
    return { name => 'wf_token', type => 'hidden', value => $id };            
}
    
=head2 __fetch_wf_token( wf_token, purge )

Return the hashref stored by __register_wf_token for the given
token id. If purge is set to a true value, the info is purged
from the session context.

=cut
sub __fetch_wf_token {
    
    my $self = shift;
    my $id = shift;
    my $purge = shift || 0;

    $self->logger()->debug( "load wf_token " . $id );
        
    my $token = $self->_client->session()->param($id);
    $self->_client->session()->clear($id) if($purge);
    return $token;
    
}

=head2 __purge_wf_token( wf_token )

Purge the token info from the session.
 
=cut 
sub __purge_wf_token {
    
    my $self = shift;    
    my $id = shift;
    
    $self->logger()->debug( "purge wf_token " . $id );
    $self->_client->session()->clear($id);
    
    return $self;
    
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