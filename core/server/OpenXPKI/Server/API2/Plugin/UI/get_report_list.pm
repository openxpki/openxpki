package OpenXPKI::Server::API2::Plugin::UI::get_report_list;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::UI::get_report_list

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 get_report_list

Return a list of reports, both parameters are optionsal.
I<NAME> is evaluated using SQL Like so it can be used to filter for a
name pattern. I<MAXAGE> must be a definition parsable by
OpenXPKI::DateTime, items older than MAXAGE or not returned.

Returns an I<ArrayRef> of I<ArrayRef> with the selected values in the given
column order.

Default columns if not specified:

    report_name  created  description  mime_type

B<Parameters>

=over

=item * C<XXX> I<Bool> - XXX. Default: XXX

=back

=cut
command "get_report_list" => {
    name    => { isa => 'Str', },
    columns => { isa => 'ArrayRefOrCommaList', coerce => 1, default => sub { [qw( report_name created description mime_type )] } },
    maxage  => { isa => 'AlphaPunct', },
} => sub {
    my ($self, $params) = @_;

    my $where = {
        pki_realm => CTX('session')->data->pki_realm,
        $params->has_name
            ? (report_name => { -like => $params->name }) : (),
    };

    if ($params->has_maxage) {
        my $maxage = OpenXPKI::DateTime::get_validity({
            VALIDITY => $params->maxage,
            VALIDITYFORMAT => 'detect',
        });
        $where->{created} = { '>=', $maxage->epoch() };
    }

    ##! 32: 'Search report ' . Dumper $where

    my $sth = CTX('dbi')->select(
        from => 'report',
        order_by => [ 'report_name' ],
        columns  => $params->columns,
        where => $where,
    );

    my @items;
    while (my @row = $sth->fetchrow_array) {
       push @items, \@row;
    }
    return \@items;
};

__PACKAGE__->meta->make_immutable;
