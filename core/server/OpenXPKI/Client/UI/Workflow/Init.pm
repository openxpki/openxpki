package OpenXPKI::Client::UI::Workflow::Init;
use Moose;

extends 'OpenXPKI::Client::UI::Workflow';
with qw(
    OpenXPKI::Client::UI::Role::QueryCache
    OpenXPKI::Client::UI::Role::Pager
);

# Core modules
use Data::Dumper;
use Encode;

# Project modules
use OpenXPKI::DateTime;
use OpenXPKI::i18n qw( i18nTokenizer i18nGettext );
use OpenXPKI::Util;

=head1 UI Methods

=head2 init_index

Requires parameter I<wf_type> and shows the intro page of the workflow.
The headline is the value of type followed by an intro text as given
as workflow description. At the end of the page a button names "start"
is shown.

This is usually used to start a workflow from the menu or link, e.g.

    workflow!index!wf_type!change_metadata

=cut

sub init_index {

    my $self = shift;
    my $args = shift;

    my $wf_info = $self->send_command_v2( 'get_workflow_base_info', {
        type => scalar $self->param('wf_type')
    });

    if (!$wf_info) {
        $self->status->error('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION');
        return $self;
    }

    # Pass the initial activity so we get the form right away
    my $wf_action = $self->__get_next_auto_action($wf_info);

    $self->__render_from_workflow({ wf_info => $wf_info, wf_action => $wf_action });
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

    my $wf_type = $self->param('wf_type');
    if (!$wf_type) {
        # todo - handle errors
        $self->log->error("No workflow given to init_start");
        return $self;
    }

    my $wf_info = $self->send_command_v2( 'create_workflow_instance', {
        workflow => $wf_type,
        params => $self->secure_param('wf_params') // {},
        ui_info => 1,
        $self->__tenant(),
    });

    if (!$wf_info) {
        # todo - handle errors
        $self->log->error("Create workflow failed");
        return $self;
    }

    $self->log->trace("wf info on create: " . Dumper $wf_info ) if $self->log->is_trace;

    $self->log->info(sprintf "Create new workflow %s, got id %01d",  $wf_info->{workflow}->{type}, $wf_info->{workflow}->{id} );

    # this duplicates code from action_index
    if ($wf_info->{workflow}->{id} > 0 && !(grep { $_ =~ m{\A_} } keys %{$wf_info->{workflow}->{context}})) {

        my $redirect = 'workflow!load!wf_id!'.$wf_info->{workflow}->{id};
        my @activity = keys %{$wf_info->{activity}};
        if (scalar @activity == 1) {
            $redirect .= '!wf_action!'.$activity[0];
        }
        $self->redirect->to($redirect);

    } else {
        # one shot workflow
        $self->__render_from_workflow({ wf_info => $wf_info });
    }

    return $self;

}

=head2 init_load

Requires parameter I<wf_id> which is the id of an existing workflow.
It loads the workflow at the current state and tries to render it
using the __render_from_workflow method. In states with multiple actions
I<wf_action> can be set to select one of them. If those arguments are not
set from the CGI environment, they can be passed as method arguments.

=cut

sub init_load {

    my $self = shift;
    my $args = shift;

    # re-instance existing workflow
    my $id = $self->param('wf_id') || $args->{wf_id} || 0;
    $id =~ s/[^\d]//g;

    my $wf_action = $self->param('wf_action') || $args->{wf_action} || '';
    my $view = $self->param('view') || '';

    my $wf_info = $self->send_command_v2( 'get_workflow_info',  {
        id => $id,
        with_ui_info => 1,
    }, { nostatus  => 1 });

    if (!$wf_info) {
        $self->status->error('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION') unless $self->status->is_set;
        return $self->init_search({ preset => { wf_id => $id } });
    }

    # Set single action if no special view is requested and only single action is avail
    if (!$view && !$wf_action && $wf_info->{workflow}->{proc_state} eq 'manual') {
        $wf_action = $self->__get_next_auto_action($wf_info);
    }

    $self->__render_from_workflow({ wf_info => $wf_info, wf_action => $wf_action, view => $view });

    return $self;

}

=head2 init_context

Requires parameter I<wf_id> which is the id of an existing workflow.
Shows the context as plain key/value pairs - usually called in a popup.

=cut

sub init_context {

    my $self = shift;

    # re-instance existing workflow
    my $id = $self->param('wf_id');
    my $view = $self->param('view') || '';


    my $wf_info = $self->send_command_v2( 'get_workflow_info',  {
        id => $id,
        with_ui_info => 1,
    }, { nostatus  => 1 });

    if (!$wf_info) {
        $self->status->error('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION') unless $self->status->is_set;
        return $self;
    }

    $self->set_page(
        label => 'I18N_OPENXPKI_UI_WORKFLOW_CONTEXT_LABEL #' . $wf_info->{workflow}->{id},
        large => 1,
    );

    $self->main->add_section({
        type => 'keyvalue',
        content => {
            label => '',
            data => $self->__render_fields( $wf_info, 'context'),
        },
    });

    return $self;

}


=head2 init_attribute

Requires parameter I<wf_id> which is the id of an existing workflow.
Shows the assigned attributes as plain key/value pairs - usually called in a popup.

=cut

sub init_attribute {

    my $self = shift;

    # re-instance existing workflow
    my $id = $self->param('wf_id');
    my $view = $self->param('view') || '';

    my $wf_info = $self->send_command_v2( 'get_workflow_info',  {
        id => $id,
        with_attributes => 1,
        with_ui_info => 1,
    }, { nostatus  => 1 });

    if (!$wf_info) {
        $self->status->error('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION') unless $self->status->is_set;
        return $self;
    }

    $self->set_page(
        label => 'I18N_OPENXPKI_UI_WORKFLOW_ATTRIBUTE_LABEL #' . $wf_info->{workflow}->{id},
        large => 1,
    );

    $self->main->add_section({
        type => 'keyvalue',
        content => {
            label => '',
            data => $self->__render_fields( $wf_info, 'attribute'),
        },
    });

    return $self;

}

=head2 init_info

Requires parameter I<wf_id> which is the id of an existing workflow.
It loads the process information to be displayed in a modal popup, used
mainly from the workflow search / result lists.

=cut

sub init_info {

    my $self = shift;
    my $args = shift;

    # re-instance existing workflow
    my $id = $self->param('wf_id') || $args->{wf_id} || 0;
    $id =~ s/[^\d]//g;

    my $wf_info = $self->send_command_v2( 'get_workflow_info',  {
        id => $id,
        with_ui_info => 1,
    }, { nostatus  => 1 });

    if (!$wf_info) {
         $self->set_page(
            shortlabel => '',
        );
        $self->main->add_section({
            type => 'text',
            content => {
                description => 'I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION',
        }});
        $self->log->warn('Unable to load workflow info for id ' . $id);
        return $self;
    }

    my $fields = $self->__render_workflow_info( $wf_info, $self->session_param('wfdetails') );

    push @{$fields}, {
        label => "I18N_OPENXPKI_UI_FIELD_ERROR_CODE",
        name => "error_code",
        value => $wf_info->{workflow}->{context}->{error_code},
    } if ($wf_info->{workflow}->{context}->{error_code}
        && $wf_info->{workflow}->{proc_state} =~ m{(manual|finished|failed)});

    # The workflow info contains info about all control actions that
    # can be done on the workflow -> render appropriate buttons.
    my @buttons_handle = ({
        href => '#/openxpki/redirect!workflow!load!wf_id!'.$wf_info->{workflow}->{id},
        label => 'I18N_OPENXPKI_UI_WORKFLOW_OPEN_WORKFLOW_LABEL',
        format => "primary",
    });

    # The workflow info contains info about all control actions that
    # can be done on the workflow -> render appropriate buttons.
    if ($wf_info->{handles} && ref $wf_info->{handles} eq 'ARRAY') {
        my @handles = @{$wf_info->{handles}};
        if (grep /context/, @handles) {
            push @buttons_handle, {
                'page' => 'workflow!context!view!result!wf_id!'.$wf_info->{workflow}->{id},
                'label' => 'I18N_OPENXPKI_UI_WORKFLOW_CONTEXT_LABEL',
            };
        }

        if (grep /attribute/, @handles) {
            push @buttons_handle, {
                'page' => 'workflow!attribute!view!result!wf_id!'.$wf_info->{workflow}->{id},
                'label' => 'I18N_OPENXPKI_UI_WORKFLOW_ATTRIBUTE_LABEL',
            };
        }

        if (grep /history/, @handles) {
            push @buttons_handle, {
                'page' => 'workflow!history!view!result!wf_id!'.$wf_info->{workflow}->{id},
                'label' => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_LABEL',
            };
        }

        if (grep /techlog/, @handles) {
            push @buttons_handle, {
                'page' => 'workflow!log!view!result!wf_id!'.$wf_info->{workflow}->{id},
                'label' => 'I18N_OPENXPKI_UI_WORKFLOW_LOG_LABEL',
            };
        }
    }

    my $label = sprintf("%s (#%01d)", ($wf_info->{workflow}->{title} || $wf_info->{workflow}->{label} || $wf_info->{workflow}->{type}), $wf_info->{workflow}->{id});
    $self->set_page(
        shortlabel => $label,
        large => 1,
    );

    my $proc_state = $wf_info->{workflow}->{proc_state};

    $self->main->add_section({
        type => 'keyvalue',
        content => {
            label => $self->__get_proc_state_label($proc_state),
            description => $self->__get_proc_state_desc($proc_state),
            data => $fields,
            buttons => \@buttons_handle,
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

    my $opts = $self->session_param('wfsearch');
    if (!exists $opts->{default}) {
        return $self->redirect->to('home');
    }

    $self->set_page(
        label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_LABEL',
        description => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_DESC',
        breadcrumb => {
            is_root => 1,
            class => 'workflow-search',
        },
    );

    my $workflows = $self->send_command_v2( 'get_workflow_instance_types' );
    return $self unless defined $workflows;
    $self->log->trace('Workflows: ' . Dumper $workflows) if $self->log->is_trace;

    my $preset = $args->{preset} // $self->__wf_search_presets;
    $self->log->trace('Presets: ' . Dumper $preset) if $self->log->is_trace;

    #
    # Search by ID
    #
    $self->main->add_form(
        action => 'workflow!load',
        label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SEARCH_BY_ID_TITLE',
        submit_label => 'I18N_OPENXPKI_UI_SEARCH_SUBMIT_LABEL',
    )->add_field(
        name => 'wf_id',
        label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SERIAL_LABEL',
        type => 'text',
        value => $preset->{wf_id} || '',
        width => 'small',
    );

    #
    # Search by workflow attributes
    #
    my @wf_types = sort { lc($a->{'label'}) cmp lc($b->{'label'}) }
      map { { 'label' => i18nGettext($workflows->{$_}->{label}), 'value' => $_ } }
      keys %{$workflows};

    my $proc_states = [
        sort { lc($a->{label}) cmp lc($b->{label}) }
        map { { 'label' => i18nGettext($self->__get_proc_state_label($_)), 'value' => $_ } }
        grep { $_ ne 'running' }
        keys %{ $self->__proc_state_i18n }
    ];

    my $form = $self->main->add_form(
        action => 'workflow!search',
        label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SEARCH_DATABASE_TITLE',
        submit_label => 'I18N_OPENXPKI_UI_SEARCH_SUBMIT_LABEL',
    )
    ->add_field(
        name => 'wf_type',
        label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_TYPE_LABEL',
        type => 'select',
        is_optional => 1,
        options => \@wf_types,
        value => $preset->{wf_type}
    )
    ->add_field(
        name => 'wf_proc_state',
        label => 'I18N_OPENXPKI_UI_WORKFLOW_PROC_STATE_LABEL',
        type => 'select',
        is_optional => 1,
        prompt => '',
        options => $proc_states,
        value => $preset->{wf_proc_state}
    )
    ->add_field(
        name => 'wf_state',
        label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_STATE_LABEL',
        placeholder => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_STATE_PLACEHOLDER',
        type => 'text',
        is_optional => 1,
        prompt => '',
        value => $preset->{wf_state}
    )
    ->add_field(
        name => 'wf_creator',
        label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_CREATOR_LABEL',
        placeholder => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_CREATOR_PLACEHOLDER',
        type => 'text',
        is_optional => 1,
        value => $preset->{wf_creator}
    )
    ->add_field(
        name => 'last_update',
        label => 'I18N_OPENXPKI_UI_WORKFLOW_LAST_UPDATE_LABEL',
        'keys' => $self->__validity_options(),
        type => 'datetime',
        is_optional => 1,
        value => $preset->{last_update},
    );

    # Searchable attributes are read from the 'uicontrol' config section
    my $attributes = $opts->{default}->{attributes};
    my @meta_descr;
    if ($attributes && (ref $attributes eq 'ARRAY')) {
        my @attrib;
        foreach my $a (@{$attributes}) {
            push @attrib, { value => $a->{key}, label=> $a->{label} };
            push @meta_descr, { label=> $a->{label}, value => $a->{description}, format => 'raw' } if $a->{description};
        }
        unshift @meta_descr, { value => 'I18N_OPENXPKI_UI_WORKFLOW_METADATA_LABEL', format => 'head' } if @meta_descr;
        $form->add_field(
            name => 'attributes',
            label => 'I18N_OPENXPKI_UI_WORKFLOW_METADATA_LABEL',
            placeholder => 'I18N_OPENXPKI_UI_SEARCH_METADATA_PLACEHOLDER',
            'keys' => \@attrib,
            type => 'text',
            is_optional => 1,
            'clonable' => 1,
            'value' => $preset->{attributes} || [],
        ) if scalar @attrib;

    }

    #
    # Hints
    #
    $self->main->add_section({
        type => 'keyvalue',
        content => {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_FIELD_HINT_LIST',
            data => [
              { label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_TYPE_LABEL', value => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_TYPE_HINT', format => 'raw' },
              { label => 'I18N_OPENXPKI_UI_WORKFLOW_PROC_STATE_LABEL', value => 'I18N_OPENXPKI_UI_WORKFLOW_PROC_STATE_HINT', format => 'raw' },
              { label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_STATE_LABEL', value => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_STATE_HINT', format => 'raw' },
              { label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_CREATOR_LABEL', value => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_CREATOR_HINT', format => 'raw' },
              { label => 'I18N_OPENXPKI_UI_WORKFLOW_LAST_UPDATE_LABEL', value => 'I18N_OPENXPKI_UI_WORKFLOW_LAST_UPDATE_HINT', format => 'raw' },
              @meta_descr,
            ]
        }
    });

    return $self;
}

sub __wf_search_presets {
    my $self = shift;
    my $preset;

    if (my $queryid = $self->param('query')) {
        my $result = $self->__load_query(workflow => $queryid);
        $preset = $result->{input} if $result;

    } else {
        $preset = $self->session_param('wfsearch')->{default}->{preset} || {};
        # convert preset for last_update
        foreach my $key (qw(last_update_before last_update_after)) {
            next unless ($preset->{$key});
            $preset->{last_update} = {
                key => $key,
                value => OpenXPKI::DateTime::get_validity({
                    VALIDITY => $preset->{$key},
                    VALIDITYFORMAT => 'detect',
                })->epoch()
            };
        }
    }

    return $preset;
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
    my $cache = $self->__load_query(workflow => $queryid) or return $self->init_search();

    # Add limits
    my $query = $cache->{query};

    if ($limit) {
        $query->{limit} = $limit;
    } elsif (!$query->{limit}) {
        $query->{limit} = 25;
    }

    $query->{start} = $startat;

    if (!$query->{order}) {
        $query->{order} = 'workflow_id';
        if (!defined $query->{reverse}) {
            $query->{reverse} = 1;
        }
    }

    $self->log->trace( "persisted query: " . Dumper $cache) if $self->log->is_trace;

    my $search_result = $self->send_command_v2( 'search_workflow_instances', $query );

    $self->log->trace( "search result: " . Dumper $search_result) if $self->log->is_trace;

    # Add page header from result - optional
    if ($cache->{page} && ref $cache->{page} eq 'HASH') {
        $self->set_page(%{ $cache->{page} });
    } else {
        my $criteria = $cache->{criteria} ? '<br>' . (join ", ", @{$cache->{criteria}}) : '';
        $self->set_page(
            label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_RESULTS_LABEL',
            description => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_RESULTS_DESCRIPTION' . $criteria ,
            breadcrumb => {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_RESULTS_TITLE',
                class => 'workflow-search-result',
            },
        );
    }

    my $pager = $self->__build_pager(
        pagename => $cache->{pagename},
        id => $queryid,
        query => $query,
        count => $cache->{count},
        %{$cache->{pager_args} // {}},
        limit => $query->{limit},
        startat => $query->{start},
    );

    my $body = $cache->{column};
    $body = $self->__default_grid_row() if(!$body);

    my @lines = $self->__render_result_list( $search_result, $body );

    $self->log->trace( "dumper result: " . Dumper \@lines) if $self->log->is_trace;

    my $header = $cache->{header};
    $header = $self->__default_grid_head() if(!$header);

    # buttons - from result (used in bulk) or default
    my @buttons;
    if ($cache->{button} && ref $cache->{button} eq 'ARRAY') {
        @buttons = @{$cache->{button}};
    } else {

        push @buttons, { label => 'I18N_OPENXPKI_UI_SEARCH_REFRESH',
            page => 'redirect!workflow!result!id!' .$queryid,
            format => 'expected' };

        push @buttons, {
            label => 'I18N_OPENXPKI_UI_SEARCH_RELOAD_FORM',
            page => 'workflow!search!query!' .$queryid,
            format => 'alternative',
        } if $cache->{input};

        push @buttons,{ label => 'I18N_OPENXPKI_UI_SEARCH_NEW_SEARCH',
            page => 'workflow!search',
            format => 'failure'};

        push @buttons, { label => 'I18N_OPENXPKI_UI_SEARCH_EXPORT_RESULT',
            href => $self->_client->script_url . '?page=workflow!export!id!'.$queryid,
            target => '_blank',
            format => 'optional'
            };
    }

    $self->main->add_section({
        type => 'grid',
        className => 'workflow',
        content => {
            actions => [{
                page => 'workflow!info!wf_id!{serial}',
                label => 'I18N_OPENXPKI_UI_WORKFLOW_OPEN_WORKFLOW_LABEL',
                icon => 'view',
                target => 'popup',
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

=head2 init_export

Like init_result but send the data as CSV download, default limit is 500!

=cut

sub init_export {

    my $self = shift;
    my $args = shift;

    my $queryid = $self->param('id');

    my $limit = $self->param('limit') || 500;
    my $startat = $self->param('startat') || 0;

    # Safety rule
    if ($limit > 500) {  $limit = 500; }

    # Load query from session
    my $cache = $self->__load_query(workflow => $queryid) or return $self->init_search();

    # Add limits
    my $query = $cache->{query};
    $query->{limit} = $limit;
    $query->{start} = $startat;

    if (!$query->{order}) {
        $query->{order} = 'workflow_id';
        if (!defined $query->{reverse}) {
            $query->{reverse} = 1;
        }
    }

    $self->log->trace( "persisted query: " . Dumper $cache) if $self->log->is_trace;

    my $search_result = $self->send_command_v2( 'search_workflow_instances', $query );

    $self->log->trace( "search cache: " . Dumper $search_result) if $self->log->is_trace;

    my $header = $cache->{header};
    $header = $self->__default_grid_head() if(!$header);

    my @head;
    my @cols;

    my $ii = 0;
    foreach my $col (@{$header}) {
        # skip hidden fields
        if ((!defined $col->{bVisible} || $col->{bVisible}) && $col->{sTitle} !~ /\A_/)  {
            push @head, $col->{sTitle};
            push @cols, $ii;
        }
        $ii++;
    }

    my $buffer = join("\t", @head)."\n";

    my $body = $cache->{column};
    $body = $self->__default_grid_row() if(!$body);

    my @lines = $self->__render_result_list( $search_result, $body );
    my $colcnt = scalar @head - 1;
    foreach my $line (@lines) {
        my @t = @{$line};
        # this hides invisible fields (assumes that hidden fields are always at the end)
        $buffer .= join("\t", @t[0..$colcnt])."\n"
    }

    if (scalar @{$search_result} == $limit) {
        $buffer .= "I18N_OPENXPKI_UI_CERT_EXPORT_EXCEEDS_LIMIT"."\n";
    }

    print $self->cgi()->header(
        -type => 'text/tab-separated-values',
        -expires => "1m",
        -attachment => "workflow export " . DateTime->now()->iso8601() .  ".txt"
    );

    print Encode::encode('UTF-8', i18nTokenizer($buffer));
    exit;

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
    my $cache = $self->__load_query(workflow => $queryid) or return $self->init_search();

    my $startat = $self->param('startat');

    my $limit = $self->param('limit') || 25;

    if ($limit > 500) {  $limit = 500; }

    # align startat to limit window
    $startat = int($startat / $limit) * $limit;

    # Add limits
    my $query = $cache->{query};
    $query->{limit} = $limit;
    $query->{start} = $startat;

    if ($self->param('order')) {
        $query->{order} = uc($self->param('order'));
    }

    if (defined $self->param('reverse')) {
        $query->{reverse} = $self->param('reverse');
    }

    $self->log->trace( "persisted query: " . Dumper $cache) if $self->log->is_trace;
    $self->log->trace( "executed query: " . Dumper $query) if $self->log->is_trace;

    my $search_result = $self->send_command_v2(search_workflow_instances => $query);

    $self->log->trace( "search result: " . Dumper $search_result) if $self->log->is_trace;


    my $body = $cache->{column};
    $body = $self->__default_grid_row() unless $body;

    my @result = $self->__render_result_list( $search_result, $body );

    $self->log->trace( "dumper result: " . Dumper @result) if $self->log->is_trace;

    $self->confined_response({ data => \@result });

    return $self;
}

=head2 init_history

Render the history as grid view (state/action/user/time)

=cut

sub init_history {

    my $self = shift;
    my $args = shift;

    my $id = $self->param('wf_id');
    my $view = $self->param('view') || '';

    $self->set_page(
        label => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_TITLE',
        description => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_DESCRIPTION',
        large => 1,
    );

    my $workflow_history = $self->send_command_v2( 'get_workflow_history', { id => $id } );

    $self->log->trace( "dumper result: " . Dumper $workflow_history) if $self->log->is_trace;

    my $i = 1;
    my @result;
    foreach my $item (@{$workflow_history}) {
        push @result, [
            $item->{'workflow_history_date'},
            $item->{'workflow_state'},
            $item->{'workflow_action'},
            $item->{'workflow_description'},
            $item->{'workflow_user'},
            $item->{'workflow_node'},
        ]
    }

    $self->log->trace( "dumper result: " . Dumper $workflow_history) if $self->log->is_trace;

    $self->main->add_section({
        type => 'grid',
        className => 'workflow',
        content => {
            columns => [
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_EXEC_TIME_LABEL' }, #, format => 'datetime'},
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_STATE_LABEL' },
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_ACTION_LABEL' },
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_DESCRIPTION_LABEL' },
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_USER_LABEL' },
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_NODE_LABEL' },
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

    $self->set_page(
        label => 'I18N_OPENXPKI_UI_MY_WORKFLOW_TITLE',
        description => 'I18N_OPENXPKI_UI_MY_WORKFLOW_DESCRIPTION',
    );

    my $tasklist = $self->session_param('tasklist')->{mine};

    my $default = {
        query => {
            attribute => { 'creator' => $self->session_param('user')->{name} },
            order => 'workflow_id',
            reverse => 1,
        },
        actions => [{
            page => 'workflow!info!wf_id!{serial}',
            label => 'I18N_OPENXPKI_UI_WORKFLOW_OPEN_WORKFLOW_LABEL',
            icon => 'view',
            target => 'popup',
        }]
    };

    if (!$tasklist || ref $tasklist ne 'ARRAY') {
        $self->__render_task_list($default);
    } else {
        foreach my $item (@$tasklist) {
            if ($item->{query}) {
                $item->{query} = { %{$default->{query}}, %{$item->{query}} };
            } else {
                $item->{query} = $default->{query};
            }
            $item->{actions} = $default->{actions} unless($item->{actions});

            $self->__render_task_list($item);
        }
    }

    return $self;

}

=head2 init_task

Outstanding tasks, filter definitions are read from the uicontrol file

=cut

sub init_task {

    my $self = shift;
    my $args = shift;

    $self->page->label('I18N_OPENXPKI_UI_WORKFLOW_OUTSTANDING_TASKS_LABEL');

    my $tasklist = $self->session_param('tasklist')->{default};

    if (!@$tasklist) {
        return $self->redirect->to('home');
    }

    $self->log->trace( "got tasklist: " . Dumper $tasklist) if $self->log->is_trace;

    foreach my $item (@$tasklist) {
        $self->__render_task_list($item);
    }

    return $self;
}


=head2 init_log

Load and display the technical log file of the workflow

=cut

sub init_log {

    my $self = shift;
    my $args = shift;

    my $id = $self->param('wf_id');
    my $view = $self->param('view') || '';

    $self->set_page(
        label => 'I18N_OPENXPKI_UI_WORKFLOW_LOG',
        large => 1,
    );

    my $result = $self->send_command_v2( 'get_workflow_log', { id => $id } );

    $result = [] unless($result);

    $self->log->trace( "dumper result: " . Dumper $result) if $self->log->is_trace;

    $self->main->add_section({
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

=head2 __render_task_list

Expects a hash that defines a workflow query and output rules for a
tasklist as defined in the uicontrol section.

=cut

sub __render_task_list {

    my $self = shift;
    my $item = shift;

    my $query = $item->{query};
    my $limit = 25;

    $query = { $self->__tenant(), %$query } unless($query->{tenant});

    if ($query->{limit}) {
        $limit = $query->{limit};
        delete $query->{limit};
    }

    if (!$query->{order}) {
        $query->{order} = 'workflow_id';
        if (!defined $query->{reverse}) {
            $query->{reverse} = 1;
        }
    }

    my @cols;
    if ($item->{cols}) {
        @cols = @{$item->{cols}};
    } else {
        @cols = (
            { label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SERIAL_LABEL', field => 'workflow_id', sortkey => 'workflow_id' },
            { label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_UPDATED_LABEL', field => 'workflow_last_update', sortkey => 'workflow_last_update' },
            { label => 'I18N_OPENXPKI_UI_WORKFLOW_TYPE_LABEL', field => 'workflow_label' },
            { label => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_LABEL', field => 'workflow_state' },
        );
    }

    my $actions = $item->{actions} // [{ page => 'redirect!workflow!load!wf_id!{serial}', icon => 'view' }];

    # create the header from the columns spec
    my ($header, $column, $rattrib) = $self->__render_list_spec( \@cols );

    if ($rattrib) {
        $query->{return_attributes} = $rattrib;
    }

    $self->log->trace( "columns : " . Dumper $column) if $self->log->is_trace;

    my $search_result = $self->send_command_v2( 'search_workflow_instances', { limit => $limit, %$query } );

    # empty message
    my $empty = $item->{ifempty} || 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL';

    my $pager;
    my @data;
    # No results
    if (!@$search_result) {

        return if ($empty eq 'hide');

    } else {

        @data = $self->__render_result_list( $search_result, $column );

        $self->log->trace( "dumper result: " . Dumper @data) if $self->log->is_trace;

        if ($limit == scalar @$search_result) {
            my %count_query = %{$query};
            delete $count_query{order};
            delete $count_query{reverse};

            my $result_count= $self->send_command_v2( 'search_workflow_instances_count', \%count_query  );

            my $pager_args = OpenXPKI::Util::filter_hash($item->{pager}, qw(limit pagesizes pagersize));

            my $cache = {
                pagename => 'workflow',
                query => $query,
                count => $result_count,
                column => $column,
                pager_args => $pager_args,
            };

            my $queryid = $self->__save_query($cache);

            $pager = $self->__build_pager(
                pagename => 'workflow',
                id => $queryid,
                query => $query,
                count => $result_count,
                limit => $limit,
                %$pager_args,
            );
        }

    }

    $self->main->add_section({
        type => 'grid',
        className => 'workflow',
        content => {
            label => $item->{label},
            description => $item->{description},
            actions => $actions,
            columns => $header,
            data => \@data,
            pager => $pager,
            empty => $empty,

        }
    });

    return \@data
}

__PACKAGE__->meta->make_immutable;
