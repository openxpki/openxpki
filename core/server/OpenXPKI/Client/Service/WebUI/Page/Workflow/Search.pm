package OpenXPKI::Client::Service::WebUI::Page::Workflow::Search;
use OpenXPKI -class;

extends 'OpenXPKI::Client::Service::WebUI::Page::Workflow';
with 'OpenXPKI::Client::Service::WebUI::PageRole::QueryCache';

# Project modules
use OpenXPKI::DateTime;
use OpenXPKI::i18n qw( i18nGettext );

=head1 UI Methods

=head2 init_search

Render form for the workflow search.
#TODO: Preset parameters

=cut

sub init_search ($self, $args) {
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

=head2 action_search

Handler for the workflow search dialog, consumes the data from the
search form and displays the matches as a grid.

=cut

sub action_search ($self) {
    my $query = { $self->__tenant_param };
    my $verbose = {};
    my $input;

    if (my $type = $self->param('wf_type')) {
        $query->{type} = $type;
        $input->{wf_type} = $type;
        $verbose->{wf_type} = $type;
    }

    if (my $state = $self->param('wf_state')) {
        $query->{state} = [ split /\s/, $state ];
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
    my $spec = $self->session_param('wfsearch')->{default};
    my $attr = $self->__build_attribute_subquery( $spec->{attributes} );

    if (my $wf_creator = $self->param('wf_creator')) {
        $input->{wf_creator} = $wf_creator;
        $attr->{'creator'} = { -like => $self->transate_sql_wildcards($wf_creator) };
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

    $self->log->trace("query : " . Dumper $query) if $self->log->is_trace;

    my $result_count = $self->send_command_v2( 'search_workflow_instances_count', $query );

    # No results founds
    if (!$result_count) {
        # if $result_count is undefined there was an error with the query
        # status was set to the error message from the run_command sub
        $self->status->error('I18N_OPENXPKI_UI_SEARCH_HAS_NO_MATCHES') if (defined $result_count);
        return $self->internal_redirect('workflow!search' => {
            preset => $input,
        });
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

    my $queryid = $self->__save_query({
        pagename => 'workflow',
        count => $result_count,
        query => $query,
        input => $input,
        header => $header,
        column => $body,
        pager_args => OpenXPKI::Util::filter_hash($spec->{pager}, qw(limit pagesizes pagersize)),
        criteria => \@criteria,
    });

    $self->redirect->to("workflow!result!id!${queryid}");

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

__PACKAGE__->meta->make_immutable;
