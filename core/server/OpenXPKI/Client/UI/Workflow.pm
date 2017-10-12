# OpenXPKI::Client::UI::Workflow
# Written 2013 by Oliver Welter
# (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Client::UI::Workflow;

use Moose;
use Data::Dumper;
use Date::Parse;

has __default_grid_head => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy => 1,

    default => sub { return [
        { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SERIAL_LABEL', sortkey => 'WORKFLOW.WORKFLOW_SERIAL' },
        { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_UPDATED_LABEL', sortkey => 'WORKFLOW.WORKFLOW_LAST_UPDATE' },
        { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_TYPE_LABEL', sortkey => 'WORKFLOW.WORKFLOW_TYPE'},
        { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_LABEL', sortkey => 'WORKFLOW.WORKFLOW_STATE' },
        { sTitle => 'serial', bVisible => 0 },
        { sTitle => "_className"},
    ]; }
);

has __default_grid_row => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy => 1,
    default => sub { return [
        { source => 'workflow', field => 'WORKFLOW_SERIAL' },
        { source => 'workflow', field => 'WORKFLOW_LAST_UPDATE' },
        { source => 'workflow', field => 'WORKFLOW_TYPE' },
        { source => 'workflow', field => 'WORKFLOW_STATE' },
        { source => 'workflow', field => 'WORKFLOW_SERIAL' }
    ]; }
);

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
    my $id = $self->param('wf_id') || 0;
    $id =~ s/[^\d]//g;

    my $wf_action = $self->param('wf_action') || '';
    my $view = $self->param('view') || '';

    my $wf_info = $self->send_command( 'get_workflow_info', {
        ID => $id,
        UIINFO => 1,
    });

    if (!$wf_info) {
        $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION','error') unless($self->_status());
        return $self->init_search({ preset => { wf_id => $id } });
    }

    # Set single action if no special view is requested and only single action is avail
    if (!$view && !$wf_action && $wf_info->{WORKFLOW}->{PROC_STATE} eq 'manual' &&
        (ref $wf_info->{STATE}->{output} ne 'ARRAY' || scalar(@{$wf_info->{STATE}->{output}}) == 0)) {
        my @activities = @{$wf_info->{STATE}->{option}};

        # Do not count global_cancel as alternative selection
        if (scalar @activities == 1 || (scalar @activities == 2 && (grep /global_cancel/, @activities))) {
            $wf_action = $activities[0];
            $self->logger()->debug('Autoselect action ' . $wf_action );
        }
    }

    $self->__render_from_workflow({ WF_INFO => $wf_info, WF_ACTION => $wf_action, VIEW => $view });

    return $self;

}

=head2 init_context

Requires parameter I<wf_id> which is the id of an existing workflow.
Shows the context as plain key/value pairs - usually called in a modal.

=cut

sub init_context {

    my $self = shift;

    # re-instance existing workflow
    my $id = $self->param('wf_id');

    my $wf_info = $self->send_command( 'get_workflow_info', {
        ID => $id,
    });

    if (!$wf_info) {
        $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION','error') unless($self->_status());
        return $self;
    }

    $self->_page({
        label => 'I18N_OPENXPKI_UI_WORKFLOW_CONTEXT_LABEL #' . $wf_info->{WORKFLOW}->{ID},
        className => 'modal-lg'
    });

    $self->add_section({
        type => 'keyvalue',
        content => {
            label => '',
            data => $self->__render_fields( $wf_info, 'context'),
    }});

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
        label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_LABEL',
        description => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_DESC',
    });

    my $workflows = $self->send_command( 'get_workflow_instance_types' );
    return $self unless(defined $workflows);

    $self->logger()->trace('Workflows ' . Dumper $workflows);

    my $preset = {};
    if ($args->{preset}) {
        $preset = $args->{preset};

    } elsif (my $queryid = $self->param('query')) {
        my $result = $self->_client->session()->param('query_wfl_'.$queryid);
        $preset = $result->{input};
    }

    $self->logger()->trace('Preset ' . Dumper $preset);

    # TODO Sorting / I18
    my @wf_names = keys %{$workflows};
    my @wfl_list = map { $_ = {'value' => $_, 'label' => $workflows->{$_}->{label}} } @wf_names ;
    @wfl_list = sort { lc($a->{'label'}) cmp lc($b->{'label'}) } @wfl_list;

    my @proc_states = (

        { label => 'I18N_OPENXPKI_UI_WORKFLOW_PROC_STATE_MANUAL', value => 'manual' },
        { label => 'I18N_OPENXPKI_UI_WORKFLOW_PROC_STATE_PAUSE', value => 'pause' },
        { label => 'I18N_OPENXPKI_UI_WORKFLOW_PROC_STATE_RETRY_EXCEEDED', value => 'retry_exceeded' },
        { label => 'I18N_OPENXPKI_UI_WORKFLOW_PROC_STATE_EXCEPTION', value => 'exception' },
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
    my $attributes = $self->_session->param('wfsearch')->{default}->{attributes};
    if ($attributes && (ref $attributes eq 'ARRAY')) {
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
            'clonable' => 1,
            'value' => $preset->{attributes} || [],
        } if (@attrib);

    }

    $self->add_section({
        type => 'form',
        action => 'workflow!load',
        content => {
            title => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SEARCH_BY_ID_TITLE',
            submit_label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SUBMIT_LABEL',
            fields => [{
                name => 'wf_id',
                label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SERIAL_LABEL',
                type => 'text',
                value => $preset->{wf_id} || '',
            }]
    }});

    $self->add_section({
        type => 'form',
        action => 'workflow!search',
        content => {
            title => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SEARCH_DATABASE_TITLE',
            submit_label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SUBMIT_LABEL',
            fields => \@fields

        }
    });

    return $self;
}

=head2 init_result

Load the result of a query, based on a query id and paging information

=cut
sub init_result {

    my $self = shift;
    my $args = shift;

    my $queryid = $self->param('id');

    # will be removed once inline paging works
    my $startat = $self->param('startat') || 0;

    my $limit = $self->param('limit') || 0;

    if ($limit > 500) {  $limit = 500; }

    # Load query from session
    my $result = $self->_client->session()->param('query_wfl_'.$queryid);

    # result expired or broken id
    if (!$result || !$result->{count}) {

        $self->set_status('I18N_OPENXPKI_UI_SEARCH_RESULT_EXPIRED_OR_EMPTY','error');
        return $self->init_search();

    }

    # Add limits
    my $query = $result->{query};

    if ($limit) {
        $query->{LIMIT} = $limit;
    } elsif (!$query->{LIMIT}) {
        $query->{LIMIT} = 25;
    }

    $query->{START} = $startat;

    if (!$query->{ORDER}) {
        $query->{ORDER} = 'WORKFLOW.WORKFLOW_SERIAL';
        if (!defined $query->{REVERSE}) {
            $query->{REVERSE} = 1;
        }
    }

    $self->logger()->trace( "persisted query: " . Dumper $result);

    my $search_result = $self->send_command( 'search_workflow_instances', $query );

    $self->logger()->trace( "search result: " . Dumper $search_result);

    # Add page header from result - optional
    if ($result->{page} && ref $result->{page} ne 'HASH') {
        $self->_page($result->{page});
    } else {
        $self->_page({
            label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_RESULTS_TITLE',
            description => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_RESULTS_DESCRIPTION',
        });
    }

    my $pager;
    if ($startat != 0 || @{$search_result} == $query->{LIMIT}) {
        $pager = $self->__render_pager( $result, { limit => $query->{LIMIT}, startat => $query->{START} } );
    }


    my $body = $result->{column};
    $body = $self->__default_grid_row() if(!$body);

    my @lines = $self->__render_result_list( $search_result, $body );

    $self->logger()->trace( "dumper result: " . Dumper @lines);

    my $header = $result->{header};
    $header = $self->__default_grid_head() if(!$header);

    # buttons - from result (used in bulk) or default
    my @buttons;
    if ($result->{button} && ref $result->{button} eq 'ARRAY') {
        @buttons = @{$result->{button}};
    } else {

        push @buttons, { label => 'I18N_OPENXPKI_UI_SEARCH_REFRESH',
            page => 'redirect!workflow!result!id!' .$queryid,
            className => 'expected' };

        push @buttons, {
            label => 'I18N_OPENXPKI_UI_SEARCH_RELOAD_FORM',
            page => 'workflow!search!query!' .$queryid,
            className => 'alternative',
        } if ($result->{input});

        push @buttons,{ label => 'I18N_OPENXPKI_UI_SEARCH_NEW_SEARCH',
            page => 'workflow!search',
            className => 'failure'};
    }

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
            data => \@lines,
            empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
            pager => $pager,
            buttons => \@buttons
        }
    });

    return $self;

}

=head2 init_pager

Similar to init_result but returns only the data portion of the table as
partial result.

=cut

sub init_pager {

    my $self = shift;
    my $args = shift;

    my $queryid = $self->param('id');

    # Load query from session
    my $result = $self->_client->session()->param('query_wfl_'.$queryid);

    # result expired or broken id
    if (!$result || !$result->{count}) {
        $self->set_status('Search result expired or empty!','error');
        return $self->init_search();
    }

    my $startat = $self->param('startat');

    my $limit = $self->param('limit') || 25;

    if ($limit > 500) {  $limit = 500; }

    # align startat to limit window
    $startat = int($startat / $limit) * $limit;

    # Add limits
    my $query = $result->{query};
    $query->{LIMIT} = $limit;
    $query->{START} = $startat;

    if ($self->param('order')) {
        $query->{ORDER} = uc($self->param('order'));
    }

    if (defined $self->param('reverse')) {
        $query->{REVERSE} = $self->param('reverse');
    }

    $self->logger()->trace( "persisted query: " . Dumper $result);
    $self->logger()->trace( "executed query: " . Dumper $query);

    my $search_result = $self->send_command( 'search_workflow_instances', $query );

    $self->logger()->trace( "search result: " . Dumper $search_result);


    my $body = $result->{column};
    $body = $self->__default_grid_row() if(!$body);

    my @result = $self->__render_result_list( $search_result, $body );

    $self->logger()->trace( "dumper result: " . Dumper @result);

    $self->_result()->{_raw} = {
        _returnType => 'partial',
        data => \@result,
    };

    return $self;
}

=head2 init_history

Render the history as grid view (state/action/user/time)

=cut
sub init_history {

    my $self = shift;
    my $args = shift;

    my $id = $self->param('wf_id');

    $self->_page({
        label => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_TITLE',
        description => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_DESCRIPTION',
        className => 'modal-lg'
    });

    my $workflow_history = $self->send_command( 'get_workflow_history', { ID => $id } );

    $self->logger()->trace( "dumper result: " . Dumper $workflow_history);

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

    return $self;

}

=head2 init_mine

Filter workflows where the current user is the creator, similar to workflow
search.

=cut
sub init_mine {

    my $self = shift;
    my $args = shift;

    my $limit = $self->param('limit') || 25;

    if ($limit > 500) {  $limit = 500; }

    # will be removed once inline paging works
    my $startat = $self->param('startat') || 0;

    my $query = {
        ATTRIBUTE => [{ KEY => 'creator', VALUE => $self->_session->param('user')->{name} }],
        ORDER => 'WORKFLOW.WORKFLOW_SERIAL',
        REVERSE => 1,
    };

    my $search_result = $self->send_command( 'search_workflow_instances',
        { %{$query}, ( LIMIT => $limit, START => $startat ) } );

    # if size of result is equal to limit, check for full result count
    my $result_count = scalar @{$search_result};
    if ($result_count == $limit) {
        # we need to remove order/reverse
        my %count_query = %{$query};
        delete $count_query{ORDER};
        delete $count_query{REVERSE};
        $result_count = $self->send_command( 'search_workflow_instances_count', \%count_query );
    }

    $self->logger()->trace( "search result: " . Dumper $search_result);

    $self->_page({
        label => 'I18N_OPENXPKI_UI_MY_WORKFLOW_TITLE',
        description => 'I18N_OPENXPKI_UI_MY_WORKFLOW_DESCRIPTION',
    });

    my @column = @{$self->__default_grid_row()};

    # Store the query if we need to page
    my $pager;
    if ($result_count > $limit) {
        my $queryid = $self->__generate_uid();
        my $_query = {
            'id' => $queryid,
            'type' => 'workflow',
            'count' => $result_count,
            'query' => $query,
            'column' => \@column,
        };
        $self->_client->session()->param('query_wfl_'.$queryid, $_query );
        $pager = $self->__render_pager( $_query, { limit => $limit, startat => $startat } );
    }

    my @result = $self->__render_result_list( $search_result, \@column );

    $self->logger()->trace( "dumper result: " . Dumper @result);

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
            columns => $self->__default_grid_head(),
            data => \@result,
            empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
            pager => $pager,

        }
    });

    return $self;

}

=head2 init_task

Outstanding tasks, filter definitions are read from the uicontrol file

=cut

sub init_task {

    my $self = shift;
    my $args = shift;

    $self->_page({
        label => 'I18N_OPENXPKI_UI_WORKFLOW_OUTSTANDING_TASKS_LABEL'
    });

    my $tasklist = $self->_client->session()->param('tasklist')->{default};

    if (!@$tasklist) {
        return $self->redirect('home');
    }

    $self->logger()->trace( "got tasklist: " . Dumper $tasklist);

    TASKLIST:
    foreach my $item (@$tasklist) {

        my $query = $item->{query};
        my $limit = 25;

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

        my @cols;
        if ($item->{cols}) {
            @cols = @{$item->{cols}};
        } else {
            @cols = (
                { label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SERIAL_LABEL', field => 'WORKFLOW_SERIAL', sortkey => 'WORKFLOW.WORKFLOW_SERIAL' },
                { label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_UPDATED_LABEL', field => 'WORKFLOW_LAST_UPDATE', sortkey => 'WORKFLOW.WORKFLOW_LAST_UPDATE' },
                { label => 'I18N_OPENXPKI_UI_WORKFLOW_TYPE_LABEL', field => 'WORKFLOW_TYPE' },
                { label => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_LABEL', field => 'WORKFLOW_STATE' },
            );
        }

        # create the header from the columns spec
        my ($header, $column) = $self->__render_list_spec( \@cols );

        $self->logger()->trace( "columns : " . Dumper $column);

        my $search_result = $self->send_command( 'search_workflow_instances', { (LIMIT => $limit), %$query } );

        # empty message
        my $empty = $item->{ifempty} || 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL';

        my $pager;
        my @data;
        # No results
        if (!@$search_result) {

            if ($empty eq 'hide') {
                next TASKLIST;
            }

        } else {

            @data = $self->__render_result_list( $search_result, $column );

            $self->logger()->trace( "dumper result: " . Dumper @data);

            if ($limit == scalar @$search_result) {
                my %count_query = %{$query};
                delete $count_query{ORDER};
                delete $count_query{REVERSE};
                my $result_count= $self->send_command( 'search_workflow_instances_count', \%count_query  );
                my $queryid = $self->__generate_uid();
                my $_query = {
                    'id' => $queryid,
                    'type' => 'workflow',
                    'count' => $result_count,
                    'query' => $query,
                    'column' => $column
                };
                $self->_client->session()->param('query_wfl_'.$queryid, $_query );
                $pager = $self->__render_pager( $_query, { limit => $limit } );
            }

        }

        $self->add_section({
            type => 'grid',
            className => 'workflow',
            content => {
                label => $item->{label},
                description => $item->{description},
                actions => [{
                    path => 'redirect!workflow!load!wf_id!{serial}',
                    icon => 'view',
                }],
                columns => $header,
                data => \@data,
                pager => $pager,
                empty => $empty,

            }
        });

    }

    return $self;

}


=head2 init_log

Load and display the technical log file of the workflow

=cut

sub init_log {

    my $self = shift;
    my $args = shift;

    my $wf_id = $self->param('wf_id');

    $self->_page({
        label => 'I18N_OPENXPKI_UI_WORKFLOW_LOG',
        className => 'modal-lg'
    });

    my $result = $self->send_command( 'get_workflow_log', { ID => $wf_id } );
    $result = [] unless($result);

    $self->logger()->trace( "dumper result: " . Dumper $result);

    $self->add_section({
        type => 'grid',
        className => 'workflow',
        content => {
            columns => [
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_LOG_TIMESTAMP_LABEL', format => 'timestamp'},
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_LOG_PRIORITY_LABEL'},
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_LOG_MESSAGE_LABEL'},
            ],
            data => $result,
            empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
        }
    });

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

    $self->logger()->trace( "wf args: " . Dumper $wf_args);

    # check for delegation
    if ($wf_args->{wf_handler}) {
        return $self->__delegate_call($wf_args->{wf_handler}, $args);
    }

    my %wf_param;

    if ($wf_args->{wf_fields}) {
        my @fields = map { $_->{name} } @{$wf_args->{wf_fields}};
        my $fields = $self->param( \@fields );
        %wf_param = %{ $fields } if ($fields);
        $self->logger()->trace( "wf fields: " . Dumper $fields );
    }

    # take over params from token, if any
    if($wf_args->{wf_param}) {
        %wf_param = (%wf_param, %{$wf_args->{wf_param}});
    }

    # Apply serialization
    foreach my $key (keys %wf_param) {
        $wf_param{$key} = $self->serializer()->serialize($wf_param{$key}) if (ref $wf_param{$key});
    }

    $self->logger()->trace( "wf params: " . Dumper \%wf_param );

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

            if ($self->__check_for_validation_error()) {
                return $self;
            }

            $self->logger()->error("workflow acton failed!");
            my $extra = { wf_id => $wf_args->{wf_id}, wf_action => $wf_args->{wf_action} };
            $self->init_load();
            return $self;
        }

        $self->logger()->trace("wf info after execute: " . Dumper $wf_info );
        # purge the workflow token
        $self->__purge_wf_token( $wf_token );

    } elsif($wf_args->{wf_type}) {

        $wf_info = $self->send_command( 'create_workflow_instance', {
            WORKFLOW => $wf_args->{wf_type}, PARAMS   => \%wf_param, UIINFO => 1
        });
        if (!$wf_info) {

            if ($self->__check_for_validation_error()) {
                return $self;
            }

            $self->logger()->error("Create workflow failed");
            # pass required arguments via extra and reload init page

            my $extra = { wf_type => $wf_args->{wf_type} };
            $self->init_index();
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


    # Check if we can auto-load the next available action
    my $wf_action;
    my @activities = keys %{$wf_info->{ACTIVITY}};
    if (scalar @activities == 1 || (scalar @activities == 2 && (grep /global_cancel/, @activities))) {
        $wf_action = $activities[0];
    }

    # If we call the token action from within a result list we want
    # to "break out" and set the new url instead rendering the result inline
    if ($wf_args->{redirect}) {
        # Check if we can auto-load the next available action
        my $redirect = 'workflow!load!wf_id!'.$wf_info->{WORKFLOW}->{ID};
        if ($wf_action) {
            $redirect .= '!wf_action!'.$wf_action;
        }
        $self->redirect($redirect);
        return $self;
    }

    if ($wf_action &&
        (ref $wf_info->{STATE}->{output} ne 'ARRAY' || scalar(@{$wf_info->{STATE}->{output}}) == 0)) {
        $self->__render_from_workflow({ WF_INFO => $wf_info, WF_ACTION => $wf_action });
    } else {
        $self->__render_from_workflow({ WF_INFO => $wf_info });
    }

    return $self;

}

=head2 action_handle

Execute a workflow internal action (fail, resume, wakeup). Requires the
workflow and action to be set in the wf_token info.

=cut

sub action_handle {

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

    if (!$wf_args->{wf_id}) {
        $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_INVALID_REQUEST_HANDLE_WITHOUT_ID!','error');
        return $self;
    }

    if (!$wf_args->{wf_handle}) {
        $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_INVALID_REQUEST_HANDLE_WITHOUT_ACTION!','error');
        return $self;
    }

    if ($wf_args->{wf_handle} eq 'fail') {
        $self->logger()->info(sprintf "Workflow %01d set to failure by operator", $wf_args->{wf_id} );

        $wf_info = $self->send_command( 'fail_workflow', {
            ID => $wf_args->{wf_id},
        });
    } elsif ($wf_args->{wf_handle} eq 'wakeup') {
        $self->logger()->info(sprintf "Workflow %01d trigger wakeup", $wf_args->{wf_id} );
        $wf_info = $self->send_command( 'wakeup_workflow', {
            ID => $wf_args->{wf_id}, ASYNC => 'watch',
        });
    } elsif ($wf_args->{wf_handle} eq 'resume') {
        $self->logger()->info(sprintf "Workflow %01d trigger resume", $wf_args->{wf_id} );
        $wf_info = $self->send_command( 'resume_workflow', {
            ID => $wf_args->{wf_id}, ASYNC => 'watch',
        });

    }

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

    my $wf_info = $self->send_command( 'get_workflow_info', {
        ID => $wf_id, UIINFO => 1
    });
    $self->logger()->trace('wf_info ' . Dumper  $wf_info);

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

    # Read the query pattern for extra attributes from the session
    my $spec = $self->_session->param('wfsearch')->{default};
    my @attr = @{$self->__build_attribute_subquery( $spec->{attributes} )};

    if (@attr) {
        $input->{attributes} = $self->__build_attribute_preset(  $spec->{attributes} );
    }

    if ($self->param('wf_creator')) {
        $input->{wf_creator} = $self->param('wf_creator');
        push @attr, { KEY => 'creator', VALUE => ~~ $self->param('wf_creator') };

    }

    $query->{ATTRIBUTE} = \@attr;

    $self->logger()->trace("query : " . Dumper $query);

    my $result_count = $self->send_command( 'search_workflow_instances_count', $query );

    # No results founds
    if (!$result_count) {
        $self->set_status('I18N_OPENXPKI_UI_SEARCH_HAS_NO_MATCHES','error');
        return $self->init_search({ preset => $input });
    }

    # check if there is a custom column set defined
    my ($header,  $body);
    if ($spec->{cols} && ref $spec->{cols} eq 'ARRAY') {
        ($header, $body) = $self->__render_list_spec( $spec->{cols} );
    } else {
        $body = $self->__default_grid_row;
        $header = $self->__default_grid_head;
    }

    my $queryid = $self->__generate_uid();
    $self->_client->session()->param('query_wfl_'.$queryid, {
        'id' => $queryid,
        'type' => 'workflow',
        'count' => $result_count,
        'query' => $query,
        'input' => $input,
        'header' => $header,
        'column' => $body,
    });

    $self->redirect( 'workflow!result!id!'.$queryid  );

    return $self;

}

=head2 action_bulk

Receive a list of workflow serials (I<wf_id>) plus a workflow action
(I<wf_action>) to execute on those workflows. For each given serial the given
action is executed. The resulting state for each workflow is shown in a grid
table. Methods that require additional parameters are not supported yet.

=cut

sub action_bulk {

    my $self = shift;

    my @serials = $self->param('wf_id[]');
    my $action = $self->param('wf_action');

    $self->logger()->debug('Selected workflows : ' . join(", ", @serials));

    my @success; # list of wf_info results
    my $errors; # hash with wf_id => error
    foreach my $id (@serials) {

        my $wf_info = $self->send_command( 'execute_workflow_activity',
            { ID => $id, ACTIVITY => $action } );

        # send_command returns undef if there is an error which usually means
        # that the action was not successful. We can slurp the verbose error
        # from the result status item and display it in the table
        if (!$wf_info) {
            $errors->{$id} = $self->_status()->{message};
        } else {
            push @success, $wf_info;
            $self->logger()->trace('Result on '.$id.': '. Dumper $wf_info);
        }

    }

    $self->_page({
        label => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_RESULT_LABEL',
        description => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_RESULT_DESC',
    });

    if ($errors) {

        $self->_status({message => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_RESULT_HAS_FAILED_ITEMS_STATUS', 'level' => 'error' });

        my @failed_id = keys %{$errors};
        my $failed_result = $self->send_command( 'search_workflow_instances', { SERIAL => \@failed_id } );

        my @result_failed = $self->__render_result_list( $failed_result, $self->__default_grid_row );

        # push the error to the result
        my $pos_serial = 4;
        my $pos_state = 3;
        map {
            my $serial = $_->[ $pos_serial ];
            $_->[ $pos_state ] = $errors->{$serial};
        } @result_failed;

        $self->logger()->trace('Mangled failed result: '. Dumper \@result_failed);

        my @fault_head = @{$self->__default_grid_head};
        $fault_head[$pos_state] = { sTitle => 'Error' };

        $self->add_section({
            type => 'grid',
            className => 'workflow',
            content => {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_RESULT_FAILED_ITEMS_LABEL',
                description => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_RESULT_FAILED_ITEMS_DESC',
                actions => [{
                    path => 'workflow!load!wf_id!{serial}!view!result',
                    label => 'I18N_OPENXPKI_UI_WORKFLOW_OPEN_WORKFLOW_LABEL',
                    icon => 'view',
                    target => 'tab',
                }],
                columns => \@fault_head,
                data => \@result_failed,
                empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
            }
        });
    } else {
        $self->_status({message => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_RESULT_ACTION_SUCCESS_STATUS', 'level' => 'success' });
    }

    if (@success) {

        my @result_done = $self->__render_result_list( \@success, $self->__default_grid_row );

        $self->add_section({
            type => 'grid',
            className => 'workflow',
            content => {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_RESULT_SUCCESS_ITEMS_LABEL',
                description => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_RESULT_SUCCESS_ITEMS_DESC',
                actions => [{
                    path => 'workflow!load!wf_id!{serial}!view!result',
                    label => 'I18N_OPENXPKI_UI_WORKFLOW_OPEN_WORKFLOW_LABEL',
                    icon => 'view',
                    target => 'tab',
                }],
                columns => $self->__default_grid_head,
                data => \@result_done,
                empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
            }
        });
    }

    # persist the selected ids and add button to recheck the status
    my $queryid = $self->__generate_uid();
    $self->_client->session()->param('query_wfl_'.$queryid, {
        'id' => $queryid,
        'type' => 'workflow',
        'count' => scalar @serials,
        'query' => { SERIAL => \@serials },
    });

    $self->add_section({
        type => 'text',
        content => {
            buttons => [{
                label => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_RECHECK_BUTTON',
                page => 'redirect!workflow!result!id!' .$queryid,
                className => 'expected',
            }]
        }
    });

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

    $self->logger()->trace( "render args: " . Dumper $args);

    my $wf_info = $args->{WF_INFO} || undef;
    my $view = $args->{VIEW} || '';

    if (!$wf_info && $args->{WF_ID}) {
        $wf_info = $self->send_command( 'get_workflow_info', {
            ID => $args->{WF_ID}, UIINFO => 1
        });
        $args->{WF_INFO} = $wf_info;
    }

    $self->logger()->trace( "wf_info: " . Dumper $wf_info);
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

    my $wf_proc_state = $wf_info->{WORKFLOW}->{PROC_STATE} || 'init';


    # add buttons for manipulative handles (wakeup, fail, resume)
    # to be added to the default button list

    my @handles;
    my @buttons_handle;
    if ($wf_info->{HANDLES} && ref $wf_info->{HANDLES} eq 'ARRAY') {
        @handles = @{$wf_info->{HANDLES}};

        $self->logger()->debug('Adding global actions ' . join('/', @handles));

        if (grep /wakeup/, @handles) {
            my $token = $self->__register_wf_token( $wf_info, { wf_handle => 'wakeup' } );
            push @buttons_handle, {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_WAKEUP_BUTTON',
                action => 'workflow!handle!wf_token!'.$token->{value},
                className => 'exceptional'
            }
        }

        if (grep /resume/, @handles) {
            my $token = $self->__register_wf_token( $wf_info, { wf_handle => 'resume' } );
            push @buttons_handle, {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_RESUME_BUTTON',
                action => 'workflow!handle!wf_token!'.$token->{value},
                'className' => 'exceptional'
            };
        }

        if (grep /fail/, @handles) {
            my $token = $self->__register_wf_token( $wf_info, { wf_handle => 'fail' } );
            push @buttons_handle, {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_FAILURE_BUTTON',
                action => 'workflow!handle!wf_token!'.$token->{value},
                className => 'failure',
                confirm => {
                    label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_FAILURE_DIALOG_LABEL',
                    description => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_FAILURE_DIALOG_TEXT',
                }
            };
        }
    }

    # check if the workflow is in a "non-regular" state
    if (grep /$wf_proc_state/, ('pause','retry_exceeded','exception', 'running')) {

        # same page head for all proc states
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

        my $desc;
        my @buttons;
        my @fields;
        # Check if the workflow is in pause or exceeded
        if (grep /$wf_proc_state/, ('pause','retry_exceeded')) {

            @fields = ({
                label => 'I18N_OPENXPKI_UI_WORKFLOW_LAST_UPDATE_LABEL',
                value => str2time($wf_info->{WORKFLOW}->{LAST_UPDATE}.' GMT'),
                'format' => 'timestamp'
            }, {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_WAKEUP_AT_LABEL',
                value => $wf_info->{WORKFLOW}->{WAKE_UP_AT},
                'format' => 'timestamp'
            }, {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_COUNT_TRY_LABEL',
                value => $wf_info->{WORKFLOW}->{COUNT_TRY}
            }, {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_PAUSE_REASON_LABEL',
                value => $wf_info->{WORKFLOW}->{CONTEXT}->{wf_pause_msg}
            });

            # If wakeup is less than 300 seconds away, we schedule an
            # automated reload of the page
            if ( $wf_info->{WORKFLOW}->{WAKE_UP_AT} ) {
                my $to_sleep = $wf_info->{WORKFLOW}->{WAKE_UP_AT} - time();
                if ($to_sleep < 30) {
                    $self->refresh('workflow!load!wf_id!'.$wf_info->{WORKFLOW}->{ID}, 30);
                } elsif ($to_sleep < 300) {
                    $self->refresh('workflow!load!wf_id!'.$wf_info->{WORKFLOW}->{ID}, $to_sleep + 15);
                }
            }

            # if there are output rules defined, we add them now
            if ( $wf_info->{STATE}->{output} ) {
                push @fields, @{$self->__render_fields( $wf_info, $view )};
            }

            if ($wf_proc_state eq 'pause') {
                $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_STATE_WATCHDOG_PAUSED','info');
                $desc = 'I18N_OPENXPKI_UI_WORKFLOW_STATE_WATCHDOG_PAUSED_DESCRIPTION';

                @buttons = ({
                    'page' => 'redirect!workflow!load!wf_id!'.$wf_info->{WORKFLOW}->{ID},
                    'label' => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_WATCHDOG_PAUSED_RECHECK_BUTTON',
                    'className' => 'alternative'
                });
            } else {
                $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_STATE_WATCHDOG_RETRY_EXCEEDED','error');
                $desc = 'I18N_OPENXPKI_UI_WORKFLOW_STATE_WATCHDOG_RETRY_EXCEEDED_DESCRIPTION';
            }

        # if the workflow is currently runnig, show info without buttons
        } elsif ($wf_proc_state eq 'running') {

            $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_STATE_RUNNING_LABEL','info');

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

            @fields = ({
                    label => 'I18N_OPENXPKI_UI_WORKFLOW_LAST_UPDATE_LABEL',
                    value => str2time($wf_info->{WORKFLOW}->{LAST_UPDATE}.' GMT'),
                    'format' => 'timestamp'
                }, {
                    label => 'I18N_OPENXPKI_UI_WORKFLOW_ACTION_RUNNING_LABEL',
                    value => ($wf_info->{ACTIVITY}->{$wf_action}->{label} || $wf_action)
            });

            @buttons = ({
                'page' => 'redirect!workflow!load!wf_id!'.$wf_info->{WORKFLOW}->{ID},
                'label' => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_RECHECK_BUTTON',
                'className' => 'alternative'
            });

            # we use the time elapsed to calculate the next update
            my $timeout = 120;
            if ( $wf_info->{WORKFLOW}->{LAST_UPDATE} ) {
                # elapsed time in MINUTES
                my $elapsed = (time() - str2time($wf_info->{WORKFLOW}->{LAST_UPDATE}.' GMT')) / 60;
                if ($elapsed > 240) {
                    $timeout = 15 * 60;
                } elsif ($elapsed > 4) {
                    # 4 hours = 15 min delay, 4 min = 2 min delay
                    $timeout = int sqrt( $elapsed ) * 60;
                }
                $self->logger()->debug('Auto Refresh when running' . $elapsed .' / ' . $timeout );

            }

            $self->refresh('workflow!load!wf_id!'.$wf_info->{WORKFLOW}->{ID}, $timeout);

        # workflow halted by exception
        } elsif ( $wf_proc_state eq 'exception') {

            @fields = ({
                label => 'I18N_OPENXPKI_UI_WORKFLOW_LAST_UPDATE_LABEL',
                value => str2time($wf_info->{WORKFLOW}->{LAST_UPDATE}.' GMT'),
                'format' => 'timestamp'
            }, {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_EXCEPTION_FAILED_ACTION_LABEL',
                value => ($wf_action_info->{label} || $wf_action)
            });

            # if there are output rules defined, we add them now
            if ( $wf_info->{STATE}->{output} ) {
                push @fields, @{$self->__render_fields( $wf_info, $view )};
            }

            # if we come here from a failed action the status is set already
            if (!$self->_status()) {
                $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_STATE_EXCEPTION','error');
            }
            $desc = 'I18N_OPENXPKI_UI_WORKFLOW_STATE_EXCEPTION_DESCRIPTION';

        } # end proc_state switch

        $self->add_section({
            type => 'keyvalue',
            content => {
                label => '',
                description => $desc,
                data => \@fields,
                buttons => [ @buttons, @buttons_handle ]
        }});

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

        $self->logger()->trace('activity info ' . Dumper $wf_action_info );

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
            my $descr = $field->{description};
            if ($descr && $descr !~ /^\s*$/ && $field->{type} ne 'hidden') {
                push @fielddesc, { label => $item->{label}, value => $descr, format => 'raw' };
            }

        }

        # Render the context values if there are no fields
        if (!scalar @fields) {
            my $fields = $self->__render_fields( $wf_info, $view );
            $self->add_section({
                type => 'keyvalue',
                content => {
                    label => '',
                    description => '',
                    data => $fields,
            }});
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
                submit_label => 'I18N_OPENXPKI_UI_WORKFLOW_SUBMIT_BUTTON',
                fields => \@fields,
                buttons => $self->__get_form_buttons( $wf_info ),
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
            className => 'modal-lg'
        });

        my $fields = $self->__render_fields( $wf_info, $view );

        $self->logger()->trace('Field data ' . Dumper $fields);

        # Add action buttons
        my $buttons = $self->__get_action_buttons( $wf_info ) ;

        # Workflows can render grids -> only one field with format = grid
        if (scalar @{$fields} == 1 && $fields->[0]->{format} eq 'grid') {

            my $grid = $fields->[0];
            $self->add_section({
                type => 'grid',
                className => 'workflow',
                content => {
                    actions => ($grid->{action} ? [{
                        path => $grid->{action},
                        label => '',
                        icon => 'view',
                        target => ($grid->{target} ? $grid->{target} : 'tab'),
                    }] : undef),
                    columns =>  $grid->{header},
                    data => $grid->{value},
                    empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
                    buttons => $buttons
                }
            });
        # Standard case - render key/value
        } else {
            $self->add_section({
                type => 'keyvalue',
                content => {
                    label => '',
                    description => '',
                    data => $fields,
                    buttons => $buttons
            }});
        }

        # set status decorator on final states, use proc state
        my $desc = $wf_info->{STATE}->{description};

        if ($wf_proc_state eq 'finished') {
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
        } elsif ($wf_proc_state eq 'exception') {

            $self->set_status( 'I18N_OPENXPKI_UI_WORKFLOW_STATE_EXCEPTION','error');
        }

    }

    # Right block
    if ($wf_info->{WORKFLOW}->{ID} ) {

        my @buttons;

        if ($view eq 'result' && $wf_info->{WORKFLOW}->{STATE} !~ /(SUCCESS|FAILURE)/) {
            @buttons = ({
                'action' => 'redirect!workflow!load!wf_id!'.$wf_info->{WORKFLOW}->{ID},
                'label' => 'I18N_OPENXPKI_UI_WORKFLOW_OPEN_WORKFLOW_LABEL', #'open workflow',
            });
        }

        # create a "blind" query to generate an initial search form
        my $queryid = $self->__generate_uid();
        my $_query = {
            'id' => $queryid,
            'type' => 'workflow',
            'input' => {
                wf_creator => $wf_info->{WORKFLOW}->{CONTEXT}->{creator},
                wf_type => $wf_info->{WORKFLOW}->{TYPE},
            },
        };
        $self->__temp_param('query_wfl_'.$queryid, $_query );

        my @data = (
            { label => 'I18N_OPENXPKI_UI_WORKFLOW_ID_LABEL', 'format' => 'link', value => {
                'label' => $wf_info->{WORKFLOW}->{ID},
                'page' => 'workflow!load!wf_id!'.$wf_info->{WORKFLOW}->{ID},
                'target' => '_blank',
            }},
            { label => 'I18N_OPENXPKI_UI_WORKFLOW_TYPE_LABEL', value => $wf_info->{WORKFLOW}->{TYPE} },
            { label => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_LABEL', value => $wf_info->{WORKFLOW}->{STATE} },
            { label => 'I18N_OPENXPKI_UI_WORKFLOW_PROC_STATE_LABEL', value => $wf_info->{WORKFLOW}->{PROC_STATE} },
            { label => 'I18N_OPENXPKI_UI_WORKFLOW_CREATOR_LABEL', 'format' => 'link', value => {
                'label' => $wf_info->{WORKFLOW}->{CONTEXT}->{creator},
                'page' => 'workflow!search!query!'.$queryid,
                'target' => '_blank',
            }}
        );


        # The workflow info contains info about all control actions that
        # can done on the workflow -> render appropriate buttons.
        my $extra_handles;
        if (@handles) {

            my @extra_links;
            if (grep /context/, @handles) {
                push @extra_links, {
                    'page' => 'workflow!context!wf_id!'.$wf_info->{WORKFLOW}->{ID},
                    'label' => 'I18N_OPENXPKI_UI_WORKFLOW_CONTEXT_LABEL',
                };
            }

            if (grep /history/, @handles) {
                push @extra_links, {
                    'page' => 'workflow!history!wf_id!'.$wf_info->{WORKFLOW}->{ID},
                    'label' => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_LABEL',
                };
            }

            if (grep /techlog/, @handles) {
                push @extra_links, {
                    'page' => 'workflow!log!wf_id!'.$wf_info->{WORKFLOW}->{ID},
                    'label' => 'I18N_OPENXPKI_UI_WORKFLOW_LOG_LABEL',
                };
            }

            push @data, {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_EXTRA_INFO_LABEL',
                format => 'linklist',
                value => \@extra_links
            } if (scalar @extra_links);

        }

        $self->_result()->{right} = [{
            type => 'keyvalue',
            content => {
                label => '',
                description => '',
                data => \@data,
                buttons => \@buttons_handle,
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
    my $btnhint = $wf_info->{STATE}->{button} || {};

    my @buttons;

    if ($btnhint->{_head}) {
        push @buttons, { section => $btnhint->{_head} };
    }

    foreach my $wf_action (@{$wf_info->{STATE}->{option}}) {
        my $wf_action_info = $wf_info->{ACTIVITY}->{$wf_action};

        my %button = (
            label => $wf_action_info->{label} || $wf_action,
            action => sprintf ('workflow!select!wf_action!%s!wf_id!%01d', $wf_action, $wf_info->{WORKFLOW}->{ID}),
        );
        # TODO - we should add some configuration option for this
        if ($wf_action =~ /global_cancel/) {
            $button{confirm} = {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_CONFIRM_CANCEL_LABEL',
                description => 'I18N_OPENXPKI_UI_WORKFLOW_CONFIRM_CANCEL_DESCRIPTION',
            };
        }

        if ($btnhint->{$wf_action}) {
            my $hint = $btnhint->{$wf_action};
            # a label at the button overrides the default label from the action
            foreach my $key (qw(description tooltip label)) {
                if ($hint->{$key}) {
                    $button{$key} = $hint->{$key};
                }
            }
            if ($hint->{format}) {
                $button{className} = $hint->{format};
            }
            if ($hint->{confirm}) {
                $button{confirm} = {
                    label => $hint->{confirm}->{label} || 'I18N_OPENXPKI_UI_PLEASE_CONFIRM_TITLE',
                    description => $hint->{confirm}->{description} || 'I18N_OPENXPKI_UI_PLEASE_CONFIRM_DESC',
                }
            }
        }

       push @buttons, \%button;
    }

    $self->logger()->trace('Buttons are ' . Dumper \@buttons);

    return \@buttons;
}

sub __get_form_buttons {

    my $self = shift;
    my $wf_info = shift;
    my @buttons;

    my $activity_count = scalar keys %{$wf_info->{ACTIVITY}};
    if ($wf_info->{ACTIVITY}->{global_cancel}) {
        push @buttons, {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_CANCEL_BUTTON',
            action => 'workflow!select!wf_action!global_cancel!wf_id!'. $wf_info->{WORKFLOW}->{ID},
            className => 'cancel',
            confirm => {
                description => 'I18N_OPENXPKI_UI_WORKFLOW_CONFIRM_CANCEL_DESCRIPTION',
                label => 'I18N_OPENXPKI_UI_WORKFLOW_CONFIRM_CANCEL_LABEL',
        }};
        $activity_count--;
    }

    # if there is another activity besides global_cancel, we add a go back button
    if ($activity_count > 1) {
        unshift @buttons, {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_RESET_BUTTON',
            page => 'redirect!workflow!load!wf_id!'.$wf_info->{WORKFLOW}->{ID},
            className => 'reset',
        };
    }

    if ($wf_info->{HANDLES} && ref $wf_info->{HANDLES} eq 'ARRAY' && (grep /fail/, @{$wf_info->{HANDLES}})) {
        my $token = $self->__register_wf_token( $wf_info, { wf_handle => 'fail' } );
        push @buttons, {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_FAILURE_BUTTON',
            action => 'workflow!handle!wf_token!'.$token->{value},
            className => 'failure',
            confirm => {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_FAILURE_DIALOG_LABEL Fail Workflow',
                description => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_FAILURE_DIALOG_TEXT',
            }
        };
    }

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
            } elsif(OpenXPKI::Serialization::Simple::is_serialized($value)) {
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

    my ($class, $method) = $call =~ /([\w\:\_]+)::([\w\_]+)/;
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
    my $colums = shift;

    $self->logger()->trace("search result " . Dumper $search_result);

    my @result;

    foreach my $wf_item (@{$search_result}) {

        my @line;
        my ($wf_info, $context, $attrib);

        # if we received a list of wf_info structures, we need to translate
        # the workflow hash into the database table format
        if ($wf_item->{WORKFLOW} && ref $wf_item->{WORKFLOW} eq 'HASH') {
            $wf_info = $wf_item;
            $context = $wf_info->{WORKFLOW}->{CONTEXT};
            $attrib = $wf_info->{WORKFLOW}->{ATTRIBUTE};
            $wf_item = {
                'WORKFLOW.WORKFLOW_LAST_UPDATE' => $wf_info->{WORKFLOW}->{LAST_UPDATE},
                'WORKFLOW.WORKFLOW_SERIAL' => $wf_info->{WORKFLOW}->{ID},
                'WORKFLOW.WORKFLOW_TYPE' => $wf_info->{WORKFLOW}->{TYPE},
                'WORKFLOW.WORKFLOW_STATE' => $wf_info->{WORKFLOW}->{STATE},
                'WORKFLOW.WORKFLOW_PROC_STATE' => $wf_info->{WORKFLOW}->{PROC_STATE},
                'WORKFLOW.WORKFLOW_WAKEUP_AT' => $wf_info->{WORKFLOW}->{WAKE_UP_AT},
            };
        }

        foreach my $col (@{$colums}) {

            # we need to load the wf info
            if (!$wf_info && ($col->{template} || $col->{source} ne 'workflow')) {
                $wf_info = $self->send_command( 'get_workflow_info', { ID => $wf_item->{'WORKFLOW.WORKFLOW_SERIAL'}, ATTRIBUTE => 1 });
                $self->logger()->trace( "fetch wf info : " . Dumper $wf_info);
                $context = $wf_info->{WORKFLOW}->{CONTEXT};
                $attrib = $wf_info->{WORKFLOW}->{ATTRIBUTE};
            }

            if ($col->{template}) {
                my $out;
                my $ttp = {
                    context => $context,
                    attribute => $attrib,
                    workflow => $wf_info->{WORKFLOW}
                };
                push @line, $self->send_command( 'render_template', { TEMPLATE => $col->{template}, PARAMS => $ttp } );

            } elsif ($col->{source} eq 'workflow') {

                # Special handling of the state field
                if ($col->{field} eq "WORKFLOW_STATE") {
                    my $state = $wf_item->{'WORKFLOW.WORKFLOW_STATE'};

                    if ($wf_item->{'WORKFLOW.WORKFLOW_PROC_STATE'} eq 'exception') {
                        $state .= " ( I18N_OPENXPKI_UI_WORKFLOW_PROC_STATE_EXCEPTION )";

                    } elsif ($wf_item->{'WORKFLOW.WORKFLOW_PROC_STATE'} eq 'pause') {
                        $state .= " ( I18N_OPENXPKI_UI_WORKFLOW_PROC_STATE_PAUSE )";

                    } elsif ($wf_item->{'WORKFLOW.WORKFLOW_PROC_STATE'} eq 'retry_exceeded') {
                        $state .= " ( I18N_OPENXPKI_UI_WORKFLOW_PROC_STATE_RETRY_EXCEEDED )";

                    }
                    push @line, $state;
                } else {
                    push @line, $wf_item->{ 'WORKFLOW.'.$col->{field} };

                }

            } elsif ($col->{source} eq 'context') {
                push @line, $context->{ $col->{field} };
            } elsif ($col->{source} eq 'attribute') {
                # to be implemented if required
                push @line, $attrib->{$col->{field}}
            } else {
                # hu ?
            }
        }

        # special color for workflows in final failure

        my $status = $wf_item->{'WORKFLOW.WORKFLOW_PROC_STATE'};

        if ($status eq 'finished' && $wf_item->{'WORKFLOW.WORKFLOW_STATE'} eq 'FAILURE') {
            $status  = 'failed';
        }

        push @line, $status;

        push @result, \@line;

    }

    return @result;

}

=head2 __render_list_spec

Create array to pass to UI from specification in config file

=cut

sub __render_list_spec {

    my $self = shift;
    my $cols = shift;

    my @header;
    my @column;

    for (my $ii = 0; $ii < scalar @{$cols}; $ii++) {

        # we must create a copy as we change the hash in the session info otherwise
        my %col = %{$cols->[$ii]};
        my $head = { sTitle => $col{label} };
        if ($col{sortkey}) {
            $head->{sortkey} = $col{sortkey};
        }
        if ($col{format}) {
            $head->{format} = $col{format};
        }
        push @header, $head;

        if ($col{template}) {

        } elsif ($col{field} =~ m{\A (context|attribute)\.(\S+) }xi) {
            # we use this later to avoid the pattern match
            $col{source} = $1;
            $col{field} = $2;

        } else {
            $col{source} = 'workflow';
            $col{field} = uc($col{field})

        }
        push @column, \%col;
    }

    push @header, { sTitle => 'serial', bVisible => 0 };
    push @header, { sTitle => "_className"};

    push @column, { source => 'workflow', field => 'WORKFLOW_SERIAL' };

    return ( \@header, \@column );
}

=head2 __render_fields

=cut
sub __render_fields {

    my $self = shift;
    my $wf_info = shift;
    my $view = shift;

        my @fields;
        my $context = $wf_info->{WORKFLOW}->{CONTEXT};

        # in case we have output format rules, we just show the defined fields
        # can be overriden with view = context
        my $output = $wf_info->{STATE}->{output};
        my @fields_to_render;

        if ($view eq 'context' && (grep /context/, @{$wf_info->{HANDLES}})) {
            foreach my $field (sort keys %{$context}) {
                push @fields_to_render, { name => $field };
            }
        } elsif ($output) {
            @fields_to_render = @{$wf_info->{STATE}->{output}};
            $self->logger()->trace('Render output rules: ' . Dumper  \@fields_to_render  );

        } else {
            foreach my $field (sort keys %{$context}) {

                next if ($field =~ m{ \A (wf_|_|workflow_id|sources) }x);
                push @fields_to_render, { name => $field };
            }
            $self->logger()->trace('No output rules, render plain context: ' . Dumper  \@fields_to_render  );
        }

        foreach my $field (@fields_to_render) {

            my $key = $field->{name} || '';
            my $item = {
                value => (defined $context->{$key} ? $context->{$key} : ''),
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
                } elsif ($field->{type} && $field->{type} eq 'textarea') {
                    $item->{format} = 'nl2br';
                }

                if (OpenXPKI::Serialization::Simple::is_serialized( $item->{value} ) ) {
                    $item->{value} = $self->serializer()->deserialize( $item->{value} );
                }
                if (ref $item->{value}) {
                    if (ref $item->{value} eq 'HASH') {
                        $item->{format} = 'deflist';
                    } elsif (ref $item->{value} eq 'ARRAY') {
                        $item->{format} = 'ullist';
                    }
                }
            }

            # convert format cert_identifier into a link
            if ($item->{format} eq "cert_identifier") {
                $item->{format} = 'link';

                # check for additional template
                if ($item->{value}) {
                    my $label = $item->{value};

                    my $cert_identifier = $item->{value};

                    $item->{value}  = {
                        label => $label,
                        page => 'certificate!detail!identifier!'.$cert_identifier,
                        target => 'modal'

                    };
                }

                $self->logger()->trace( 'item ' . Dumper $item);

            # add a redirect command to the page
            } elsif ($item->{format} eq "redirect") {

                $self->redirect($item->{value});

            # create a link to download the given filename
            } elsif ($item->{format} =~ m{ \A download(\/([\w_\/-]+))? }xms ) {

                my $mime = $2 || 'application/octect-stream';

                $item->{format} = 'extlink';

                my $label;
                my $basename;
                my $source;
                # value can be a hash with additional properties - likely serialized
                if (OpenXPKI::Serialization::Simple::is_serialized( $item->{value} ) ) {
                    $item->{value} = $self->serializer()->deserialize( $item->{value} );
                }

                if (ref $item->{value}) {
                    my $t = $item->{value};
                    $label = $t->{label} || 'I18N_OPENXPKI_UI_CLICK_TO_DOWNLOAD';

                    # Fallback for legacy config
                    if (!$t->{source} && $t->{file}) {
                         $source = "file:".$t->{file};
                    }
                    $source = $t->{source};
                    $basename = $t->{filename} if ($t->{filename});
                    $mime = $t->{mime} if ($t->{mime});
                } else {
                    $label = $item->{value};
                    $source = "file:".$item->{value};
                }

                if (!$basename && $source =~ m{ file:.*?([^\/]+(\.\w+)?) \z }xms) {
                   $basename = $1;
                }

                my $target = $self->__persist_response({
                    source => $source,
                    attachment =>  $basename,
                    mime => $mime
                });

                $item->{value}  = {
                    label => $label,
                    page => $self->_client()->_config()->{'scripturl'} . "?page=".$target
                };

            # format for cert_info block
            } elsif ($item->{format} eq "cert_info") {
                $item->{format} = 'deflist';

                # its likely that we need to deserialize
                my $raw = $item->{value};
                if (OpenXPKI::Serialization::Simple::is_serialized( $raw ) ) {
                    $raw = $self->serializer()->deserialize( $raw );
                }

                # this requires that we find the profile and subject in the context
                my @val;
                my $cert_profile = $context->{cert_profile};
                my $cert_subject_style = $context->{cert_subject_style};
                if ($cert_profile && $cert_subject_style) {

                    if (!$raw || ref $raw ne 'HASH') {
                        $raw = {};
                    }

                    my $fields = $self->send_command( 'get_field_definition',
                        { PROFILE => $cert_profile, STYLE => $cert_subject_style, 'SECTION' =>  'info' });
                    $self->logger()->trace( 'Profile fields' . Dumper $fields );

                    foreach my $field (@$fields) {
                        # this still uses "old" syntax - adjust after API refactoring
                        my $key = $field->{ID}; # Name of the context key
                        if ($raw->{$key}) {
                            push @val, { label => $field->{LABEL}, value => $raw->{$key}, key => $key };
                        }
                    }
                } else {
                    # if nothing is found, transform raw values to a deflist
                    @val = map { { key => $_, label => $_, value => $item->{value}->{$_}} } sort keys %{$item->{value}};

                }

                $item->{value} = \@val;

            } elsif ($item->{format} eq "ullist" || $item->{format} eq "rawlist") {

                if (OpenXPKI::Serialization::Simple::is_serialized( $item->{value} ) ) {
                    $item->{value} = $self->serializer()->deserialize( $item->{value} );
                }

            } elsif ($item->{format} eq "itemcnt") {

                my $list = $item->{value};
                if (OpenXPKI::Serialization::Simple::is_serialized( $item->{value} ) ) {
                    $list = $self->serializer()->deserialize( $item->{value} );
                }

                if (ref $list eq 'ARRAY') {
                    $item->{value} = scalar @{$list};
                } elsif (ref $list eq 'HASH') {
                    $item->{value} = scalar keys %{$list};
                } else {
                    $item->{value} = '??';
                }
                $item->{format} = '';

            } elsif ($item->{format} eq "deflist") {

                if (OpenXPKI::Serialization::Simple::is_serialized( $item->{value} ) ) {
                    $item->{value} = $self->serializer()->deserialize( $item->{value} );
                }
                # Sort by label
                my @val;
                if ($item->{value} && (ref $item->{value} eq 'HASH')) {
                    @val = map { { label => $_, value => $item->{value}->{$_}} } sort keys %{$item->{value}};
                }
                $item->{value} = \@val;

            } elsif ($item->{format} eq "grid") {

                my @head;
                # Create the required header structure
                if ($field->{header}) {
                    @head = map { { 'sTitle' => $_ } } @{$field->{header}};
                } else {
                    # just create empty headers for the number of columns
                    @head = map { { 'sTitle' => '' } } @{$field->{value}->[0]};
                }
                $item->{header} = \@head;
                $item->{action} = $field->{action};
                $item->{target} = $field->{target} ?  $field->{target} : 'tab';
            }

            if ($field->{template}) {

                my $param = { value => $item->{value} };

                $self->logger()->trace('Render output using template on field '.$key.', '. $field->{template} . ', params:  ' . Dumper $param);

                # Rendering target depends on value format
                # deflist iterates over each key/label pair and sets the return value into the label
                if ($item->{format} eq "deflist") {

                    foreach (@{$item->{value}}){
                        $_->{value} = $self->send_command( 'render_template', { TEMPLATE => $field->{template}, PARAMS => $_ } );
                        $_->{format} = 'raw';
                    }

                # bullet list, put the full list to tt and split at the | as sep (as used in profile)
                } elsif ($item->{format} eq "ullist" || $item->{format} eq "rawlist") {

                    my $out = $self->send_command( 'render_template', { TEMPLATE => $field->{template}, PARAMS => $param } );
                    $self->logger()->debug('Return from template ' . $out );
                    if ($out) {
                        my @val = split /\s*\|\s*/, $out;
                        $self->logger()->trace('Split ' . Dumper \@val);
                        $item->{value} = \@val;
                    } else {
                        $item->{value} = undef; # prevent pusing emtpy lists
                    }

                } elsif ($item->{format} eq "raw") {
                    # try to deserialize
                    my $param = $item->{value};
                    if (!ref $param && OpenXPKI::Serialization::Simple::is_serialized( $param ) ) {
                        $param = $self->serializer()->deserialize( $param );
                    }
                    $item->{value} = $self->send_command( 'render_template', { TEMPLATE => $field->{template}, PARAMS => { value => $param } } );

                } elsif (ref $item->{value} eq '') {
                    $item->{value} = $self->send_command( 'render_template', { TEMPLATE => $field->{template}, PARAMS => $param } );

                } elsif (ref $item->{value} eq 'HASH' && $item->{value}->{label}) {
                    $item->{value}->{label} = $self->send_command( 'render_template', { TEMPLATE => $field->{template},
                        PARAMS => { value => $item->{value}->{label} }} );
                } else {
                    $self->logger()->error('Unable to apply template, format: '.$item->{format}.', field: '.$key);

                }

            }

            # do not push items that are empty
            if (defined $item->{value} &&
                ((ref $item->{value} eq 'HASH' && %{$item->{value}}) ||
                (ref $item->{value} eq 'ARRAY' && @{$item->{value}}) ||
                (ref $item->{value} eq '' && $item->{value} ne ''))) {
                push @fields, $item;
            }
        }

        return \@fields;

}

=head2 __check_for_validation_error

Uses last_reply to check if there was a validation error. If a validation
error occured, the field_errors hash is returned and the status variable is
set to render the errors in the form view. Returns undef otherwise.

=cut

sub __check_for_validation_error {

    my $self = shift;
    my $reply = $self->_last_reply();
    if ($reply->{LIST} && ref $reply->{LIST} eq 'ARRAY' &&
        $reply->{LIST}->[0]->{LABEL} eq 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATION_FAILED_ON_EXECUTE') {
        my $p = $reply->{LIST}->[0]->{PARAMS};
        my $validator_msg = $p->{__ERROR__};
        my $field_errors = $p->{__FIELDS__};
        my @fields = (ref $field_errors eq 'ARRAY') ? map { $_->{name} } @$field_errors : ();
        $self->_status({ level => 'error', message => $validator_msg, field_errors => $field_errors });
        $self->logger()->error("Input validation error on fields ". join ",", @fields);
        $self->logger()->trace('validation details' . Dumper $field_errors );
        return $field_errors;
    }
    return;
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
