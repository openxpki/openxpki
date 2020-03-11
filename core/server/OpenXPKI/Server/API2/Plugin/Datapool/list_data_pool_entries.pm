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

Returns an I<ArrayRef[HashRef]>:

    [
        { namespace => '...', key => '...' },
        { namespace => '...', key => '...' },
        ...
    ]

B<Parameters>

=over

=item * C<pki_realm> I<Str> - PKI realm. Optional, default: current realm

If the API is called directly from OpenXPKI::Server::Workflow only the PKI realm
of the currently active session is accepted.

=item * C<namespace> I<Str> - datapool namespace (custom string to organize entries)

=item * C<limit> I<Int> - max. number of entries returned. Optional.

=item * C<metadata> I<Bool> - add mtime and expiration date to the result (epoch)

=back

=cut
command "list_data_pool_entries" => {
    namespace => { isa => 'AlphaPunct', },
    pki_realm => { isa => 'AlphaPunct', default => sub { CTX('session')->data->pki_realm } },
    limit     => { isa => 'Int', },
    metadata  => { isa => 'Bool', },
} => sub {
    my ($self, $params) = @_;

    my $requested_pki_realm = $params->pki_realm;

    # when called from a workflow we only allow the current realm
    # NOTE: only check direct caller. if workflow is deeper in the caller
    # chain we assume it's ok.
    $self->assert_current_pki_realm_within_workflow($requested_pki_realm);


    my @colums = qw( namespace datapool_key );
    if ($params->has_metadata && $params->metadata) {
        push @colums, "last_update", "notafter";
    }

    my $result = CTX('dbi')->select(
        from   => 'datapool',
        columns => \@colums,
        where => {
            pki_realm => $requested_pki_realm,
            $params->has_namespace ? (namespace => $params->namespace) : (),
            notafter => [ { '>' => time }, undef ],
        },
        order_by => [ 'datapool_key', 'namespace' ],
        $params->has_limit ? ( limit => $params->limit ) : (),
    )->fetchall_arrayref({});

    my @res;
    if ($params->has_metadata && $params->metadata) {
        @res = map { {
            namespace => $_->{namespace},
            key       => $_->{datapool_key},
            mtime     => $_->{last_update},
            expiration_date => $_->{notafter} // '',
        } } @$result
    } else {
        @res = map { {
            namespace => $_->{namespace},
            key       => $_->{datapool_key},
        } } @$result
    }
    return \@res;

};

__PACKAGE__->meta->make_immutable;
