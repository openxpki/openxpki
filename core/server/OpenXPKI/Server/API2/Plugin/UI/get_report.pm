package OpenXPKI::Server::API2::Plugin::UI::get_report;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::UI::get_report

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 get_report

retrieve data from the report table, name is mandatory, realm is always
the session realm. By default, only the meta-information of the report is
returned (report_name, description, mime_type, created). With I<FORMAT=DATA>
only the data blob is given (might be binary!), I<FORMAT=ALL> is the same
as HASH with the data added in the "report_value" column.

B<Parameters>

=over

=item * C<XXX> I<Bool> - XXX. Default: XXX

=back

=cut
command "get_report" => {
    name   => { isa => 'AlphaPunct', required => 1, },
    format => { isa => 'Str', matching => qr{ \A ( ALL | HASH | DATA ) \Z }msx, default => "HASH", },
} => sub {
    my ($self, $params) = @_;

    my $name = $params->name;
    my $format = $params->format;

    my $columns;
    if ('ALL' eq $format) {
        $columns = ['*'];
    }
    elsif ('DATA' eq $format) {
        $columns = ['report_value'];
    }
    else {
        $columns = ['report_name','created','mime_type','description'];
    }

    ##! 16: 'Search for ' . $name
    my $report = CTX('dbi')->select_one(
        columns => $columns,
        from => 'report',
        where => { report_name => $name, pki_realm => CTX('session')->data->pki_realm },
    )
        or OpenXPKI::Exception->throw(
            message => 'Report not found',
            params => { name => $name },
        );

    ##! 64: 'Return value ' . Dumper $report
    if ('DATA' eq $format) {
        return $report->{report_value};
    }
    else {
        return $report;
    }
};

__PACKAGE__->meta->make_immutable;
