package OpenXPKI::Client::Service::WebUI::Page::Workflow::Export;
use OpenXPKI -class;

extends 'OpenXPKI::Client::Service::WebUI::Page::Workflow';
with qw(
    OpenXPKI::Client::Service::WebUI::PageRole::QueryCache
);

# Core modules
use Encode;

# Project modules
use OpenXPKI::DateTime;
use OpenXPKI::i18n qw( i18nTokenizer );

=head1 UI Methods

=head2 init_export

Like init_result but send the data as CSV download, default limit is 500!

=cut

sub init_export ($self, $args) {
    my $queryid = $self->param('id');

    my $limit = $self->param('limit') || 500;
    my $startat = $self->param('startat') || 0;

    # Safety rule
    if ($limit > 500) { $limit = 500; }

    # Load query from session
    my $cache = $self->load_query(workflow => $queryid)
        or return $self->internal_redirect('workflow!search');

    # Add limits
    my $query = $cache->{query};
    $query->{limit} = $limit;
    $query->{start} = $startat;

    if (not $query->{order}) {
        $query->{order} = 'workflow_id';
        if (!defined $query->{reverse}) {
            $query->{reverse} = 1;
        }
    }

    $self->log->trace( "persisted query: " . Dumper $cache) if $self->log->is_trace;

    my $search_result = $self->send_command_v2( 'search_workflow_instances', $query );

    $self->log->trace( "search cache: " . Dumper $search_result) if $self->log->is_trace;

    my $header = $cache->{header} || $self->default_grid_head;

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

    my $body = $cache->{column} || $self->default_grid_row;

    my @lines = $self->render_result_list( $search_result, $body );
    my $colcnt = scalar @head - 1;
    foreach my $line (@lines) {
        my @t = @{$line};
        # this hides invisible fields (assumes that hidden fields are always at the end)
        $buffer .= join("\t", @t[0..$colcnt])."\n"
    }

    if (scalar @{$search_result} == $limit) {
        $buffer .= "I18N_OPENXPKI_UI_CERT_EXPORT_EXCEEDS_LIMIT"."\n";
    }

    $self->attachment(
        mimetype => 'text/tab-separated-values',
        filename => sprintf('workflow export %s.txt', DateTime->now->iso8601),
        bytes => Encode::encode('UTF-8', i18nTokenizer($buffer)),
        expires => '1m',
    );
}

__PACKAGE__->meta->make_immutable;
