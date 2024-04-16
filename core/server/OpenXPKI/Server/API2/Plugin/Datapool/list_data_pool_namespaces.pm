package OpenXPKI::Server::API2::Plugin::Datapool::list_data_pool_namespaces;
use OpenXPKI::Server::API2::EasyPlugin;

with 'OpenXPKI::Server::API2::Plugin::Datapool::Util';

=head1 NAME

OpenXPKI::Server::API2::Plugin::Datapool::list_data_pool_namespaces

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Types;
use OpenXPKI::DateTime;
use OpenXPKI::Debug;


=head1 COMMANDS

=head2 list_data_pool_namespaces

Return a list of namespaces as array, if I<show_count> is set, returns
a hash with the namespace as key and the item count as value.

B<Parameters>

=over

=item * C<pki_realm> I<Str> - PKI realm. Optional, default: current realm

=item * C<show_count> I<Bool> - if set

=back

=cut
command "list_data_pool_namespaces" => {
    pki_realm     => { isa => 'AlphaPunct', default => sub { CTX('session')->data->pki_realm } },
    show_count    => { isa => 'Bool', required => 0, },
} => sub {
    my ($self, $params) = @_;


    return CTX('dbi')->select_column(
        from   => 'datapool',
        columns => ['namespace'],
        where => {
            pki_realm => $params->pki_realm,
        },
        group_by => [ 'namespace' ],
        order_by => [ 'namespace' ],
    ) if (!$params->show_count);


    my $lines = CTX('dbi')->select_arrays(
        from   => 'datapool',
        columns => ['namespace','count(*)'],
        where => {
            pki_realm => $params->pki_realm,
        },
        group_by => [ 'namespace' ],
    );

    my %counts = map { ($_->[0] =>  $_->[1]) } @{$lines};
    return \%counts;

};

__PACKAGE__->meta->make_immutable;
