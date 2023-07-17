package OpenXPKI::Server::API2::Plugin::Datapool::list_data_pool_entries;
use OpenXPKI::Server::API2::EasyPlugin;

with 'OpenXPKI::Server::API2::Plugin::Datapool::Util';

=head1 NAME

OpenXPKI::Server::API2::Plugin::Datapool::list_data_pool_entries

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::Util;


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

=item * C<key_name> I<Str> - search pattern for datapool keys. Optional.

Supports asterisk C<*> as wildcard to do a substring search.

=item * C<limit> I<Int> - max. number of entries returned. Optional.

=item * C<metadata> I<Bool> - add mtime and expiration date to the result (epoch)

=back

=cut
my %common_params = (
    pki_realm => { isa => 'AlphaPunct', default => sub { CTX('session')->data->pki_realm } },
    namespace => { isa => 'AlphaPunct' },
    key_name  => { isa => 'Str' },
);

command "list_data_pool_entries" => {
    %common_params,
    limit     => { isa => 'Int' },
    metadata  => { isa => 'Bool', default => 0 },
} => sub {
    my ($self, $params) = @_;

    # when called from a workflow we only allow the current realm
    # NOTE: only check direct caller. if workflow is deeper in the caller
    # chain we assume it's ok.
    $self->assert_current_pki_realm_within_workflow($params->pki_realm);

    my $sql_params = $self->_make_db_query($params);

    $sql_params->{limit} = $params->limit if $params->has_limit;
    push $sql_params->{columns}->@*, (
        'last_update',
        'notafter',
        'CASE WHEN encryption_key IS NULL THEN 0 ELSE 1 END AS encrypted',
    ) if $params->metadata;

    ##! 32: 'Query ' . Dumper $sql_params
    my $data = CTX('dbi')->select_hashes($sql_params->%*);

    # translate SQL columns to returned hash keys
    my %translate = (
        datapool_key => 'key',
        last_update => 'mtime',
        notafter => 'expiration_date',
    );

    my @result = map {
        my $tuple = $_;
        +{
            map { ($translate{$_} // $_) => $tuple->{$_} } keys $tuple->%*
        }
    } $data->@*;

    return \@result;

};

=head2 list_data_pool_entries_count

Similar to L</list_data_pool_entries> but only returns the number of matching rows.

B<Parameters>

All parameters are optional and can be used to filter the result list:

see L</list_data_pool_entries> for parameter list (except C<limit> and
C<metadata> parameters which are not used in C<list_data_pool_entries_count>).

=cut
command "list_data_pool_entries_count" => {
    %common_params
} => sub {
    my ($self, $params) = @_;

    my $sql_params = $self->_make_db_query($params);

    ##! 32: 'Query ' . Dumper $sql_params
    return CTX('dbi')->count($sql_params->%*);
};


sub _make_db_query {
    my ($self, $params) = @_;

    # convert asterisk wildcard to SQL percent
    my $key_name = $params->has_key_name
        ? OpenXPKI::Util->asterisk_to_sql_wildcard($params->key_name)
        : undef;

    return {
        from   => 'datapool',
        columns => [ 'namespace', 'datapool_key' ],
        where => {
            pki_realm => $params->pki_realm,
            $params->has_namespace ? (namespace => $params->namespace) : (),
            defined($key_name) ? (datapool_key => { -like => $key_name }) : (),
            notafter => [ { '>' => time }, undef ],
        },
        order_by => [ 'datapool_key', 'namespace' ],
    };
}

__PACKAGE__->meta->make_immutable;
