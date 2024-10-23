package OpenXPKI::Client::Service::WebUI::Page::Workflow::Pager;
use OpenXPKI -class;

extends 'OpenXPKI::Client::Service::WebUI::Page::Workflow';
with qw(
    OpenXPKI::Client::Service::WebUI::PageRole::QueryCache
);

=head1 UI Methods

=head2 init_pager

Similar to init_result but returns only the data portion of the table as
partial result.

=cut

sub init_pager ($self, $args) {
    my $queryid = $self->param('id');

    # Load query from session
    my $cache = $self->__load_query(workflow => $queryid)
        or return $self->internal_redirect('workflow!search');

    my $startat = $self->param('startat');

    my $limit = $self->param('limit') || 25;

    if ($limit > 500) {  $limit = 500; }

    # align startat to limit window
    $startat = int($startat / $limit) * $limit;

    # Add limits
    my $query = $cache->{query};
    $query->{limit} = $limit;
    $query->{start} = $startat;
    $query->{order} = uc($self->param('order')) if $self->param('order');
    $query->{reverse} = $self->param('reverse') if defined $self->param('reverse');

    $self->log->trace( "persisted query: " . Dumper $cache) if $self->log->is_trace;
    $self->log->trace( "executed query: " . Dumper $query) if $self->log->is_trace;

    my $search_result = $self->send_command_v2(search_workflow_instances => $query);
    $self->log->trace( "search result: " . Dumper $search_result) if $self->log->is_trace;

    my $body = $cache->{column} || $self->default_grid_row;

    my @result = $self->render_result_list( $search_result, $body );
    $self->log->trace( "dumper result: " . Dumper @result) if $self->log->is_trace;

    $self->confined_response({ data => \@result });

    return $self;
}

__PACKAGE__->meta->make_immutable;
