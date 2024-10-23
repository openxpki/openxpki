package OpenXPKI::Client::Service::WebUI::Page::Workflow::Result;
use OpenXPKI -class;

extends 'OpenXPKI::Client::Service::WebUI::Page::Workflow';
with qw(
    OpenXPKI::Client::Service::WebUI::PageRole::QueryCache
    OpenXPKI::Client::Service::WebUI::PageRole::Pager
);

=head1 UI Methods

=head2 init_result

Load the result of a query, based on a query id and paging information

=cut
sub init_result ($self, $args) {
    my $queryid = $self->param('id');

    # will be removed once inline paging works
    my $startat = $self->param('startat') || 0;

    my $limit = $self->param('limit') || 0;

    if ($limit > 500) {  $limit = 500; }

    # Load query from session
    my $cache = $self->__load_query(workflow => $queryid)
        or return $self->internal_redirect('workflow!search');

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

    my $body = $cache->{column} || $self->default_grid_row;

    my @lines = $self->render_result_list( $search_result, $body );

    $self->log->trace( "dumper result: " . Dumper \@lines) if $self->log->is_trace;

    my $header = $cache->{header} || $self->default_grid_head;

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
            href => $self->client->script_url . '?page=workflow!export!id!'.$queryid,
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

__PACKAGE__->meta->make_immutable;
