package OpenXPKI::Server::API2::Plugin::Datapool::list_data_pool_entries;
use OpenXPKI::Server::API2::EasyPlugin;

with 'OpenXPKI::Server::API2::Plugin::Datapool::Util';

=head1 NAME

OpenXPKI::Server::API2::Plugin::Datapool::list_data_pool_entries

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 list_data_pool_entries

List all keys in the datapool in a given namespace.


=over

=item * NAMESPACE

=item * PKI_REALM, optional, see get_data_pool_entry for details.

=item * LIMIT, optional, max number of entries returned

=back

Returns an arrayref of Namespace and key of all entries found.

B<Parameters>

=over

=item * C<XXX> I<Bool> - XXX. Default: XXX

=back

=cut
command "list_data_pool_entries" => {
    namespace => { isa => 'AlphaPunct', },
    pki_realm => { isa => 'AlphaPunct', default => sub { CTX('session')->data->pki_realm } },
    limit     => { isa => 'Int', },
} => sub {
    my ($self, $params) = @_;

    my $requested_pki_realm = $params->pki_realm;

    # when called from a workflow we only allow the current realm
    # NOTE: only check direct caller. if workflow is deeper in the caller
    # chain we assume it's ok.
    $self->assert_current_pki_realm_within_workflow($requested_pki_realm);

    my $result = CTX('dbi')->select(
        from   => 'datapool',
        columns => [ qw( namespace datapool_key ) ],
        where => {
            pki_realm => $requested_pki_realm,
            $params->has_namespace ? (namespace => $params->namespace) : (),
        },
        order_by => [ 'datapool_key', 'namespace' ],
        $params->has_limit ? ( limit => $params->limit ) : (),
    )->fetchall_arrayref({});

    return [
        map { {
            namespace => $_->{namespace},
            key       => $_->{datapool_key},
        } } @$result
    ];
};

__PACKAGE__->meta->make_immutable;
