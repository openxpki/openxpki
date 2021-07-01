package OpenXPKI::Client::UI::Workflow;
use Moose;

# Core modules
use DateTime;
use POSIX;
use Data::Dumper;
use Cache::LRU;
use Digest::SHA qw(sha1_hex);

# CPAN modules
use Log::Log4perl::MDC;
use Date::Parse;
use YAML::Loader;
use Try::Tiny;
use MIME::Base64;
use OpenXPKI::DateTime;
use OpenXPKI::Debug;
use OpenXPKI::i18n qw( i18nTokenizer i18nGettext );


extends 'OpenXPKI::Client::UI::Result';


# used to cache static patterns like the creator lookup
my $template_cache = Cache::LRU->new( size => 256 );


has __default_grid_head => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy => 1,

    default => sub { return [
        { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_SERIAL_LABEL', sortkey => 'workflow_id' },
        { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_UPDATED_LABEL', sortkey => 'workflow_last_update' },
        { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_TYPE_LABEL', sortkey => 'workflow_type'},
        { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_LABEL', sortkey => 'workflow_state' },
        { sTitle => 'serial', bVisible => 0 },
        { sTitle => "_className"},
    ]; }
);

has __default_grid_row => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy => 1,
    default => sub { return [
        { source => 'workflow', field => 'workflow_id' },
        { source => 'workflow', field => 'workflow_last_update' },
        { source => 'workflow', field => 'workflow_type' },
        { source => 'workflow', field => 'workflow_state' },
        { source => 'workflow', field => 'workflow_id' }
    ]; }
);

has __default_wfdetails => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy => 1,
    default => sub { return [
        {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_ID_LABEL',
            field => 'id',
            link => {
                page => 'workflow!load!wf_id![% id %]',
                target => '_blank',
            },
        },
        {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_TYPE_LABEL',
            field => 'type',
        },
        {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_CREATOR_LABEL',
            field => 'creator',
        },
        {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_LABEL',
            template => "[% IF state == 'SUCCESS' %]<b>Success</b>[% ELSE %][% state %][% END %]",
            format => "raw",
        },
        {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_PROC_STATE_LABEL',
            field => 'proc_state',
        },
    ] },
);

has __validity_options => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy => 1,
    default => sub { return [
        { value => 'last_update_before', label => 'I18N_OPENXPKI_UI_WORKFLOW_LAST_UPDATE_BEFORE_LABEL' },
        { value => 'last_update_after', label => 'I18N_OPENXPKI_UI_WORKFLOW_LAST_UPDATE_AFTER_LABEL' },

    ];}
);

has __proc_state_i18n => (
    is => 'ro', isa => 'HashRef', lazy => 1, init_arg => undef,
    default => sub { return {
        # label = short label
        #   - heading for workflow info popup (workflow search results)
        #   - search dropdown
        #   - technical info block on workflow page
        #
        # desc = description
        #   - workflow info popup (workflow search results)
        running => {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_INFO_RUNNING_LABEL',
            desc =>  'I18N_OPENXPKI_UI_WORKFLOW_INFO_RUNNING_DESC',
        },
        manual => {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_INFO_MANUAL_LABEL',
            desc =>  'I18N_OPENXPKI_UI_WORKFLOW_INFO_MANUAL_DESC',
        },
        finished => {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_INFO_FINISHED_LABEL',
            desc =>  'I18N_OPENXPKI_UI_WORKFLOW_INFO_FINISHED_DESC',
        },
        pause => {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_INFO_PAUSE_LABEL',
            desc =>  'I18N_OPENXPKI_UI_WORKFLOW_INFO_PAUSE_DESC',
        },
        exception => {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_INFO_EXCEPTION_LABEL',
            desc =>  'I18N_OPENXPKI_UI_WORKFLOW_INFO_EXCEPTION_DESC',
        },
        retry_exceeded => {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_INFO_RETRY_EXCEEDED_LABEL',
            desc =>  'I18N_OPENXPKI_UI_WORKFLOW_INFO_RETRY_EXCEEDED_DESC',
        },
        archived => {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_INFO_ARCHIVED_LABEL',
            desc =>  'I18N_OPENXPKI_UI_WORKFLOW_INFO_ARCHIVED_DESC',
        },
        failed => {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_INFO_FAILED_LABEL',
            desc =>  'I18N_OPENXPKI_UI_WORKFLOW_INFO_FAILED_DESC',
        },
    } },
);

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

    workflow!index!wf_type!change_metadata

=cut

sub init_index {

    my $self = shift;
    my $args = shift;

    my $wf_info = $self->send_command_v2( 'get_workflow_base_info', {
        type => $self->param('wf_type')
    });

    if (!$wf_info) {
        $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION','error');
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

    my $wf_info = $self->send_command_v2( 'create_workflow_instance', {
       workflow => $self->param('wf_type'), params   => {}, ui_info => 1
    });

    if (!$wf_info) {
        # todo - handle errors
        $self->logger()->error("Create workflow failed");
        return $self;
    }

    $self->logger()->trace("wf info on create: " . Dumper $wf_info ) if $self->logger->is_trace;

    $self->logger()->info(sprintf "Create new workflow %s, got id %01d",  $wf_info->{workflow}->{type}, $wf_info->{workflow}->{id} );

    # this duplicates code from action_index
    if ($wf_info->{workflow}->{id} > 0) {

        my $redirect = 'workflow!load!wf_id!'.$wf_info->{workflow}->{id};
        my @activity = keys %{$wf_info->{activity}};
        if (scalar @activity == 1) {
            $redirect .= '!wf_action!'.$activity[0];
        }
        $self->redirect($redirect);

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
    });

    if (!$wf_info) {
        $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION','error') unless($self->_status());
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
    });

    if (!$wf_info) {
        $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION','error') unless($self->_status());
        return $self;
    }

    $self->_page({
        label => 'I18N_OPENXPKI_UI_WORKFLOW_CONTEXT_LABEL #' . $wf_info->{workflow}->{id},
        isLarge => 1,
    });

    my %buttons;
    %buttons = ( buttons => [{
        page => 'workflow!info!wf_id!'.$wf_info->{workflow}->{id},
        label => 'I18N_OPENXPKI_UI_WORKFLOW_BACK_TO_INFO_LABEL',
        format => "primary",
    }]) if ($view eq 'result');

    $self->add_section({
        type => 'keyvalue',
        content => {
            label => '',
            data => $self->__render_fields( $wf_info, 'context'),
            %buttons
    }});

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
    });

    if (!$wf_info) {
        $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION','error') unless($self->_status());
        return $self;
    }

    $self->_page({
        label => 'I18N_OPENXPKI_UI_WORKFLOW_ATTRIBUTE_LABEL #' . $wf_info->{workflow}->{id},
        isLarge => 1,
    });

    my %buttons;
    %buttons = ( buttons => [{
        page => 'workflow!info!wf_id!'.$wf_info->{workflow}->{id},
        label => 'I18N_OPENXPKI_UI_WORKFLOW_BACK_TO_INFO_LABEL',
        format => "primary",
    }]) if ($view eq 'result');

    $self->add_section({
        type => 'keyvalue',
        content => {
            label => '',
            data => $self->__render_fields( $wf_info, 'attribute'),
            %buttons
    }});

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
    });

    if (!$wf_info) {
        $self->_page({
            label => '',
            shortlabel => '',
            description => 'I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION',
        });
        $self->logger()->warn('Unable to load workflow info for id ' . $id);
        return $self;
    }

    my $fields = $self->__render_workflow_info( $wf_info, $self->_client->session()->param('wfdetails') );

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
    $self->_page({
        label => $label,
        shortlabel => $label,
        description => '',
        isLarge => 1,
    });

    my $proc_state = $wf_info->{workflow}->{proc_state};

    $self->add_section({
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

    $self->_page({
        label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_LABEL',
        description => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_DESC',
    });

    my $workflows = $self->send_command_v2( 'get_workflow_instance_types' );
    return $self unless(defined $workflows);

    $self->logger()->trace('Workflows ' . Dumper $workflows) if $self->logger->is_trace;

    my $preset = $self->_session->param('wfsearch')->{default}->{preset} || {};
    # convert preset for last_update
    foreach my $key (qw(last_update_before last_update_after)) {
        next unless ($preset->{$key});
        $preset->{last_update} = {
            key => $key,
            value => OpenXPKI::DateTime::get_validity({
                VALIDITY => $preset->{$key},
                VALIDITYFORMAT => 'detect'
            })->epoch()
        };
    }

    if ($args->{preset}) {
        $preset = $args->{preset};

    } elsif (my $queryid = $self->param('query')) {
        my $result = $self->_client->session()->param('query_wfl_'.$queryid);
        $preset = $result->{input};
    }

    $self->logger()->trace('Preset ' . Dumper $preset) if $self->logger->is_trace;

    # TODO Sorting / I18
    my @wf_names = keys %{$workflows};
    my @wfl_list = map { {'value' => $_, 'label' => $workflows->{$_}->{label}} } @wf_names ;
    @wfl_list = sort { lc($a->{'label'}) cmp lc($b->{'label'}) } @wfl_list;

    my $proc_states = [
        sort { $a->{label} cmp $b->{label} }
        map { { label => i18nGettext($self->__get_proc_state_label($_)), value => $_} }
        grep { $_ ne 'running' }
        keys %{ $self->__proc_state_i18n }
    ];

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
          options => $proc_states,
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
        },
        { name => 'last_update',
          label => 'I18N_OPENXPKI_UI_WORKFLOW_LAST_UPDATE_LABEL',
          'keys' => $self->__validity_options(),
          type => 'datetime',
          is_optional => 1,
          value => $preset->{last_update},
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

    $self->logger()->trace( "persisted query: " . Dumper $result) if $self->logger->is_trace;

    my $search_result = $self->send_command_v2( 'search_workflow_instances', $query );

    $self->logger()->trace( "search result: " . Dumper $search_result) if $self->logger->is_trace;

    # Add page header from result - optional
    if ($result->{page} && ref $result->{page} ne 'HASH') {
        $self->_page($result->{page});
    } else {
        my $criteria = $result->{criteria} ? '<br>' . (join ", ", @{$result->{criteria}}) : '';
        $self->_page({
            label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_RESULTS_LABEL',
            description => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_RESULTS_DESCRIPTION' . $criteria ,
            breadcrumb => [
                { label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_LABEL', className => 'workflow-search' },
                { label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_RESULTS_TITLE', className => 'workflow-search-result' }
            ],
        });
    }

    my $pager_args = $result->{pager} || {};

    my $pager = $self->__render_pager( $result, { %$pager_args, limit => $query->{limit}, startat => $query->{start} } );

    my $body = $result->{column};
    $body = $self->__default_grid_row() if(!$body);

    my @lines = $self->__render_result_list( $search_result, $body );

    $self->logger()->trace( "dumper result: " . Dumper \@lines) if $self->logger->is_trace;

    my $header = $result->{header};
    $header = $self->__default_grid_head() if(!$header);

    # buttons - from result (used in bulk) or default
    my @buttons;
    if ($result->{button} && ref $result->{button} eq 'ARRAY') {
        @buttons = @{$result->{button}};
    } else {

        push @buttons, { label => 'I18N_OPENXPKI_UI_SEARCH_REFRESH',
            page => 'redirect!workflow!result!id!' .$queryid,
            format => 'expected' };

        push @buttons, {
            label => 'I18N_OPENXPKI_UI_SEARCH_RELOAD_FORM',
            page => 'workflow!search!query!' .$queryid,
            format => 'alternative',
        } if ($result->{input});

        push @buttons,{ label => 'I18N_OPENXPKI_UI_SEARCH_NEW_SEARCH',
            page => 'workflow!search',
            format => 'failure'};

        push @buttons, { label => 'I18N_OPENXPKI_UI_SEARCH_EXPORT_RESULT',
            href => $self->_client()->_config()->{'scripturl'} . '?page=workflow!export!id!'.$queryid,
            target => '_blank',
            format => 'optional'
            };
    }

    $self->add_section({
        type => 'grid',
        className => 'workflow',
        content => {
            actions => [{
                path => 'workflow!info!wf_id!{serial}',
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
    my $result = $self->_client->session()->param('query_wfl_'.$queryid);

    # result expired or broken id
    if (!$result || !$result->{count}) {
        $self->set_status('I18N_OPENXPKI_UI_SEARCH_RESULT_EXPIRED_OR_EMPTY','error');
        return $self->init_search();
    }

    # Add limits
    my $query = $result->{query};
    $query->{limit} = $limit;
    $query->{start} = $startat;

    if (!$query->{order}) {
        $query->{order} = 'workflow_id';
        if (!defined $query->{reverse}) {
            $query->{reverse} = 1;
        }
    }

    $self->logger()->trace( "persisted query: " . Dumper $result) if $self->logger->is_trace;

    my $search_result = $self->send_command_v2( 'search_workflow_instances', $query );

    $self->logger()->trace( "search result: " . Dumper $search_result) if $self->logger->is_trace;

    my $header = $result->{header};
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

    my $body = $result->{column};
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

    print i18nTokenizer($buffer);
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
    $query->{limit} = $limit;
    $query->{start} = $startat;

    if ($self->param('order')) {
        $query->{order} = uc($self->param('order'));
    }

    if (defined $self->param('reverse')) {
        $query->{reverse} = $self->param('reverse');
    }

    $self->logger()->trace( "persisted query: " . Dumper $result) if $self->logger->is_trace;
    $self->logger()->trace( "executed query: " . Dumper $query) if $self->logger->is_trace;

    my $search_result = $self->send_command_v2( 'search_workflow_instances', $query );

    $self->logger()->trace( "search result: " . Dumper $search_result) if $self->logger->is_trace;


    my $body = $result->{column};
    $body = $self->__default_grid_row() if(!$body);

    my @result = $self->__render_result_list( $search_result, $body );

    $self->logger()->trace( "dumper result: " . Dumper @result) if $self->logger->is_trace;

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
    my $view = $self->param('view') || '';

    $self->_page({
        label => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_TITLE',
        description => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_DESCRIPTION',
        isLarge => 1,
    });

    my $workflow_history = $self->send_command_v2( 'get_workflow_history', { id => $id } );

    my %buttons;
    %buttons = ( buttons => [{
        page => 'workflow!info!wf_id!'.$id,
        label => 'I18N_OPENXPKI_UI_WORKFLOW_BACK_TO_INFO_LABEL',
        format => "primary",
    }]) if ($view eq 'result');

    $self->logger()->trace( "dumper result: " . Dumper $workflow_history) if $self->logger->is_trace;

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

    $self->logger()->trace( "dumper result: " . Dumper $workflow_history) if $self->logger->is_trace;

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
                { sTitle => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_NODE_LABEL' },
            ],
            data => \@result,
            %buttons,
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

    $self->_page({
        label => 'I18N_OPENXPKI_UI_MY_WORKFLOW_TITLE',
        description => 'I18N_OPENXPKI_UI_MY_WORKFLOW_DESCRIPTION',
    });

    my $tasklist = $self->_client->session()->param('tasklist')->{mine};

    my $default = {
        query => {
            attribute => { 'creator' => $self->_session->param('user')->{name} },
            order => 'workflow_id',
            reverse => 1,
        },
        actions => [{
            path => 'workflow!info!wf_id!{serial}',
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

    $self->_page({
        label => 'I18N_OPENXPKI_UI_WORKFLOW_OUTSTANDING_TASKS_LABEL'
    });

    my $tasklist = $self->_client->session()->param('tasklist')->{default};

    if (!@$tasklist) {
        return $self->redirect('home');
    }

    $self->logger()->trace( "got tasklist: " . Dumper $tasklist) if $self->logger->is_trace;

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

    $self->_page({
        label => 'I18N_OPENXPKI_UI_WORKFLOW_LOG',
        isLarge => 1,
    });

    my $result = $self->send_command_v2( 'get_workflow_log', { id => $id } );

    my %buttons;
    %buttons = ( buttons => [{
        page => 'workflow!info!wf_id!'.$id,
        label => 'I18N_OPENXPKI_UI_WORKFLOW_BACK_TO_INFO_LABEL',
        format => "primary",
    }]) if ($view eq 'result');

    $result = [] unless($result);

    $self->logger()->trace( "dumper result: " . Dumper $result) if $self->logger->is_trace;

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
            %buttons,
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

    $self->logger()->trace( "wf args: " . Dumper $wf_args) if $self->logger->is_trace;

    # check for delegation
    if ($wf_args->{wf_handler}) {
        return $self->__delegate_call($wf_args->{wf_handler}, $args);
    }

    my %wf_param;
    if ($wf_args->{wf_fields}) {
        %wf_param = %{$self->param_from_fields( $wf_args->{wf_fields} )};
        $self->logger()->trace( "wf fields: " . Dumper \%wf_param ) if $self->logger->is_trace;
    }

    # take over params from token, if any
    if($wf_args->{wf_param}) {
        %wf_param = (%wf_param, %{$wf_args->{wf_param}});
    }

    $self->logger()->trace( "wf params: " . Dumper \%wf_param ) if $self->logger->is_trace;
    ##! 64: "wf params: " . Dumper \%wf_param

    if ($wf_args->{wf_id}) {

        if (!$wf_args->{wf_action}) {
            $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_INVALID_REQUEST_NO_ACTION!','error');
            return $self;
        }
        Log::Log4perl::MDC->put('wfid', $wf_args->{wf_id});
        $self->logger()->info(sprintf "Run %s on workflow #%01d", $wf_args->{wf_action}, $wf_args->{wf_id} );

        # send input data to workflow
        $wf_info = $self->send_command_v2( 'execute_workflow_activity', {
            id       => $wf_args->{wf_id},
            activity => $wf_args->{wf_action},
            params   => \%wf_param,
            ui_info => 1
        });

        if (!$wf_info) {

            if ($self->__check_for_validation_error()) {
                return $self;
            }

            $self->logger()->error("workflow acton failed!");
            my $extra = { wf_id => $wf_args->{wf_id}, wf_action => $wf_args->{wf_action} };
            $self->init_load($extra);
            return $self;
        }

        $self->logger()->trace("wf info after execute: " . Dumper $wf_info ) if $self->logger->is_trace;
        # purge the workflow token
        $self->__purge_wf_token( $wf_token );

    } elsif ($wf_args->{wf_type}) {

        $wf_info = $self->send_command_v2( 'create_workflow_instance', {
            workflow => $wf_args->{wf_type}, params => \%wf_param, ui_info => 1
        });
        if (!$wf_info) {

            if ($self->__check_for_validation_error()) {
                return $self;
            }

            $self->logger()->error("Create workflow failed");
            # pass required arguments via extra and reload init page

            my $extra = { wf_type => $wf_args->{wf_type} };
            $self->init_index($extra);
            return $self;
        }
        $self->logger()->trace("wf info on create: " . Dumper $wf_info ) if $self->logger->is_trace;

        $self->logger()->info(sprintf "Create new workflow %s, got id %01d",  $wf_args->{wf_type}, $wf_info->{workflow}->{id} );

        # purge the workflow token
        $self->__purge_wf_token( $wf_token );

        # always redirect after create to have the url pointing to the created workflow
        # do not redirect for "one shot workflows" or workflows already in a final state
        # as they might hold volatile data (e.g. key download)
        my $proc_state = $wf_info->{workflow}->{proc_state};

        $wf_args->{redirect} = (
            $wf_info->{workflow}->{id} > 0
            and $proc_state ne 'finished'
            and $proc_state ne 'archived'
        );

    } else {
        $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_INVALID_REQUEST_NO_ACTION!','error');
        return $self;
    }


    # Check if we can auto-load the next available action
    my $wf_action;
    if ($wf_info->{state}->{autoselect}) {
        $wf_action = $wf_info->{state}->{autoselect};
        $self->logger()->debug("Autoselect set: $wf_action");
    } else {
        $wf_action = $self->__get_next_auto_action($wf_info);
    }

    # If we call the token action from within a result list we want
    # to "break out" and set the new url instead rendering the result inline
    if ($wf_args->{redirect}) {
        # Check if we can auto-load the next available action
        my $redirect = 'workflow!load!wf_id!'.$wf_info->{workflow}->{id};
        if ($wf_action) {
            $redirect .= '!wf_action!'.$wf_action;
        }
        $self->redirect($redirect);
        return $self;
    }

    if ($wf_action) {
        $self->__render_from_workflow({ wf_info => $wf_info, wf_action => $wf_action });
    } else {
        $self->__render_from_workflow({ wf_info => $wf_info });
    }

    return $self;

}

=head2 action_handle

Execute a workflow internal action (fail, resume, wakeup, archive). Requires
the workflow and action to be set in the wf_token info.

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

    my $handle = $wf_args->{wf_handle};

    if (!$wf_args->{wf_handle}) {
        $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_INVALID_REQUEST_HANDLE_WITHOUT_ACTION!','error');
        return $self;
    }

    Log::Log4perl::MDC->put('wfid', $wf_args->{wf_id});


    if ('fail' eq $handle) {
        $self->logger()->info(sprintf "Workflow %01d set to failure by operator", $wf_args->{wf_id} );

        $wf_info = $self->send_command_v2( 'fail_workflow', {
            id => $wf_args->{wf_id},
        });
    } elsif ('wakeup' eq $handle) {
        $self->logger()->info(sprintf "Workflow %01d trigger wakeup", $wf_args->{wf_id} );
        $wf_info = $self->send_command_v2( 'wakeup_workflow', {
            id => $wf_args->{wf_id}, async => 1, wait => 1
        });
    } elsif ('resume' eq $handle) {
        $self->logger()->info(sprintf "Workflow %01d trigger resume", $wf_args->{wf_id} );
        $wf_info = $self->send_command_v2( 'resume_workflow', {
            id => $wf_args->{wf_id}, async => 1, wait => 1
        });
    } elsif ('reset' eq $handle) {
        $self->logger()->info(sprintf "Workflow %01d trigger reset", $wf_args->{wf_id} );
        $wf_info = $self->send_command_v2( 'reset_workflow', {
            id => $wf_args->{wf_id}
        });
    } elsif ('archive' eq $handle) {
        $self->logger()->info(sprintf "Workflow %01d trigger archive", $wf_args->{wf_id} );
        $wf_info = $self->send_command_v2( 'archive_workflow', {
            id => $wf_args->{wf_id}
        });
    }

    $self->__render_from_workflow({ wf_info => $wf_info });

    return $self;

}

=head2 action_load

Load a workflow given by wf_id, redirects to init_load

=cut

sub action_load {

    my $self = shift;
    my $args = shift;

    $self->redirect('workflow!load!wf_id!'.$self->param('wf_id').'!_seed!'.time() );
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
        if (!$wf_id) {
            $self->logger()->error('No workflow id given');
            $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION','error');
            return $self;
        }
    }

    Log::Log4perl::MDC->put('wfid', $wf_id);
    my $wf_info = $self->send_command_v2( 'get_workflow_info', {
        id => $wf_id,
        with_ui_info => 1,
    });
    $self->logger()->trace('wf_info ' . Dumper  $wf_info) if $self->logger->is_trace;

    if (!$wf_info) {
        $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION','error');
        return $self;
    }

    # If the activity has no fields and no ui class we proceed immediately
    # FIXME - really a good idea - intentional stop items without fields?
    my $wf_action_info = $wf_info->{activity}->{$wf_action};
    $self->logger()->trace('wf_action_info ' . Dumper  $wf_action_info) if $self->logger->is_trace;
    if ((!$wf_action_info->{field} || (scalar @{$wf_action_info->{field}}) == 0) &&
        !$wf_action_info->{uihandle}) {

        $self->logger()->debug('activity has no input - execute');

        # send input data to workflow
        $wf_info = $self->send_command_v2( 'execute_workflow_activity', {
            id       => $wf_info->{workflow}->{id},
            activity => $wf_action,
            ui_info  => 1
        });

        $args->{wf_action} = $self->__get_next_auto_action($wf_info);

    } else {

        $args->{wf_action} = $wf_action;
    }

    $args->{wf_info} = $wf_info;

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
    my $verbose = {};
    my $input;

    if (my $type = $self->param('wf_type')) {
        $query->{type} = $type;
        $input->{wf_type} = $type;
        $verbose->{wf_type} = $type;
    }

    if (my $state = $self->param('wf_state')) {
        $query->{state} = $state;
        $input->{wf_state} = $state;
        $verbose->{wf_state} = $state;
    }

    if (my $proc_state = $self->param('wf_proc_state')) {
        $query->{proc_state} = $proc_state;
        $input->{wf_proc_state} = $proc_state;
        $verbose->{wf_proc_state} = $self->__get_proc_state_label($proc_state);
    }

    if (my $last_update_before = $self->param('last_update_before')) {
        $query->{last_update_before} = $last_update_before;
        $input->{last_update} = { key => 'last_update_before', value => $last_update_before };
        $verbose->{last_update_before} = DateTime->from_epoch( epoch => $last_update_before )->iso8601();
    }

    if (my $last_update_after = $self->param('last_update_after')) {
        $query->{last_update_after} = $last_update_after;
        $input->{last_update} = { key => 'last_update_after', value => $last_update_after };
        $verbose->{last_update_after} = DateTime->from_epoch( epoch => $last_update_after )->iso8601();
    }

    # Read the query pattern for extra attributes from the session
    my $spec = $self->_session->param('wfsearch')->{default};
    my $attr = $self->__build_attribute_subquery( $spec->{attributes} );

    if (my $wf_creator = $self->param('wf_creator')) {
        $input->{wf_creator} = $wf_creator;
        $attr->{'creator'} = scalar $wf_creator;
        $verbose->{wf_creator} = $wf_creator;
    }

    if ($attr) {
        $input->{attributes} = $self->__build_attribute_preset(  $spec->{attributes} );
        $query->{attribute} = $attr;
    }

    # check if there is a custom column set defined
    my ($header,  $body, $rattrib);
    if ($spec->{cols} && ref $spec->{cols} eq 'ARRAY') {
        ($header, $body, $rattrib) = $self->__render_list_spec( $spec->{cols} );
    } else {
        $body = $self->__default_grid_row;
        $header = $self->__default_grid_head;
    }

    $query->{return_attributes} = $rattrib if ($rattrib);

    $self->logger()->trace("query : " . Dumper $query) if $self->logger->is_trace;

    my $result_count = $self->send_command_v2( 'search_workflow_instances_count', $query );

    # No results founds
    if (!$result_count) {
        $self->set_status('I18N_OPENXPKI_UI_SEARCH_HAS_NO_MATCHES','error');
        return $self->init_search({ preset => $input });
    }


    my @criteria;
    foreach my $item ((
        { name => 'wf_type', label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_TYPE_LABEL' },
        { name => 'wf_proc_state', label => 'I18N_OPENXPKI_UI_WORKFLOW_PROC_STATE_LABEL' },
        { name => 'wf_state', label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_STATE_LABEL' },
        { name => 'wf_creator', label => 'I18N_OPENXPKI_UI_WORKFLOW_SEARCH_CREATOR_LABEL'}
        )) {
        my $val = $verbose->{ $item->{name} };
        next unless ($val);
        $val =~ s/[^\w\s*\,]//g;
        push @criteria, sprintf '<nobr><b>%s:</b> <i>%s</i></nobr>', $item->{label}, $val;
    }

    foreach my $item (@{$self->__validity_options()}) {
        my $val = $verbose->{ $item->{value} };
        next unless ($val);
        push @criteria, sprintf '<nobr><b>%s:</b> <i>%s</i></nobr>', $item->{label}, $val;
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
        'pager'  => $spec->{pager} || {},
        'criteria' => \@criteria
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

    my $wf_token = $self->param('wf_token') || '';
    if (!$wf_token) {
        $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_INVALID_REQUEST_ACTION_WITHOUT_TOKEN!','error');
        return $self;
    }

    # token contains the name of the action to do and extra params
    my $wf_args = $self->__fetch_wf_token( $wf_token );
    if (!$wf_args->{wf_action}) {
        $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_INVALID_REQUEST_HANDLE_WITHOUT_ACTION!','error');
        return $self;
    }

    $self->logger()->trace('Doing bulk with arguments: '. Dumper $wf_args) if $self->logger->is_trace;

    # wf_token is also used as name of the form field
    my @serials = $self->param($wf_token);

    my @success; # list of wf_info results
    my $errors; # hash with wf_id => error

    my ($command, %params);
    if ($wf_args->{wf_action} =~ m{(fail|wakeup|resume|reset)}) {
        $command = $wf_args->{wf_action}.'_workflow';
        %params = %{$wf_args->{params}} if ($wf_args->{params});
    } elsif ($wf_args->{wf_action} =~ m{\w+_\w+}) {
        $command = 'execute_workflow_activity';
        $params{activity} = $wf_args->{wf_action};
        $params{params} = %{$wf_args->{params}} if ($wf_args->{params});
    }
    # run in background
    $params{async} = 1 if ($wf_args->{async});


    if (!$command) {
        $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_INVALID_REQUEST_HANDLE_WITHOUT_ACTION!','error');
        return $self;
    }

    $self->logger()->debug("Run command $command on workflows " . join(", ", @serials));

    $self->logger()->trace('Execute parameters ' . Dumper \%params) if ($self->logger()->is_trace);

    foreach my $id (@serials) {

        my $wf_info;
        eval {
            $wf_info = $self->send_command_v2( $command , { id => $id, %params } );
        };

        # send_command returns undef if there is an error which usually means
        # that the action was not successful. We can slurp the verbose error
        # from the result status item and display it in the table
        if (!$wf_info) {
            $errors->{$id} = $self->_status()->{message} || 'I18N_OPENXPKI_UI_APPLICATION_ERROR';
        } else {
            push @success, $wf_info;
            $self->logger()->trace('Result on '.$id.': '. Dumper $wf_info) if $self->logger->is_trace;
        }
    }

    $self->_page({
        label => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_RESULT_LABEL',
        description => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_RESULT_DESC',
    });

    if ($errors) {

        $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_BULK_RESULT_HAS_FAILED_ITEMS_STATUS', 'error');

        my @failed_id = keys %{$errors};
        my $failed_result = $self->send_command_v2( 'search_workflow_instances', { id => \@failed_id } );

        my @result_failed = $self->__render_result_list( $failed_result, $self->__default_grid_row );

        # push the error to the result
        my $pos_serial = 4;
        my $pos_state = 3;
        map {
            my $serial = $_->[ $pos_serial ];
            $_->[ $pos_state ] = $errors->{$serial};
        } @result_failed;

        $self->logger()->trace('Mangled failed result: '. Dumper \@result_failed) if $self->logger->is_trace;

        my @fault_head = @{$self->__default_grid_head};
        $fault_head[$pos_state] = { sTitle => 'Error' };

        $self->add_section({
            type => 'grid',
            className => 'workflow',
            content => {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_RESULT_FAILED_ITEMS_LABEL',
                description => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_RESULT_FAILED_ITEMS_DESC',
                actions => [{
                    path => 'workflow!info!wf_id!{serial}',
                    label => 'I18N_OPENXPKI_UI_WORKFLOW_OPEN_WORKFLOW_LABEL',
                    icon => 'view',
                    target => 'popup',
                }],
                columns => \@fault_head,
                data => \@result_failed,
                empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
            }
        });
    } else {
        $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_BULK_RESULT_ACTION_SUCCESS_STATUS', 'success');
    }

    if (@success) {

        my @result_done = $self->__render_result_list( \@success, $self->__default_grid_row );

        $self->add_section({
            type => 'grid',
            className => 'workflow',
            content => {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_RESULT_SUCCESS_ITEMS_LABEL',
                description => $params{async} ?
                    'I18N_OPENXPKI_UI_WORKFLOW_BULK_RESULT_ASYNC_ITEMS_DESC' :
                    'I18N_OPENXPKI_UI_WORKFLOW_BULK_RESULT_SUCCESS_ITEMS_DESC',
                actions => [{
                    path => 'workflow!info!wf_id!{serial}',
                    label => 'I18N_OPENXPKI_UI_WORKFLOW_OPEN_WORKFLOW_LABEL',
                    icon => 'view',
                    target => 'popup',
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
        'query' => { id => \@serials },
    });

    $self->add_section({
        type => 'text',
        content => {
            buttons => [{
                label => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_RECHECK_BUTTON',
                page => 'redirect!workflow!result!id!' .$queryid,
                format => 'expected',
            }]
        }
    });

}

=head1 internal methods

=head2 __render_from_workflow ( { wf_id, wf_info, wf_action }  )

Internal method that renders the ui components from the current workflow state.
The info about the current workflow can be passed as a workflow info hash as
returned by the get_workflow_info api method or simply the workflow
id. In states with multiple action, the wf_action parameter can tell
the method to proceed with this state.

=head3 activity selection

If a state has multiple available activities, and no activity is given via
wf_action, the page includes the content of the description tag of the state
(or the workflow) and a list of buttons rendered from the description of the
available actions. For actions without a description tag, the action name is
used. If a user clicks one of the buttons, the call gets dispatched to the
action_select method.

=head3 activity rendering

If the state has only one available activity or wf_action is given, the method
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

    $self->logger()->trace( "render args: " . Dumper $args) if $self->logger->is_trace;

    my $wf_info = $args->{wf_info} || undef;
    my $view = $args->{view} || '';

    if (!$wf_info && $args->{id}) {
        $wf_info = $self->send_command_v2( 'get_workflow_info', {
            id => $args->{id},
            with_ui_info => 1,
        });
        $args->{wf_info} = $wf_info;
    }

    $self->logger()->trace( "wf_info: " . Dumper $wf_info) if $self->logger->is_trace;
    if (!$wf_info) {
        $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_UNABLE_TO_LOAD_WORKFLOW_INFORMATION','error');
        return $self;
    }

    # delegate handling to custom class
    if ($wf_info->{state}->{uihandle}) {
        return $self->__delegate_call($wf_info->{state}->{uihandle}, $args);
    }

    my $wf_action;
    if($args->{wf_action}) {
        if (!$wf_info->{activity}->{$args->{wf_action}}) {
            $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_REQUESTED_ACTION_NOT_AVAILABLE','warn');
        } else {
            $wf_action = $args->{wf_action};
        }
    }

    my $wf_proc_state = $wf_info->{workflow}->{proc_state} || 'init';

    # add buttons for manipulative handles (wakeup, fail, reset, resume)
    # to be added to the default button list

    my @handles;
    my @buttons_handle;
    if ($wf_info->{handles} && ref $wf_info->{handles} eq 'ARRAY') {
        @handles = @{$wf_info->{handles}};

        $self->logger()->debug('Adding global actions ' . join('/', @handles));

        if (grep /\A wakeup \Z/x, @handles) {
            my $token = $self->__register_wf_token( $wf_info, { wf_handle => 'wakeup' } );
            push @buttons_handle, {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_WAKEUP_BUTTON',
                action => 'workflow!handle!wf_token!'.$token->{value},
                format => 'exceptional'
            }
        }

        if (grep /\A resume \Z/x, @handles) {
            my $token = $self->__register_wf_token( $wf_info, { wf_handle => 'resume' } );
            push @buttons_handle, {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_RESUME_BUTTON',
                action => 'workflow!handle!wf_token!'.$token->{value},
                format => 'exceptional'
            };
        }

        if (grep /\A reset \Z/x, @handles) {
            my $token = $self->__register_wf_token( $wf_info, { wf_handle => 'reset' } );
            push @buttons_handle, {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_RESET_BUTTON',
                action => 'workflow!handle!wf_token!'.$token->{value},
                format => 'reset',
                confirm => {
                    label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_RESET_DIALOG_LABEL',
                    description => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_RESET_DIALOG_TEXT',
                    confirm_label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_RESET_DIALOG_CONFIRM_BUTTON',
                    cancel_label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_RESET_DIALOG_CANCEL_BUTTON',
                }
            };
        }

        if (grep /\A fail \Z/x, @handles) {
            my $token = $self->__register_wf_token( $wf_info, { wf_handle => 'fail' } );
            push @buttons_handle, {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_FAILURE_BUTTON',
                action => 'workflow!handle!wf_token!'.$token->{value},
                format => 'failure',
                confirm => {
                    label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_FAILURE_DIALOG_LABEL',
                    description => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_FAILURE_DIALOG_TEXT',
                    confirm_label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_FAILURE_DIALOG_CONFIRM_BUTTON',
                    cancel_label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_FAILURE_DIALOG_CANCEL_BUTTON',
                }
            };
        }

        if (grep /\A archive \Z/x, @handles) {
            my $token = $self->__register_wf_token( $wf_info, { wf_handle => 'archive' } );
            push @buttons_handle, {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_ARCHIVING_BUTTON',
                action => 'workflow!handle!wf_token!'.$token->{value},
                format => 'exceptional',
                confirm => {
                    label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_ARCHIVING_DIALOG_LABEL',
                    description => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_ARCHIVING_DIALOG_TEXT',
                    confirm_label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_ARCHIVING_DIALOG_CONFIRM_BUTTON',
                    cancel_label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_ARCHIVING_DIALOG_CANCEL_BUTTON',
                }
            };
        }
    }

    # we set the breadcrumb only if the workflow has a title set
    # fallback to label if title is not DEFINED is done in the API
    # setting title to the empty string will suppress breadcrumbs
    my @breadcrumb;
    if ($wf_info->{workflow}->{title}) {
        if ($wf_info->{workflow}->{id}) {
            push @breadcrumb, {
                className => 'workflow-type' ,
                label => sprintf("%s (#%01d)", $wf_info->{workflow}->{title}, $wf_info->{workflow}->{id})
            };
        } elsif ($wf_info->{workflow}->{state} eq 'INITIAL') {
            push @breadcrumb, {
                className => 'workflow-type',
                label => sprintf("%s", $wf_info->{workflow}->{title})
            };
        }
    }

    # helper sub to render the pages description text from state/action using a template
    my $templated_description = sub {
        my $page_def = shift;
        my $description;
        if ($page_def->{template}) {
            my $user = $self->_client->session()->param('user');
            $description = $self->send_command_v2( 'render_template', {
                template => $page_def->{template}, params => {
                    context => $wf_info->{workflow}->{context},
                    user => { name => $user->{name},  role => $user->{role} },
                },
            });
        }
        return  $description || $page_def->{description} || '';
    };

    # show buttons to proceed with workflow if it's in "non-regular" state
    my %irregular = (
        running => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_RUNNING_DESC',
        pause => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_PAUSE_DESC',
        exception => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_EXCEPTION_DESC',
        retry_exceeded => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_RETRY_EXCEEDED_DESC',
    );
    if ($irregular{$wf_proc_state}) {

        # same page head for all proc states
        my $wf_action = $wf_info->{workflow}->{context}->{wf_current_action};
        my $wf_action_info = $wf_info->{activity}->{ $wf_action };

        if (@breadcrumb && $wf_info->{state}->{label}) {
            push @breadcrumb, { className => 'workflow-state', label => $wf_info->{state}->{label} };
        }

        my $label = $self->__get_proc_state_label($wf_proc_state); # reuse labels from init_info popup
        my $desc = $irregular{$wf_proc_state};

        $self->_page({
            label => $label,
            breadcrumb => \@breadcrumb,
            shortlabel => $wf_info->{workflow}->{id},
            description => $desc,
            className => 'workflow workflow-proc-state workflow-proc-'.$wf_proc_state,
            ($wf_info->{workflow}->{id} ? (canonical_uri => 'workflow!load!wf_id!'.$wf_info->{workflow}->{id}) : ()),
        });

        my @buttons;
        my @fields;
        # Check if the workflow is in pause or exceeded
        if (grep /$wf_proc_state/, ('pause','retry_exceeded')) {

            @fields = ({
                label => 'I18N_OPENXPKI_UI_WORKFLOW_LAST_UPDATE_LABEL',
                value => str2time($wf_info->{workflow}->{last_update}.' GMT'),
                'format' => 'timestamp'
            }, {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_WAKEUP_AT_LABEL',
                value => $wf_info->{workflow}->{wake_up_at},
                'format' => 'timestamp'
            }, {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_COUNT_TRY_LABEL',
                value => $wf_info->{workflow}->{count_try}
            }, {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_PAUSE_REASON_LABEL',
                value => $wf_info->{workflow}->{context}->{wf_pause_msg}
            });

            if ($wf_proc_state eq 'pause') {

                # If wakeup is less than 300 seconds away, we schedule an
                # automated reload of the page
                my $to_sleep = $wf_info->{workflow}->{wake_up_at} - time();
                if ($to_sleep < 30) {
                    $self->refresh('workflow!load!wf_id!'.$wf_info->{workflow}->{id}, 30);
                    $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_STATE_WATCHDOG_PAUSED_30SEC','info');
                } elsif ($to_sleep < 300) {
                    $self->refresh('workflow!load!wf_id!'.$wf_info->{workflow}->{id}, $to_sleep + 30);
                    $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_STATE_WATCHDOG_PAUSED_5MIN','info');
                } else {
                    $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_STATE_WATCHDOG_PAUSED','info');
                }

                @buttons = ({
                    page => 'redirect!workflow!load!wf_id!'.$wf_info->{workflow}->{id},
                    label => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_WATCHDOG_PAUSED_RECHECK_BUTTON',
                    format => 'alternative'
                });
                push @fields, {
                    label => 'I18N_OPENXPKI_UI_WORKFLOW_PAUSED_ACTION_LABEL',
                    value => $wf_action_info->{label}
                };
            } else {
                $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_STATE_WATCHDOG_RETRY_EXCEEDED','error');
                push @fields, {
                    label => 'I18N_OPENXPKI_UI_WORKFLOW_EXCEPTION_FAILED_ACTION_LABEL',
                    value => $wf_action_info->{label}
                };
            }

            # if there are output rules defined, we add them now
            if ( $wf_info->{state}->{output} ) {
                push @fields, @{$self->__render_fields( $wf_info, $view )};
            }

        # if the workflow is currently runnig, show info without buttons
        } elsif ($wf_proc_state eq 'running') {

            $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_STATE_RUNNING_LABEL','info');

            @fields = ({
                    label => 'I18N_OPENXPKI_UI_WORKFLOW_LAST_UPDATE_LABEL',
                    value => str2time($wf_info->{workflow}->{last_update}.' GMT'),
                    format => 'timestamp'
                }, {
                    label => 'I18N_OPENXPKI_UI_WORKFLOW_ACTION_RUNNING_LABEL',
                    value => ($wf_info->{activity}->{$wf_action}->{label} || $wf_action)
            });

            @buttons = ({
                page => 'redirect!workflow!load!wf_id!'.$wf_info->{workflow}->{id},
                label => 'I18N_OPENXPKI_UI_WORKFLOW_BULK_RECHECK_BUTTON',
                format => 'alternative'
            });

            # we use the time elapsed to calculate the next update
            my $timeout = 15;
            if ( $wf_info->{workflow}->{last_update} ) {
                # elapsed time in MINUTES
                my $elapsed = (time() - str2time($wf_info->{workflow}->{last_update}.' GMT')) / 60;
                if ($elapsed > 240) {
                    $timeout = 15 * 60;
                } elsif ($elapsed > 1) {
                    # 4 hours = 15 min delay, 4 min = 1 min delay
                    $timeout = POSIX::floor(sqrt( $elapsed )) * 60;
                }
                $self->logger()->debug('Auto Refresh when running' . $elapsed .' / ' . $timeout );
            }

            $self->refresh('workflow!load!wf_id!'.$wf_info->{workflow}->{id}, $timeout);

        # workflow halted by exception
        } elsif ( $wf_proc_state eq 'exception') {

            @fields = ({
                label => 'I18N_OPENXPKI_UI_WORKFLOW_LAST_UPDATE_LABEL',
                value => str2time($wf_info->{workflow}->{last_update}.' GMT'),
                'format' => 'timestamp'
            }, {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_EXCEPTION_FAILED_ACTION_LABEL',
                value => $wf_action_info->{label}
            });

            # add the exception text in case the user is allowed to see the context
            push @fields, {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_EXCEPTION_MESSAGE_LABEL',
                value => $wf_info->{workflow}->{context}->{wf_exception},
            } if ((grep /context/, @handles) && $wf_info->{workflow}->{context}->{wf_exception});

            # if there are output rules defined, we add them now
            if ( $wf_info->{state}->{output} ) {
                push @fields, @{$self->__render_fields( $wf_info, $view )};
            }

            # if we come here from a failed action the status is set already
            if (!$self->_status()) {
                $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_STATE_EXCEPTION','error');
            }

        } # end proc_state switch

        $self->add_section({
            type => 'keyvalue',
            content => {
                data => \@fields,
                buttons => [ @buttons, @buttons_handle ]
        }});

    # if there is one activity selected (or only one present), we render it now
    } elsif ($wf_action) {

        my $wf_action_info = $wf_info->{activity}->{$wf_action};
        # if we fallback to the state label we dont want it in the 1
        my $label = $wf_action_info->{label};
        if ($label ne $wf_action) {
            if (@breadcrumb && $wf_info->{state}->{label}) {
                push @breadcrumb, { className => 'workflow-state', label => $wf_info->{state}->{label} };
            }
        } else {
            $label = $wf_info->{state}->{label};
        }

        $self->_page({
            label => $label,
            breadcrumb => \@breadcrumb,
            shortlabel => $wf_info->{workflow}->{id},
            description =>  $templated_description->($wf_action_info),
            className => 'workflow workflow-action ' . ($wf_action_info->{uiclass} || ''),
            canonical_uri => sprintf('workflow!load!wf_id!%01d!wf_action!%s', $wf_info->{workflow}->{id}, $wf_action),
        });

        # delegation based on activity
        if ($wf_action_info->{uihandle}) {
            return $self->__delegate_call($wf_action_info->{uihandle}, $args, $wf_action);
        }

        $self->logger()->trace('activity info ' . Dumper $wf_action_info ) if $self->logger->is_trace;

        # we allow prefill of the form if the workflow is started
        my $do_prefill = $wf_info->{workflow}->{state} eq 'INITIAL';

        my $context = $wf_info->{workflow}->{context};
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
            next unless ($item);

            push @fields, $item;
            # if the field has a description text, push it to the @fielddesc list
            my $descr = $field->{description};
            if ($descr && $descr !~ /^\s*$/ && $field->{type} ne 'hidden') {
                push @fielddesc, { label => $item->{label}, value => $descr, format => 'raw' };
            }

        }

        # Render the context values if there are no fields
        if (!scalar @fields) {
            $self->add_section({
                type => 'keyvalue',
                content => {
                    label => '',
                    description => '',
                    data => $self->__render_fields( $wf_info, $view ),
                    buttons => $self->__get_form_buttons( $wf_info ),
            }});

        } else {

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
                    submit_label => $wf_action_info->{button} || 'I18N_OPENXPKI_UI_WORKFLOW_SUBMIT_BUTTON',
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
        }
    } else {

        $self->_page({
            label => $wf_info->{state}->{label} || $wf_info->{workflow}->{title} || $wf_info->{workflow}->{label},
            breadcrumb => \@breadcrumb,
            shortlabel => $wf_info->{workflow}->{id},
            description =>  $templated_description->($wf_info->{state}),
            className => 'workflow workflow-page ' . ($wf_info->{state}->{uiclass} || ''),
            ($wf_info->{workflow}->{id} ? (canonical_uri => 'workflow!load!wf_id!'.$wf_info->{workflow}->{id}) : ()),
        });

        # Set status decorator on final states (uses proc_state).
        # To finalize without status message use state name "NOSTATUS".
        # Some field types are able to override the status during render so
        # this might not be the final status line!
        if ( $wf_info->{state}->{status} && ref $wf_info->{state}->{status} eq 'HASH' ) {
            $self->_status( $wf_info->{state}->{status} );

        # Finished workflow
        } elsif ('finished' eq $wf_proc_state) {
            # add special colors for success and failure
            my $state = $wf_info->{workflow}->{state};
            if ('SUCCESS' eq $state) {
                $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_STATUS_SUCCESS', 'success');
            }
            elsif ('FAILURE' eq $state) {
                $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_STATUS_FAILURE', 'error');
            }
            elsif ('CANCELED' eq $state) {
                $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_STATUS_CANCELED', 'warn');
            }
            elsif ('NOSTATUS' ne $state) {
                $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_STATUS_MISC_FINAL', 'warn');
            }

        # Archived workflow
        } elsif ('archived' eq $wf_proc_state) {
            $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_STATE_ARCHIVED', 'info');

        # Forcibly failed workflow
        } elsif ('failed' eq $wf_proc_state) {
            $self->set_status('I18N_OPENXPKI_UI_WORKFLOW_STATE_FAILED', 'error');
        }

        my $fields = $self->__render_fields( $wf_info, $view );

        $self->logger()->trace('Field data ' . Dumper $fields) if $self->logger->is_trace;

        # Add action buttons
        my $buttons = $self->__get_action_buttons( $wf_info ) ;

        if (!@$fields && $wf_info->{workflow}->{state} eq 'INITIAL') {
            # initial step of workflow without fields
            $self->add_section({
                type => 'text',
                content => {
                    label => '',
                    description => '',
                    buttons => $buttons,
                }
            });

        } else {

            # state manual but no buttons -> user is waiting for a third party
            # to continue the workflow and might want to reload the page
            if ($wf_proc_state eq 'manual' && @{$buttons} == 0) {
                $buttons = [{
                    page => 'redirect!workflow!load!wf_id!'.$wf_info->{workflow}->{id},
                    label => 'I18N_OPENXPKI_UI_WORKFLOW_STATE_MANUAL_RECHECK_BUTTON',
                    format => 'alternative'
                }];
            }

            my @fields = @{$fields};

            # if we have no fields at all in the output we need an empty
            # section to make the UI happy and to show the buttons, if any
            $self->add_section({
                type => 'text',
                content => {
                    buttons => $buttons,
            }}) unless (@fields);

            my @section_fields;
            while (my $field = shift @fields) {

                # check if this field is a grid or chart
                if ($field->{format} !~ m{(grid|chart)}) {
                    push @section_fields, $field;
                    next;
                }

                # check if we have normal fields on the stack to output
                if (@section_fields) {
                    $self->add_section({
                        type => 'keyvalue',
                        content => {
                            label => '',
                            description => '',
                            data => [ @section_fields ],
                    }});
                    @section_fields  = ();
                }

                if ($field->{format} eq 'grid') {
                    $self->logger()->trace('Adding grid ' . Dumper $field) if $self->logger->is_trace;
                    $self->add_section({
                        type => 'grid',
                        className => 'workflow',
                        content => {
                            actions => ($field->{action} ? [{
                                path => $field->{action},
                                label => '',
                                icon => 'view',
                                target => ($field->{target} ? $field->{target} : 'tab'),
                            }] : undef),
                            columns =>  $field->{header},
                            data => $field->{value},
                            empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
                            buttons => (@fields ? [] : $buttons), # add buttons if its the last item
                        }
                    });
                } elsif ($field->{format} eq 'chart') {

                    $self->logger()->trace('Adding chart ' . Dumper $field) if $self->logger->is_trace;
                    $self->add_section({
                        type => 'chart',
                        content => {
                            label => $field->{label} || '',
                            options => $field->{options},
                            data => $field->{value},
                            empty => 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL',
                            buttons => (@fields ? [] : $buttons), # add buttons if its the last item
                        }
                    });
                }
            }
            # no chart/grid in the last position => output items on the stack

            $self->add_section({
                type => 'keyvalue',
                content => {
                    label => '',
                    description => '',
                    data => \@section_fields,
                    buttons => $buttons,
            }}) if (@section_fields);
        }
    }

    #
    # Right block
    #
    if ($wf_info->{workflow}->{id}) {

        my $wfdetails_config = $self->_client->session()->param('wfdetails');
        # undef = no right box
        if (defined $wfdetails_config) {

            if ($view eq 'result' && $wf_info->{workflow}->{proc_state} !~ /(finished|failed|archived)/) {
                push @buttons_handle, {
                    href => '#/openxpki/redirect!workflow!load!wf_id!'.$wf_info->{workflow}->{id},
                    label => 'I18N_OPENXPKI_UI_WORKFLOW_OPEN_WORKFLOW_LABEL',
                    format => "primary",
                };
            }

            # assemble infos
            my $data = $self->__render_workflow_info( $wf_info, $wfdetails_config );

            # The workflow info contains info about all control actions that
            # can done on the workflow -> render appropriate buttons.
            my $extra_handles;
            if (@handles) {

                my @extra_links;
                if (grep /context/, @handles) {
                    push @extra_links, {
                        'page' => 'workflow!context!wf_id!'.$wf_info->{workflow}->{id},
                        'label' => 'I18N_OPENXPKI_UI_WORKFLOW_CONTEXT_LABEL',
                    };
                }

                if (grep /attribute/, @handles) {
                    push @extra_links, {
                        'page' => 'workflow!attribute!wf_id!'.$wf_info->{workflow}->{id},
                        'label' => 'I18N_OPENXPKI_UI_WORKFLOW_ATTRIBUTE_LABEL',
                    };
                }

                if (grep /history/, @handles) {
                    push @extra_links, {
                        'page' => 'workflow!history!wf_id!'.$wf_info->{workflow}->{id},
                        'label' => 'I18N_OPENXPKI_UI_WORKFLOW_HISTORY_LABEL',
                    };
                }

                if (grep /techlog/, @handles) {
                    push @extra_links, {
                        'page' => 'workflow!log!wf_id!'.$wf_info->{workflow}->{id},
                        'label' => 'I18N_OPENXPKI_UI_WORKFLOW_LOG_LABEL',
                    };
                }

                push @{$data}, {
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
                    data => $data,
                    buttons => \@buttons_handle,
            }}];
        }
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
    my $btnhint = $wf_info->{state}->{button} || {};

    my @buttons;

    if ($btnhint->{_head}) {
        push @buttons, { section => $btnhint->{_head} };
    }

    foreach my $wf_action (@{$wf_info->{state}->{option}}) {
        my $wf_action_info = $wf_info->{activity}->{$wf_action};

        my %button = (
            label => $wf_action_info->{label},
            action => sprintf ('workflow!select!wf_action!%s!wf_id!%01d', $wf_action, $wf_info->{workflow}->{id}),
        );

        # buttons in workflow start = only one initial start button
        %button = (
            label => ($wf_action_info->{label} ne $wf_action) ? $wf_action_info->{label} : 'I18N_OPENXPKI_UI_WORKFLOW_START_BUTTON',
            page => 'workflow!start!wf_type!'. $wf_info->{workflow}->{type},
        ) if (!$wf_info->{workflow}->{id});

        # TODO - we should add some configuration option for this
        if ($wf_action =~ /global_cancel/) {
            $button{confirm} = {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_CONFIRM_CANCEL_LABEL',
                description => 'I18N_OPENXPKI_UI_WORKFLOW_CONFIRM_CANCEL_DESCRIPTION',
                confirm_label => 'I18N_OPENXPKI_UI_WORKFLOW_CONFIRM_DIALOG_CONFIRM_BUTTON',
                cancel_label => 'I18N_OPENXPKI_UI_WORKFLOW_CONFIRM_DIALOG_CANCEL_BUTTON',
            };
            $button{format} = 'failure';
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
                $button{format} = $hint->{format};
            }
            if ($hint->{confirm}) {
                $button{confirm} = {
                    label => $hint->{confirm}->{label} || 'I18N_OPENXPKI_UI_PLEASE_CONFIRM_TITLE',
                    description => $hint->{confirm}->{description} || 'I18N_OPENXPKI_UI_PLEASE_CONFIRM_DESC',
                    confirm_label => $hint->{confirm}->{confirm} || 'I18N_OPENXPKI_UI_WORKFLOW_CONFIRM_DIALOG_CONFIRM_BUTTON',
                    cancel_label => $hint->{confirm}->{cancel} ||  'I18N_OPENXPKI_UI_WORKFLOW_CONFIRM_DIALOG_CANCEL_BUTTON',
                }
            }
            if ($hint->{break} && $hint->{break} =~ /(before|after)/) {
                $button{'break_'. $hint->{break}} = 1;
            }

        }
        push @buttons, \%button;

    }

    $self->logger()->trace('Buttons are ' . Dumper \@buttons) if $self->logger->is_trace;

    return \@buttons;
}

sub __get_form_buttons {

    my $self = shift;
    my $wf_info = shift;
    my @buttons;

    my $activity_count = scalar keys %{$wf_info->{activity}};
    if ($wf_info->{activity}->{global_cancel}) {
        push @buttons, {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_CANCEL_BUTTON',
            action => 'workflow!select!wf_action!global_cancel!wf_id!'. $wf_info->{workflow}->{id},
            format => 'cancel',
            confirm => {
                description => 'I18N_OPENXPKI_UI_WORKFLOW_CONFIRM_CANCEL_DESCRIPTION',
                label => 'I18N_OPENXPKI_UI_WORKFLOW_CONFIRM_CANCEL_LABEL',
                confirm_label => 'I18N_OPENXPKI_UI_WORKFLOW_CONFIRM_DIALOG_CONFIRM_BUTTON',
                cancel_label => 'I18N_OPENXPKI_UI_WORKFLOW_CONFIRM_DIALOG_CANCEL_BUTTON',
        }};
        $activity_count--;
    }

    # if there is another activity besides global_cancel, we add a go back button
    if ($activity_count > 1) {
        unshift @buttons, {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_RESET_BUTTON',
            page => 'redirect!workflow!load!wf_id!'.$wf_info->{workflow}->{id},
            format => 'reset',
        };
    }

    if ($wf_info->{handles} && ref $wf_info->{handles} eq 'ARRAY' && (grep /fail/, @{$wf_info->{handles}})) {
        my $token = $self->__register_wf_token( $wf_info, { wf_handle => 'fail' } );
        push @buttons, {
            label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_FAILURE_BUTTON',
            action => 'workflow!handle!wf_token!'.$token->{value},
            format => 'terminate',
            confirm => {
                label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_FAILURE_DIALOG_LABEL',
                description => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_FAILURE_DIALOG_TEXT',
                confirm_label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_FAILURE_DIALOG_CONFIRM_BUTTON',
                cancel_label => 'I18N_OPENXPKI_UI_WORKFLOW_FORCE_FAILURE_DIALOG_CANCEL_BUTTON',
            }
        };
    }

    return \@buttons;
}


sub __get_next_auto_action {

    my $self = shift;
    my $wf_info = shift;
    my $wf_action;

    # no auto action if the state has output rules defined
    return if (ref $wf_info->{state}->{output} eq 'ARRAY' &&
        scalar(@{$wf_info->{state}->{output}}) > 0);


    my @activities = keys %{$wf_info->{activity}};
    # only one valid activity found, so use it
    if (scalar @activities == 1) {
        $wf_action = $activities[0];

    # do not count global_cancel as alternative selection
    } elsif (scalar @activities == 2 && (grep /global_cancel/, @activities)) {
        $wf_action = ($activities[1] eq 'global_cancel') ? $activities[0] : $activities[1];

    }

    return unless ($wf_action);

    # do not load activities that do not have fields or a uihandle class
    return unless ($wf_info->{activity}->{$wf_action}->{field} ||
        $wf_info->{activity}->{$wf_action}->{uihandle});

    $self->logger()->debug('Implicit autoselect of action ' . $wf_action ) if($wf_action);

    return $wf_action;

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
    return if ($type eq "server");

    my $item = {
        name => $name,
        label => $field->{label} || $name,
        type => $type
    };

    $item->{placeholder} = $field->{placeholder} if ($field->{placeholder});
    $item->{tooltip} = $field->{tooltip} if ($field->{tooltip});

    if ($field->{option}) {
        $item->{options} = $field->{option};
    }

    if ($field->{clonable}) {
        $item->{clonable} = 1;
    }

    if (!$field->{required}) {
        $item->{is_optional} = 1;
    }

    # special handling of preset cert_identifier fields
    if ($type eq 'cert_identifier' && $value) {
        $item->{type} = 'static';
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

    if ($item->{type} eq 'static' && $field->{template}) {
        if (OpenXPKI::Serialization::Simple::is_serialized($value)) {
            $item->{value} = $self->serializer()->deserialize($value);
        }
        $item->{verbose} = $self->send_command_v2( 'render_template', { template => $field->{template}, params => $item } );
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

    my ($class, $method, $n, $param) = $call =~ /([\w\:\_]+)::([\w\_]+)(!([!\w]+))?/;
    $self->logger()->debug("delegate render to $class, $method" );
    eval "use $class; 1;";
    if ($param) {
        $class->$method( $self, $args, $wf_action, $param );
    } else {
        $class->$method( $self, $args, $wf_action );
    }
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

    $self->logger()->trace("search result " . Dumper $search_result) if $self->logger->is_trace;

    my @result;

    my $wf_labels = $self->send_command_v2( 'get_workflow_instance_types' );

    foreach my $wf_item (@{$search_result}) {

        my @line;
        my ($wf_info, $context, $attrib);

        # if we received a list of wf_info structures, we need to translate
        # the workflow hash into the database table format
        if ($wf_item->{workflow} && ref $wf_item->{workflow} eq 'HASH') {
            $wf_info = $wf_item;
            $context = $wf_info->{workflow}->{context};
            $attrib = $wf_info->{workflow}->{attribute};
            $wf_item = {
                'workflow_last_update' => $wf_info->{workflow}->{last_update},
                'workflow_id' => $wf_info->{workflow}->{id},
                'workflow_type' => $wf_info->{workflow}->{type},
                'workflow_state' => $wf_info->{workflow}->{state},
                'workflow_proc_state' => $wf_info->{workflow}->{proc_state},
                'workflow_wakeup_at' => $wf_info->{workflow}->{wake_up_at},
            };
        }

        $wf_item->{workflow_label} = $wf_labels->{$wf_item->{workflow_type}}->{label};
        $wf_item->{workflow_description} = $wf_labels->{$wf_item->{workflow_type}}->{description};

        foreach my $col (@{$colums}) {

            my $field = lc($col->{field} // ''); # migration helper, lowercase uicontrol input
            $field = 'workflow_id' if ($field eq 'workflow_serial');

            # we need to load the wf info
            if (!$wf_info && ($col->{template} || $col->{source} eq 'context')) {
                $wf_info = $self->send_command_v2( 'get_workflow_info',  {
                    id => $wf_item->{'workflow_id'},
                    with_attributes => 1,
                });
                $self->logger()->trace( "fetch wf info : " . Dumper $wf_info) if $self->logger->is_trace;
                $context = $wf_info->{workflow}->{context};
                $attrib = $wf_info->{workflow}->{attribute};
            }

            if ($col->{template}) {
                my $out;
                my $ttp = {
                    context => $context,
                    attribute => $attrib,
                    workflow => $wf_info->{workflow}
                };
                push @line, $self->send_command_v2( 'render_template', { template => $col->{template}, params => $ttp } );

            } elsif ($col->{source} eq 'workflow') {

                # Special handling of the state field
                if ($field eq "workflow_state") {
                    my $state = $wf_item->{'workflow_state'};
                    my $proc_state = $wf_item->{'workflow_proc_state'};

                    if (grep /\A $proc_state \Z/x, qw( exception pause retry_exceeded failed )) {
                        $state .= sprintf(" (%s)", $self->__get_proc_state_label($proc_state));
                    };
                    push @line, $state;
                } else {
                    push @line, $wf_item->{ $field };

                }

            } elsif ($col->{source} eq 'context') {
                push @line, $context->{ $col->{field} };
            } elsif ($col->{source} eq 'attribute') {
                push @line, $wf_item->{ $col->{field} }
            } elsif ($col->{field} eq 'creator') {
                push @line, $self->__render_creator_tooltip($wf_item->{creator}, $col);
            } else {
                # hu ?
            }
        }

        # special color for workflows in final failure

        my $status = $wf_item->{'workflow_proc_state'};

        if ($status eq 'finished' && $wf_item->{'workflow_state'} eq 'FAILURE') {
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
    my %attrib;

    for (my $ii = 0; $ii < scalar @{$cols}; $ii++) {

        # we must create a copy as we change the hash in the session info otherwise
        my %col = %{ $cols->[$ii] };
        my $field = $col{field} // ''; # prevent "Use of uninitialized value $col{"field"} in string eq"
        my $head = { sTitle => $col{label} };

        if ($field eq 'creator') {
            $attrib{'creator'} = 1;
            $col{format} = 'tooltip';

        } elsif ($field =~ m{\A (attribute)\.(\S+) }xi) {
            $col{source} = $1;
            $col{field} = $2;
            $attrib{$2} = 1;

        } elsif ($field =~ m{\A (context)\.(\S+) }xi) {
            # we use this later to avoid the pattern match
            $col{source} = $1;
            $col{field} = $2;

        } elsif (!$col{template}) {
            $col{source} = 'workflow';
            $col{field} = uc($col{field})

        }
        push @column, \%col;

        if ($col{sortkey}) {
            $head->{sortkey} = $col{sortkey};
        }
        if ($col{format}) {
            $head->{format} = $col{format};
        }
        push @header, $head;
    }

    push @header, { sTitle => 'serial', bVisible => 0 };
    push @header, { sTitle => "_className"};

    push @column, { source => 'workflow', field => 'workflow_id' };

    return ( \@header, \@column, [ keys(%attrib) ] );
}

=head2 __render_fields

=cut

sub __render_fields {

    my $self = shift;
    my $wf_info = shift;
    my $view = shift;

    my @fields;
    my $context = $wf_info->{workflow}->{context};

    # in case we have output format rules, we just show the defined fields
    # can be overriden with view = context
    my $output = $wf_info->{state}->{output};
    my @fields_to_render;

    if ($view eq 'context' && (grep /context/, @{$wf_info->{handles}})) {
        foreach my $field (sort keys %{$context}) {
            push @fields_to_render, { name => $field };
        }
    } elsif ($view eq 'attribute' && (grep /attribute/, @{$wf_info->{handles}})) {
        my $attr = $wf_info->{workflow}->{attribute};
        foreach my $field (sort keys %{$attr }) {
            push @fields_to_render, { name => $field, value => $attr->{$field} };
        }
    } elsif ($output) {
        @fields_to_render = @$output;
        # strip array indicator [] from field name
        for (@fields_to_render) { $_->{name} =~ s/\[\]$// if ($_->{name}) }
        $self->logger()->trace('Render output rules: ' . Dumper  \@fields_to_render) if $self->logger->is_trace;

    } else {
        foreach my $field (sort keys %{$context}) {
            next if ($field =~ m{ \A (wf_|_|workflow_id|sources) }x);
            push @fields_to_render, { name => $field };
        }
        $self->logger()->trace('No output rules, render plain context: ' . Dumper  \@fields_to_render) if $self->logger->is_trace;
    }

    my $queued; # receives header items that depend on non-empty sections
    ##! 64: "Context: " . Dumper($context)
    FIELD: foreach my $field (@fields_to_render) {

        my $key = $field->{name} || '';
        ##! 64: "Context value for field $key: " . (defined $context->{$key} ? Dumper($context->{$key}) : '')
        my $item = {
            name => $key,
            value => $field->{value} // (defined $context->{$key} ? $context->{$key} : ''),
            format =>  $field->{format} || ''
        };


        if ($field->{uiclass}) {
            $item->{className} = $field->{uiclass};
        }

        if ($item->{format} eq 'spacer') {
            push @fields, { format => 'head', className => $item->{className}||'spacer' };
            next FIELD;
        }

        # Suppress key material, exceptions are vollatile and download fields
        if ($item->{value} =~ /-----BEGIN[^-]*PRIVATE KEY-----/ && $item->{format} ne 'download' && substr($key,0,1) ne '_') {
            $item->{value} = 'I18N_OPENXPKI_UI_WORKFLOW_SENSITIVE_CONTENT_REMOVED_FROM_CONTEXT';
        }

        # Label, Description, Tooltip
        foreach my $prop (qw(label description tooltip preamble)) {
            if ($field->{$prop}) {
                $item->{$prop} = $field->{$prop};
            }
        }

        if (!$item->{label}) {
            $item->{label} = $key;
        }

        my $field_type = $field->{type} || '';

        # we have several formats that might have non-scalar values
        if (OpenXPKI::Serialization::Simple::is_serialized( $item->{value} ) ) {
            $item->{value} = $self->serializer()->deserialize( $item->{value} );
        }

        # auto-assign format based on some assumptions if no format is set
        if (!$item->{format}) {

            # create a link on cert_identifier fields
            if ( $key =~ m{ cert_identifier \z }x ||
                $field_type eq 'cert_identifier') {
                $item->{format} = 'cert_identifier';
            }

            # Code format any PEM blocks
            if ( $key =~ m{ \A (pkcs10|pkcs7) \z }x  ||
                $item->{value} =~ m{ \A -----BEGIN([A-Z ]+)-----.*-----END([A-Z ]+)---- }xms) {
                $item->{format} = 'code';
            } elsif ($field_type eq 'textarea') {
                $item->{format} = 'nl2br';
            }

            if (ref $item->{value}) {
                if (ref $item->{value} eq 'HASH') {
                    $item->{format} = 'deflist';
                } elsif (ref $item->{value} eq 'ARRAY') {
                    $item->{format} = 'ullist';
                }
            }
            ##! 64: 'Auto applied format: ' . $item->{format}
        }

        # convert format cert_identifier into a link
        if ($item->{format} eq "cert_identifier") {
            $item->{format} = 'link';

            # do not create if the field is empty
            if ($item->{value}) {
                my $label = $item->{value};

                my $cert_identifier = $item->{value};
                $item->{value}  = {
                    label => $label,
                    page => 'certificate!detail!identifier!'.$cert_identifier,
                    target => 'popup',
                    # label is usually formated to a human readable string
                    # but we sometimes need the raw value in the UI for extras
                    value => $cert_identifier,
                };
            }

            $self->logger()->trace( 'item ' . Dumper $item) if $self->logger->is_trace;

        # open another workflow - performs ACL check
        } elsif ($item->{format} eq "workflow_id") {

            my $workflow_id = $item->{value};
            next FIELD unless($workflow_id);

            my $can_access = $self->send_command_v2( 'check_workflow_acl',
                    { id => $workflow_id  });

            if ($can_access) {
                $item->{format} = 'link';
                $item->{value}  = {
                    label => $workflow_id,
                    page => 'workflow!load!wf_id!'.$workflow_id,
                    target => '_blank',
                    value => $workflow_id,
                };
            } else {
                $item->{format} = '';
            }

            $self->logger()->trace( 'item ' . Dumper $item) if $self->logger->is_trace;

        # add a redirect command to the page
        } elsif ($item->{format} eq "redirect") {

            if (ref $item->{value}) {
                my $v = $item->{value};
                my $target = $v->{target} || 'workflow!load!wf_id!'.$wf_info->{workflow}->{id};
                my $pause = $v->{pause} || 1;
                $self->refresh($target, $pause);
                if ($v->{label}) {
                    $self->set_status($v->{label}, ($v->{level} || 'info'));
                }
            } else {
                $self->redirect($item->{value});
            }
            # we dont want this to show up in the result so we unset its value
            $item = undef;

        # create a link to download the given filename
        } elsif ($item->{format} =~ m{ \A download(\/([\w_\/-]+))? }xms ) {

            # legacy - format is "download/mime/type"
            my $mime = $2 || 'application/octect-stream';
            $item->{format} = 'download';

            # value is empty
            next FIELD unless($item->{value});

            # parameters given in the field definition
            my $param = $field->{param} || {};

            # Arguments for the UI field
            # label => STR           # text above the download field
            # type => "plain" | "base64" | "link",  # optional, default: "plain"
            # data => STR,           # plain data, Base64 data or URL
            # mimetype => STR,       # optional: mimetype passed to browser
            # filename => STR,       # optional: filename, default: depends on data
            # autodownload => BOOL,  # optional: set to 1 to auto-start download
            # hide => BOOL,          # optional: set to 1 to hide input and buttons (requires autodownload)

            my $vv = $item->{value};
            # scalar value
            if (!ref $vv) {
                # if an explicit filename is set, we assume it is v3.10 or
                # later so we assume the value is the data and config is in
                # the field parameters
                if ($param->{filename}) {
                    $vv = { filename => $param->{filename}, data => $vv };
                } else {
                    $vv = { filename => $vv, source => 'file:'.$vv };
                }
            }

            # very old legacy format where file was given without source
            if ($vv->{file}) {
                $vv->{source} = "file:".$vv->{file};
                $vv->{filename} = $vv->{file} unless($vv->{filename});
                delete $vv->{file};
            }

            # merge items from field param
            $self->logger()->info(Dumper [ $vv, $param ]);
            map { $vv->{$_} ||= $param->{$_}  } ('mime','label','binary','hide','auto','filename');

            # guess filename from a file source
            if (!$vv->{filename} && $vv->{source} && $vv->{source} =~ m{ file:.*?([^\/]+(\.\w+)?) \z }xms) {
                $vv->{filename} = $1;
            }

            # set mime to default / from format
            $vv->{mime} ||= $mime;

            # we have an external source so we need a link
            if ($vv->{source}) {
                 my $target = $self->__persist_response({
                    source => $vv->{source},
                    attachment =>  $vv->{filename},
                    mime => $vv->{mime}
                });
                $item->{value}  = {
                    label => 'I18N_OPENXPKI_UI_CLICK_TO_DOWNLOAD',
                    type => 'link',
                    filename => $vv->{filename},
                    data => $self->_client()->_config()->{'scripturl'} . "?page=".$target,
                };
            } else {
                my $type;
                # payload is binary, so encode it and set type to base64
                if ($vv->{binary}) {
                    $type = 'base64';
                    $vv->{data} = encode_base64($vv->{data}, '');
                } elsif ($vv->{base64}) {
                    $type = 'base64';
                }
                $item->{value}  = {
                    label=> $vv->{label},
                    mimetype => $vv->{mime},
                    filename => $vv->{filename},
                    type => $type,
                    data => $vv->{data},
                };
            }

            if ($vv->{hide}) {
                $item->{value}->{autodownload} = 1;
                $item->{value}->{hide} = 1;
            } elsif ($vv->{auto}) {
                $item->{value}->{autodownload} = 1;
            }

        # format for cert_info block
        } elsif ($item->{format} eq "cert_info") {
            $item->{format} = 'deflist';

            my $raw = $item->{value};

            # this requires that we find the profile and subject in the context
            my @val;
            my $cert_profile = $context->{cert_profile};
            my $cert_subject_style = $context->{cert_subject_style};
            if ($cert_profile && $cert_subject_style) {

                if (!$raw || ref $raw ne 'HASH') {
                    $raw = {};
                }

                my $fields = $self->send_command_v2( 'get_field_definition',
                    { profile => $cert_profile, style => $cert_subject_style, 'section' =>  'info' });
                $self->logger()->trace( 'Profile fields' . Dumper $fields ) if $self->logger->is_trace;

                foreach my $field (@$fields) {
                    # FIXME this still uses "old" syntax - adjust after API refactoring
                    my $key = $field->{id}; # Name of the context key
                    if ($raw->{$key}) {
                        push @val, { label => $field->{label}, value => $raw->{$key}, key => $key };
                    }
                }
            } else {
                # if nothing is found, transform raw values to a deflist
                @val = map { { key => $_, label => $_, value => $item->{value}->{$_}} } sort keys %{$item->{value}};

            }

            $item->{value} = \@val;

        } elsif ($item->{format} eq "ullist" || $item->{format} eq "rawlist") {
            # nothing to do here

        } elsif ($item->{format} eq "itemcnt") {

            my $list = $item->{value};

            if (ref $list eq 'ARRAY') {
                $item->{value} = scalar @{$list};
            } elsif (ref $list eq 'HASH') {
                $item->{value} = scalar keys %{$list};
            } else {
                $item->{value} = '??';
            }
            $item->{format} = '';

        } elsif ($item->{format} eq "deflist") {

            # Sort by label
            my @val;
            if ($item->{value} && (ref $item->{value} eq 'HASH')) {
                @val = map { { label => $_, value => $item->{value}->{$_}} } sort keys %{$item->{value}};
                $item->{value} = \@val;
            }

        } elsif ($item->{format} eq "grid") {

            my @head;
            # item value can be data or grid specification
            if (ref $item->{value} eq 'HASH') {
                my $hv = $item->{value};
                $item->{header} = [ map { { 'sTitle' => $_ } } @{$hv->{header}} ];
                $item->{value} = $hv->{value};
            } elsif ($field->{header}) {
                $item->{header} = [ @head = map { { 'sTitle' => $_ } } @{$field->{header}} ];
            } else {
                $item->{header} = [ @head = map { { 'sTitle' => '' } } @{$item->{value}->[0]} ];
            }
            $item->{action} = $field->{action};
            $item->{target} = $field->{target} ?  $field->{target} : 'tab';

        } elsif ($item->{format} eq "chart") {

            my @head;

            my $param = $field->{param} || {};

            $item->{options} = {
                type => 'line',
            };

            # read options from the fields param method
            foreach my $key ('width','height','type','title') {
                $item->{options}->{$key} = $param->{$key} if (defined $param->{$key});
            }

            # series can be a hash based on the datas keys or an array
            my $series = $param->{series};
            if (ref $series eq 'ARRAY') {
                $item->{options}->{series} = $series;
            }

            my $start_at = 0;
            my $interval = 'months';

            # item value can be data (array) or chart specification (hash)
            if (ref $item->{value} eq 'HASH') {
                # single data row chart with keys as groups
                my $hv = $item->{value};
                my @series;
                my @keys;
                if (ref $series eq 'HASH') {
                    # series contains label as key / value hash
                    @keys = sort keys %{$series};
                    map {
                        # series value can be a scalar (label) or a full hash
                        my $ll = $series->{$_};
                        push @series, (ref $ll ? $ll : { label => $ll });
                        $_;
                    } @keys;

                } elsif (ref $series eq 'ARRAY') {
                    @keys = map {
                        my $kk = $_->{key};
                        delete $_->{key};
                        $kk;
                    } @{$series};

                } else {

                    @keys = grep { ref $hv->{$_} ne 'HASH' } sort keys %{$hv};
                    if (my $prefix = $param->{label}) {
                        # label is a prefix to be merged with the key names
                        @series = map { { label => $prefix.'_'.uc($_) } } @keys;
                    } else {
                        @series = map {  { label => $_ } } @keys;
                    }
                }

                # check if we have a single row or multiple, we also assume
                # that all keys have the same value count so we just take the
                # first one
                if (ref $hv->{$keys[0]}) {
                    # get the number of items per row
                    my $ic = scalar @{$hv->{$keys[0]}};

                    # if start_at is not set, we do a backward calculation
                    $start_at ||= DateTime->now()->subtract ( $interval => ($ic-1) );
                    my $val = [];
                    for (my $drw = 0; $drw < $ic; $drw++) {
                        my @row = (undef) x @keys;
                        unshift @row, $start_at->epoch();
                        $start_at->add( $interval => 1 );
                        $val->[$drw] = \@row;
                        for (my $idx = 0; $idx < @keys; $idx++) {
                            $val->[$drw]->[$idx+1] = $hv->{$keys[$idx]}->[$drw];
                        }
                    }
                    $item->{value} = $val;

                } elsif ($item->{options}->{type} eq 'pie') {

                    my $sum = 0;
                    my @val = map { $sum+=$hv->{$_}; $hv->{$_} || 0 } @keys;
                    if ($sum) {
                        my $divider = 100 / $sum;

                        @val = map {  $_ * $divider } @val;

                        unshift @val, '';
                        $item->{value} = [ \@val ];
                    }

                } else {
                    # only one row so this is easy
                    my @val = map { $hv->{$_} || 0 } @keys;
                    unshift @val, '';
                    $item->{value} = [ \@val ];
                }
                $item->{options}->{series} = \@series if (@series);

            } elsif (ref $item->{value} eq 'ARRAY' && @{$item->{value}}) {
                if (!ref $item->{value}->[0]) {
                    $item->{value} = [ $item->{value} ];
                }
            }

        } elsif ($item->{format} eq 'head') {
            # head can either show a value from context or a fixed label
            if ($item->{value} eq '') {
                $item->{value} = $item->{label};
            }
            $item->{empty} = $field->{ifempty} || '';
            $item->{className} //= 'spacer';

        } elsif ($field_type eq 'select' && !$field->{template} && $field->{option} && ref $field->{option} eq 'ARRAY') {
            foreach my $option (@{$field->{option}}) {
                next unless (defined $option->{value});
                if ($item->{value} eq $option->{value}) {
                    $item->{value} = $option->{label};
                    last;
                }
            }
        }

        if ($field->{template}) {

            $self->logger()->trace('Render output using template on field '.$key.', '. $field->{template} . ', value:  ' . Dumper $item->{value}) if $self->logger->is_trace;

            # Rendering target depends on value format
            # deflist: iterate over each label/value pair and render the value template
            if ($item->{format} eq "deflist") {
                $item->{value} = [
                    map { {
                        # $_ is a HashRef: { label => STR, key => STR, value => STR } where key is the field name (not needed here)
                        label => $_->{label},
                        value => $self->send_command_v2('render_template', { template => $field->{template}, params => $_ }),
                        format => 'raw',
                    } }
                    @{ $item->{value} }
                ];

            # bullet list, put the full list to tt and split at the | as sep (as used in profile)
            } elsif ($item->{format} eq "ullist" || $item->{format} eq "rawlist") {
                my $out = $self->send_command_v2('render_template', {
                    template => $field->{template},
                    params => { value => $item->{value} },
                });
                $self->logger()->debug('Rendered template: ' . $out);
                if ($out) {
                    my @val = split /\s*\|\s*/, $out;
                    $self->logger()->trace('Split ' . Dumper \@val) if $self->logger->is_trace;
                    $item->{value} = \@val;
                } else {
                    $item->{value} = undef; # prevent pushing emtpy lists
                }

            } elsif (ref $item->{value} eq 'HASH' && $item->{value}->{label}) {
                $item->{value}->{label} = $self->send_command_v2('render_template', {
                    template => $field->{template},
                    params => { value => $item->{value}->{label} },
                });

            } else {
                $item->{value} = $self->send_command_v2('render_template', {
                    template => $field->{template},
                    params => { value => $item->{value} },
                });
            }

        } elsif ($field->{yaml_template}) {
            ##! 64: 'Rendering value: ' . $item->{value}
            $self->logger->debug('Template value: ' . Dumper $item );
            my $structure = $self->send_command_v2('render_yaml_template', {
                template => $field->{yaml_template},
                params => { value => $item->{value} },
            });
            $self->logger->debug('Rendered YAML template: ' . Dumper $structure);
            ##! 64: 'Rendered YAML template: ' . $out
            if (defined $structure) {
                $item->{value} = $structure;
            } else {
                $item->{value} = undef; # prevent pushing emtpy lists
            }
        }

        # do not push items that are empty
        if (!(defined $item->{value} &&
            ((ref $item->{value} eq 'HASH' && %{$item->{value}}) ||
            (ref $item->{value} eq 'ARRAY' && @{$item->{value}}) ||
            (ref $item->{value} eq '' && $item->{value} ne '')))) {
            #noop
        } elsif ($item->{format} eq 'head' && $item->{empty}) {
            # queue header element - we only add it (below) if a non-empty item follows
            $queued = $item;
        } else {
            # add queued element if any
            if ($queued) {
                push @fields, $queued;
                $queued = undef;
            }
            # push current field
            push @fields, $item;
        }
    }

    return \@fields;

}

=head2 __render_workflow_info

Render the technical info of a workflow (state, proc_state, etc). Expects a
wf_info structure and optional a wfdetail_config, will fallback to the
default display if this is not given.

=cut

sub __render_workflow_info {

    my $self = shift;
    my $wf_info = shift;
    my $wfdetails_config = shift || [];

    $wfdetails_config = $self->__default_wfdetails
        unless (@$wfdetails_config);

    my $wfdetails_info;
    # if needed, fetch enhanced info incl. workflow attributes
    if (
        # if given info hash doesn't contain attribute data...
        not($wf_info->{workflow}->{attribute}) and (
            # ...but default wfdetails reference attribute.*
               grep { ($_->{field}//'') =~              / attribute\. /msx } @$wfdetails_config
            or grep { ($_->{template}//'') =~           / attribute\. /msx } @$wfdetails_config
            or grep { (($_->{link}//{})->{page}//'') =~ / attribute\. /msx } @$wfdetails_config
            or grep { ($_->{field}//'') =~              / \Acreator /msx } @$wfdetails_config
        )
    ) {
        $wfdetails_info = $self->send_command_v2( 'get_workflow_info',  {
            id => $wf_info->{workflow}->{id},
            with_attributes => 1,
        })->{workflow};
    }
    else {
        $wfdetails_info = $wf_info->{workflow};
    }

    # assemble infos
    my @data;
    for my $cfg (@$wfdetails_config) {
        my $value;

        my $field = $cfg->{field} // '';
        if ($field eq 'creator') {
            # we enforce tooltip, if you need something else use a template on attribute.creator
            if ($wfdetails_info->{attribute}->{creator} =~ m{certid:([\w-]+)}) {
                $cfg->{format} = 'link';
                # for a link the tooltip is on the top level and the value is a
                # scalar so we need to remap this
                $value = $self->__render_creator_tooltip($wfdetails_info->{attribute}->{creator}, $cfg);
                $value->{label} = $value->{value};
                $value->{page} = 'certificate!detail!identifier!'.$1;
            } else {
                $cfg->{format} = 'tooltip';
                $value = $self->__render_creator_tooltip($wfdetails_info->{attribute}->{creator}, $cfg);
            }
        } elsif ($cfg->{template}) {
            $value = $self->send_command_v2( render_template => {
                template => $cfg->{template},
                params => $wfdetails_info,
            });
        } elsif ($field =~ m{\A attribute\.(\S+) }xi) {
            $value = $wfdetails_info->{attribute}->{$1} // '-';
        } elsif ($field =~ m{\A context\.(\S+) }xi) {
            $value = $wfdetails_info->{context}->{$1} // '-';
        } elsif ($field eq 'proc_state') {
            $value = $self->__get_proc_state_label($wfdetails_info->{$field});
        } elsif ($field) {
            $value = $wfdetails_info->{$field} // '-';
        }

        # if it's a link: render URL template ("page")
        if ($cfg->{link}) {
            $value = {
                label => $value,
                page => $self->send_command_v2( render_template => {
                    template => $cfg->{link}->{page},
                    params => $wfdetails_info,
                }),
                target => $cfg->{link}->{target} || 'popup',
            }
        }

        push @data, {
            label => $cfg->{label} // '',
            value => $value,
            format => $cfg->{link} ? 'link' : ($cfg->{format} || 'text'),
            $cfg->{tooltip} ? ( tooltip => $cfg->{tooltip} ) : (),
        };
    }

    return \@data;

}

=head2 __render_creator_tooltip

Expects the userid of a creator and the field definition.

If the field has I<yaml_template> set, the template is parsed with the
value of the creator given as key I<creator> in the parameter hash. If
the resulting data structure is a hash and has a non-empty key I<value>,
it is used as value for the field.

If the field has I<template> set, the result of this template is used as
tooltip for the field, the literal value given as I<creator> is used as
the visible value. If the namespace of the item is I<certid>, the value
will be created as link pointing to the certificate details popup.

If neither one is set, the C<creator()> method from the C<Metadata>
Plugin is used as default renderer.

In case the template does not provide a usable value, the tooltip will
show an error message, depending on weather the creator string has a
namespace tag or not.

=cut

sub __render_creator_tooltip {

    my $self = shift;
    my $creator = shift;
    my $field = shift;

    my $cacheid;
    my $value = { value => $creator };
    if (!$field->{nocache}) {
        # Enable caching of the creator information
        # The key is made from the creator name and the template string
        # and bound to the user session to avoid information leakage in
        # case the template binds to the users role/permissions
        $cacheid = Digest::SHA->new()
            ->add($self->_session->id())
            ->add($field->{yaml_template} // $field->{template} // '')
            ->add($creator//'')->hexdigest;

        $self->logger()->trace('creator tooltip cache id ' .  $cacheid);
        my $value = $template_cache->get($cacheid);
        return $value if($value);

    }

    # the field comes with a YAML template = render the field definiton from it
    if ($field->{yaml_template}) {
        $self->logger()->debug('render creator tooltip from yaml template');
        my $val = $self->send_command_v2( render_yaml_template => {
            template => $field->{yaml_template},
            params => { creator => $creator },
        });
        $value = $val if (ref $val eq 'HASH' && $val->{value});

    # use template (or default template) to set username
    } else {
        $self->logger()->debug('render creator name from template');
        my $username = $self->send_command_v2( render_template => {
            template => $field->{template} || '[% USE Metadata; Metadata.creator(creator) %]',
            params => { creator => $creator },
        });
        if ($username) {
            $value->{tooltip} = (($username ne $creator) ? $username : '');
        }
    }

    # creator has no namespace so there was nothing to resolve
    if (!defined $value->{tooltip} && $creator !~ m{\A\w+:}) {
        $value->{tooltip} = 'I18N_OPENXPKI_UI_WORKFLOW_CREATOR_NO_NAMESPACE';
    }

    # still no result
    $value->{tooltip} //= 'I18N_OPENXPKI_UI_WORKFLOW_CREATOR_UNABLE_TO_RESOLVE';

    $self->logger()->trace(Dumper { cacheid => $cacheid, value => $value} );

    $template_cache->set($cacheid => $value) if($cacheid);
    return $value;

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

    my $pager_args = { limit => $limit };
    if ($item->{pager}) {
        $pager_args = $item->{pager};
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

    my $actions = $item->{actions} // [{ path => 'redirect!workflow!load!wf_id!{serial}', icon => 'view' }];

    # create the header from the columns spec
    my ($header, $column, $rattrib) = $self->__render_list_spec( \@cols );

    if ($rattrib) {
        $query->{return_attributes} = $rattrib;
    }

    $self->logger()->trace( "columns : " . Dumper $column) if $self->logger->is_trace;

    my $search_result = $self->send_command_v2( 'search_workflow_instances', { (limit => $limit), %$query } );

    # empty message
    my $empty = $item->{ifempty} || 'I18N_OPENXPKI_UI_TASK_LIST_EMPTY_LABEL';

    my $pager;
    my @data;
    # No results
    if (!@$search_result) {

        return if ($empty eq 'hide');

    } else {

        @data = $self->__render_result_list( $search_result, $column );

        $self->logger()->trace( "dumper result: " . Dumper @data) if $self->logger->is_trace;

        if ($limit == scalar @$search_result) {
            my %count_query = %{$query};
            delete $count_query{order};
            delete $count_query{reverse};
            my $result_count= $self->send_command_v2( 'search_workflow_instances_count', \%count_query  );
            my $queryid = $self->__generate_uid();
            my $_query = {
                'id' => $queryid,
                'type' => 'workflow',
                'count' => $result_count,
                'query' => $query,
                'column' => $column,
                'pager' => $pager_args,
            };
            $self->_client->session()->param('query_wfl_'.$queryid, $_query );
            $pager = $self->__render_pager( $_query, $pager_args );
        }

    }

    $self->add_section({
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

=head2 __check_for_validation_error

Uses last_reply to check if there was a validation error. If a validation
error occured, the field_errors hash is returned and the status variable is
set to render the errors in the form view. Returns undef otherwise.

=cut

sub __check_for_validation_error {

    my $self = shift;
    my $reply = $self->_last_reply();
    if ($reply->{'ERROR'}->{CLASS} eq 'OpenXPKI::Exception::InputValidator' &&
        $reply->{'ERROR'}->{ERRORS}) {
        my $validator_msg = $reply->{'ERROR'}->{LABEL};
        my $field_errors = $reply->{'ERROR'}->{ERRORS};
        if (ref $field_errors eq 'ARRAY') {
            $self->logger()->error("Input validation error on fields ".
                join(",", map { ref $_ ? $_->{name} : $_ } @{$field_errors}));
        } else {
            $self->logger()->error("Input validation error");
        }
        $self->_status({ level => 'error', message => $validator_msg, field_errors => $field_errors });
        $self->logger()->trace('validation details' . Dumper $field_errors ) if $self->logger->is_trace;
        return $field_errors;
    }
    return;
}

sub __get_proc_state_label {
    my ($self, $proc_state) = @_;
    return $proc_state ? $self->__proc_state_i18n->{$proc_state}->{label} : '-';
}

sub __get_proc_state_desc {
    my ($self, $proc_state) = @_;
    return $proc_state ? $self->__proc_state_i18n->{$proc_state}->{desc} : '-';
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

=cut

__PACKAGE__->meta->make_immutable;
