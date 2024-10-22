package OpenXPKI::Client::Service::WebUI::Page::Cache;
use OpenXPKI -class;

extends 'OpenXPKI::Client::Service::WebUI::Page';


=head2 init_fetch

Return the data persisted with L<OpenXPKI::Client::Service::WebUI::Page/persist_response>.

=cut
sub init_fetch {
    my $self = shift;

    my $response = $self->param('id');
    my $data = $self->fetch_response( $response );

    if (!$data) {
        $self->log->error('Got empty response');
        $self->redirect->to('home!welcome');
        return;
    }

    $self->log->trace('Cached response retrieved: ' . Dumper($data)) if $self->log->is_trace;

    # support multi-valued responses (persisted as array ref)
    if (ref $data eq 'ARRAY') {
        my $idx = $self->param('idx');
        $self->log->debug("Found mulitvalued response, index is $idx");
        if (!defined $idx || ($idx > scalar @{$data})) {
            die "Parameter 'idx' specifies an invalid index";
        }
        $data = $data->[$idx];
    }

    if (ref $data ne 'HASH') {
        die "Invalid, incomplete or expired fetch statement";
    }

    $data->{mime} = "application/json; charset=UTF-8" unless $data->{mime};

    if ($data->{data}) {
        $self->attachment(
            mimetype => $data->{mime},
            filename => $data->{attachment},
            bytes => $data->{data},
        ),
        return;
    }

    my ($type, $source) = ($data->{source} =~ m{(\w+):(.*)});
    $self->log->debug("Fetching source: $type, key: $source");

    if ('file' eq $type) {
        $self->attachment(
            mimetype => $data->{mime},
            filename => $data->{attachment},
            bytes_callback => sub {
                my $consume = shift;
                open (my $fh, "<", $source) || die "Unable to open '$source': $!";
                while (my $line = <$fh>) { $consume->($line) }
                close $fh;
            },
        );

    } elsif ('datapool' eq $type) {
        # todo - catch exceptions/not found
        my $dp = $self->send_command_v2( 'get_data_pool_entry', {
            namespace => 'workflow.download',
            key => $source,
        });
        die "Requested data not found/expired" unless $dp->{value};
        Encode::encode('UTF-8', $dp->{value}) if $data->{mime} =~ /utf-8/i;
        $self->attachment(
            mimetype => $data->{mime},
            filename => $data->{attachment},
            bytes => $dp->{value},
        );

    } elsif ('report' eq $type) {
        # todo - catch exceptions/not found
        my $report = $self->send_command_v2( 'get_report', {
            name => $source,
            format => 'ALL',
        });
        die "Requested data not found/expired" unless $report;
        $self->attachment(
            mimetype => $report->{mime_type},
            filename => $report->{report_name},
            bytes => $report->{report_value},
        );
    }
}
