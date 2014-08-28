# OpenXPKI::Client::UI::Workflow
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Workflow;

use Moose;
use Data::Dumper;
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

    my $wf_info = $self->send_command( 'get_workflow_info', {
        TYPE => $self->param('wf_type'), UIINFO => 1
    });

    if (!$wf_info) {
        $self->set_status(i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION'),'error');
        return $self;
    }

    # Pass the initial activity so we get the form right away
    my $wf_action = (keys %{$wf_info->{ACTIVITY}})[0];

    $self->__render_from_workflow({ WF_INFO => $wf_info, WF_ACTION => $wf_action });
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
        $self->set_status(i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION'),'error') unless($self->_status());
        return $self;
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
        label => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_SEARCH_TITLE'),
        description => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_SEARCH_DESCRIPTION'),
    });

    my $workflows = $self->send_command( 'list_workflow_titles' );
    return $self unless(defined $workflows);

    # TODO Sorting / I18
    my @wf_names = keys %{$workflows};
    my @wfl_list = map { $_ = {'value' => $_, 'label' => i18nGettext($workflows->{$_}->{label})} } @wf_names ;
    @wfl_list = sort { lc($a->{'label'}) cmp lc($b->{'label'}) } @wfl_list;

    my @states = (
        { label => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_SEARCH_STATE_SUCCESS_LABEL'), value => 'SUCCESS' },
        { label => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_SEARCH_STATE_FAILURE_LABEL'), value => 'FAILURE' },
        { label => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_SEARCH_STATE_PENDING_LABEL'), value => 'PENDING' },
        { label => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_SEARCH_STATE_APPROVAL_LABEL'), value => 'APPROVAL' },
    );
    @states = sort { lc($a->{'label'}) cmp lc($b->{'label'}) } @states;

    $self->_result()->{main} = [
        {   type => 'form',
            action => 'workflow!load',
            content => {
                title => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SEARCH_BY_ID_TITLE'),
                submit_label => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SUBMIT_LABEL'),
                fields => [
                    { name => 'wf_id', label => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_SEARCH_WORKFLOW_ID_LABEL'), type => 'text' },
                ]
        }},
        {   type => 'form',
            action => 'workflow!search',
            content => {
                title => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SEARCH_DATABASE_TITLE'),
                submit_label => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SUBMIT_LABEL'),
                fields => [
                    { name => 'wf_type',
                      label => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_SEARCH_TYPE_LABEL'), 
                      type => 'select',
                      is_optional => 1,
                      options => \@wfl_list 
                    },
                    { name => 'wf_state',
                      label => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_SEARCH_STATE_LABEL'), #'State',
                      type => 'select',
                      is_optional => 1,
                      editable => 0,
                      prompt => '',
                      options => \@states
                    },
                    { name => 'wf_creator',
                      label => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_SEARCH_CREATOR_LABEL'), # 'Creator',
                      type => 'text',
                      is_optional => 1
                    },
                ]
        }}
    ];

    return $self;
}

sub init_history {

    my $self = shift;
    my $args = shift;

    my $id = $self->param('wf_id');

    $self->_page({
        label => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_HISTORY_TITLE'),
        description => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_HISTORY_DESCRIPTION'),
    });

    my $workflow_history = $self->send_command( 'get_workflow_history', { ID => $id } );

    $self->logger()->debug( "dumper result: " . Dumper $workflow_history);

    my $i = 1;
    my @result;
    foreach my $item (@{$workflow_history}) {
        push @result, [
            $item->{'WORKFLOW_HISTORY_DATE'},
            i18nGettext($item->{'WORKFLOW_STATE'}),
            i18nGettext($item->{'WORKFLOW_ACTION'}),
            i18nGettext($item->{'WORKFLOW_DESCRIPTION'}),
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
                { sTitle => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_HISTORY_EXEC_TIME_LABEL') }, #, format => 'datetime'},
                { sTitle => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_HISTORY_STATE_LABEL') },
                { sTitle => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_HISTORY_ACTION_LABEL') },
                { sTitle => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_HISTORY_DESCRIPTION_LABEL') },
                { sTitle => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_HISTORY_USER_LABEL') },
            ],
            data => \@result
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
        $self->set_status(i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_INVALID_REQUEST_ACTION_WITHOUT_TOKEN!'),'error');
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
            $self->set_status(i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_INVALID_REQUEST_NO_ACTION!'),'error');
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
        $self->set_status(i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_WORKFLOW_WAS_UPDATED'),'success');
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
        $wf_args->{redirect} = 1;

    } else {
        $self->set_status(i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_INVALID_REQUEST_NO_ACTION!'),'error');
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
        $self->set_status(i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION'),'error');
        return $self;
    }

    # If the activity has no fields and no ui class we proceed immediately
    # FIXME - really a good idea - intentional stop items without fields?
    my $wf_action_info = $wf_info->{ACTIVITY}->{$wf_action};
    $self->logger()->trace('wf_action_info ' . Dumper  $wf_action_info);
    if ((!$wf_action_info->{FIELD} || (scalar @{$wf_action_info->{FIELD}}) == 0) &&
        !$wf_action_info->{UIHANDLE}) {

        $self->logger()->debug('activity has no input - execute');

        # send input data to workflow
        $wf_info = $self->send_command( 'execute_workflow_activity', {
            WORKFLOW => $wf_info->{WORKFLOW}->{TYPE},
            ID       => $wf_info->{WORKFLOW}->{ID},
            ACTIVITY => $wf_action,
            UIINFO => 1
        });

        # in case we need access to volatile context values we store them away
        # and merge them back later - this can be removed after refactoring the API
        #my $org_context = $wf_info->{WORKFLOW}->{CONTEXT};

        # TODO - change API
        #$wf_info = $self->send_command( 'get_workflow_ui_info', {
        #    ID => $wf_id
        #});

        # Merge back the private context values
        #foreach my $key (keys %{$org_context}) {
        #    if ($key =~ /^_/) {
        #        $wf_info->{WORKFLOW}->{CONTEXT}->{$key} = $org_context->{$key};
        #    }
        #}

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
        label => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_SEARCH_RESULTS_TITLE'),
        description => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_SEARCH_RESULTS_DESCRIPTION'),
    });

    my $i = 1;
    my @result;
    foreach my $item (@{$search_result}) {
        push @result, [
            $item->{'WORKFLOW.WORKFLOW_SERIAL'},
            $item->{'WORKFLOW.WORKFLOW_LAST_UPDATE'},
            i18nGettext($item->{'WORKFLOW.WORKFLOW_TYPE'}),
            i18nGettext($item->{'WORKFLOW.WORKFLOW_STATE'}),
            i18nGettext($item->{'WORKFLOW.WORKFLOW_PROC_STATE'}),
            $item->{'WORKFLOW.WORKFLOW_WAKEUP_AT'},
            $item->{'WORKFLOW.WORKFLOW_SERIAL'},
        ];
    }

    $self->logger()->trace( "dumper result: " . Dumper @result);

    $self->add_section({
        type => 'grid',
        className => 'workflow',
        processing_type => 'all',
        content => {
            header => 'Grid-Headline',
            actions => [{
                path => 'workflow!load!wf_id!{serial}!view!result',
                label => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_OPEN_WORKFLOW_LABEL'),
                icon => 'view',
                target => 'tab',
            }],
            columns => [
                { sTitle => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SERIAL_LABEL') },
                { sTitle => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_SEARCH_UPDATED_LABEL') },
                { sTitle => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_TYPE_LABEL') },
                { sTitle => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_STATE_LABEL') },
                { sTitle => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_PROC_STATE_LABEL') },
                { sTitle => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_WAKE_UP_LABEL'), format => 'timestamp' },
                { sTitle => 'serial', bVisible => 0 },
            ],
            data => \@result
        }
    });

    $self->redirect( $self->__persist_response( undef ) );
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
        $wf_info = $self->send_command( 'get_workflow_info', {
            ID => $args->{WF_ID}, UIINFO => 1
        });
        $args->{WF_INFO} = $wf_info;
    }

    $self->logger()->debug( "wf_info: " . Dumper $wf_info);
    if (!$wf_info) {
        $self->set_status(i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION'),'error');
        return $self;
    }

    # delegate handling to custom class
    if ($wf_info->{STATE}->{uihandle}) {
        return $self->__delegate_call($wf_info->{STATE}->{uihandle}, $args);
    }

    my @activities = keys %{$wf_info->{ACTIVITY}};

    my $wf_action;

    #if (scalar @activities == 1) {
    #    $wf_action = $activities[0];
    #} els
    if($args->{WF_ACTION}) {
        $wf_action = $args->{WF_ACTION};
        if (!$wf_info->{ACTIVITY}->{$wf_action}) {
            $self->set_status(i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_REQUESTED_ACTION_NOT_AVAILABLE'),'error');
            return $self;
        }
    }

    $self->_page({
        label => i18nGettext($wf_info->{WORKFLOW}->{label} || $wf_info->{WORKFLOW}->{TYPE}),
        shortlabel => i18nGettext($wf_info->{WORKFLOW}->{ID}),
        description => i18nGettext($wf_info->{STATE}->{description} || $wf_info->{WORKFLOW}->{description}),
    });

    # if there is one activity selected (or only one present), we render it now
    if ($wf_action) {
        my $wf_action_info = $wf_info->{ACTIVITY}->{$wf_action};
        # delegation based on activity
        if ($wf_action_info->{uihandle}) {
            return $self->__delegate_call($wf_action_info->{uihandle}, $args, $wf_action);
        }

        $self->logger()->debug('activity info ' . Dumper $wf_action_info );

        # we allow prefill of the form if the workflow is started
        my $do_prefill = !defined $wf_info->{WORKFLOW}->{STATE};

        my $context = $wf_info->{WORKFLOW}->{CONTEXT};
        my @fields;
        foreach my $field (@{$wf_action_info->{field}}) {

            my $name = $field->{name};
            next if ($name =~ m{ \A workflow_id }x);
            next if ($name =~ m{ \A wf_ }x);
            # _ fields are volatile but not hidden (e.g. password input)
            #next if ($name =~ m{ \A _ }x);

            my $type = $field->{type} || 'text';

            # fields to be filled only by server sided workflows
            next if ($type eq "server");

            my $item = {
                name => $name,
                label => i18nGettext($field->{label}) || $name,
                type => $type
            };

            $item->{placeholder} = $field->{placeholder} if ($field->{placeholder});
            $item->{tooltip} = $field->{tooltip} if ($field->{tooltip});

            $item->{options} = $field->{options} if ($field->{options});
            if ($field->{clonable}) {
                $item->{clonable} = 1;
                $item->{name} .= '[]';
            }

            my $val = $self->param($name);
            if ($do_prefill && defined $val) {
                # XSS prevention - very rude, but if you need to pass something
                # more sophisticated use the wf_token technique
                $val =~ s/[^A-Za-z0-9_=,-\. ]//;
                $item->{value} = $val;
            } elsif (defined $context->{$name}) {
                # clonables need array as value
                if ($item->{clonable}) {
                    if (ref $context->{$name}) {
                        $item->{value} = $context->{$name};
                    } elsif($context->{$name} =~ /^ARRAY/) {
                        $item->{value} = $self->serializer()->deserialize($context->{$name});
                    } else {
                        $item->{value} = [ $context->{$name} ];
                    }
                } else {
                    $item->{value} = $context->{$name};
                }
            } elsif ($field->{default}) {
                $item->{value} = $field->{default};
            }

            if (!$field->{required}) {
                $item->{is_optional} = 1;
            }

            push @fields, $item;

        }

        # record the workflow info in the session
        push @fields, $self->__register_wf_token( $wf_info, {
            wf_action => $wf_action,
            wf_fields => \@fields,
        });

        $self->_result()->{main} = [{
            type => 'form',
            action => 'workflow',
            content => {
                label => $wf_action_info->{label},
                description => $wf_action_info->{description},
                submit_label => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_LABEL_CONTINUE'),
                fields => \@fields
            }},
        ];
    } else {

        # more than one action available, so we offer some buttons to choose how to continue

        my @fields;
        my $context = $wf_info->{WORKFLOW}->{CONTEXT};
        foreach my $key (sort keys %{$context}) {
            next if ($key =~ m{ \A wf_ }x);
            next if ($key =~ m{ \A _ }x);
            next if ($key =~ m{ \A workflow_id }x);
            next if ($key =~ m{ \A sources }x);

            my $item = { label => $key, value => $context->{$key} };

            # create a link on cert_identifier fields
            if ( $key =~ m{ cert_identifier \z }x) {
                $item->{format} = 'link';
                $item->{value}  = { label => $context->{$key}, page => 'certificate!info!identifier!'. $context->{$key}, target => 'modal' };
            }

            # Code format any PEM blocks
            if ( $key =~ m{ (pkcs10) }x) {
                $item->{format} = 'code';
            }


            # FIXME - will not work once we change serialization format
            if (ref $item->{value} eq '' &&  $item->{value} =~ m{ \A (HASH|ARRAY) }x) {
                $item->{value} = $self->serializer()->deserialize( $context->{$key} );
                if (ref $item->{value} eq 'HASH') {
                    $item->{format} = 'deflist';
                }
            }

            # todo - i18n labels
            push @fields, $item;
        }

        # Add action buttons only if we are not in result view
        my $buttons;
        $buttons = $self->__get_action_buttons( $wf_info ) if (!$args->{VIEW} || $args->{VIEW} ne 'result');

        my @section = {
            type => 'keyvalue',
            content => {
                label => '',
                description => '',
                data => \@fields,
                buttons => $buttons
        }};

        $self->_result()->{main} = \@section;

        # set status decorator on final states
        my $desc = $wf_info->{STATE}->{description};
        if ( $wf_info->{WORKFLOW}->{STATE} eq 'SUCCESS') {
            $self->set_status( i18nGettext($desc || 'I18N_OPENXPKI_UI_WORKFLOW_STATE_SUCCESS'),'success');
        } elsif ( $wf_info->{WORKFLOW}->{STATE} eq 'FAILURE') {
            $self->set_status( i18nGettext($desc || 'I18N_OPENXPKI_UI_WORKFLOW_STATE_FAILURE'),'error');
        } elsif ( $wf_info->{WORKFLOW}->{PROC_STATE} eq 'pause') {
            $self->set_status(i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_STATE_WATCHDOG_PAUSED'),'warning');
        }

    }
    if ($wf_info->{WORKFLOW}->{ID} ) {

        my @buttons;
        if ($args->{VIEW} && $args->{VIEW} eq 'result' && $wf_info->{WORKFLOW}->{STATE} !~ /(SUCCESS|FAILURE)/) {
            @buttons = ({
                'action' => 'redirect!workflow!load!wf_id!'.$wf_info->{WORKFLOW}->{ID},
                'label' => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_OPEN_WORKFLOW_LABEL'), #'open workflow',
            });
        }

        push @buttons, {
            'action' => 'redirect!workflow!history!wf_id!'.$wf_info->{WORKFLOW}->{ID},
            'label' => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_HISTORY_LABEL'),
        };

        $self->_result()->{right} = [{
            type => 'keyvalue',
            content => {
                label => '',
                description => '',
                data => [
                    { label => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_ID_LABEL'), value => $wf_info->{WORKFLOW}->{ID} },
                    { label => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_STATE_LABEL'), value => $wf_info->{WORKFLOW}->{STATE} },
                    { label => i18nGettext('I18N_OPENXPKI_UI_WORKFLOW_PROC_STATE_LABEL'), value => $wf_info->{WORKFLOW}->{PROC_STATE} }
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