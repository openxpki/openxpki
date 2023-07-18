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

Per default only entries which are not yet expired are returned.

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

Supports asterisk C<*> as wildcard to do a substring search, e.g. C<*cert> for all keys ending with "cert"

=item * C<limit> I<Int> - max. number of entries returned. Optional.

=item * C<start> I<Int> - only return entries starting at given index (can only be used if C<limit> was specified). Optional.

=item * C<metadata> I<Bool> - add mtime and expiration date to the result (epoch)

=item * Cvalues> I<Bool> - add values to the result (attention - these may be objects)

=item * C<mtime_after> I<Str> - only return entries last modified B<after>
given dateC<**>. Optional.

=item * C<mtime_before> I<Str> - only return entries last modified B<before>
given dateC<**>. Optional.

=item * C<expires_after> I<Str> - only return entries expiring B<after> given
dateC<**>. Optional.

Default (but only if also C<expires_before> is B<not> given):
return entries not yet expired.

Also returns entries without an expiration date.

=item * C<expires_before> I<Str> - only return entries expiring B<before> given
dateC<**>. Optional.

C<**> dates are handled by L<OpenXPKI::DateTime/get_validity> with C<VALIDITYFORMAT = 'detect'>

=back

=cut
my %common_params = (
    pki_realm => { isa => 'AlphaPunct', default => sub { CTX('session')->data->pki_realm } },
    namespace => { isa => 'AlphaPunct' },
    key_name => { isa => 'Str', required => 0 },
    mtime_after => { isa => 'Str', required => 0 },
    mtime_before => { isa =>'Str', required => 0 },
    expires_after => { isa => 'Str', required => 0 },
    expires_before => { isa =>'Str', required => 0 },
);

command "list_data_pool_entries" => {
    %common_params,
    limit     => { isa => 'Int', required => 0 },
    start     => { isa => 'Int', required => 0 },
    metadata  => { isa => 'Bool', default => 0 },
    values    => { isa => 'Bool', default => 0 },
} => sub {
    my ($self, $params) = @_;

    # when called from a workflow we only allow the current realm
    # NOTE: only check direct caller. if workflow is deeper in the caller
    # chain we assume it's ok.
    $self->assert_current_pki_realm_within_workflow($params->pki_realm);

    my $sql_params = $self->_make_db_query($params, $params->metadata, $params->values);

    if ($params->has_limit) {
        $sql_params->{limit} = $params->limit;
        $sql_params->{offset} = $params->start if $params->has_start;
    }

    ##! 32: 'Query ' . Dumper $sql_params
    my $data = CTX('dbi')->select_hashes($sql_params->%*);

    # translate SQL columns to returned hash keys
    my %translate = (
        datapool_key => 'key',
        datapool_value => 'value',
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

    # when called from a workflow we only allow the current realm
    # NOTE: only check direct caller. if workflow is deeper in the caller
    # chain we assume it's ok.
    $self->assert_current_pki_realm_within_workflow($params->pki_realm);

    my $sql_params = $self->_make_db_query($params);

    ##! 32: 'Query ' . Dumper $sql_params
    return CTX('dbi')->count($sql_params->%*);
};

sub _validity_to_condition {
    my $self = shift;
    my $after_input = shift;
    my $before_input = shift;
    my $include_empty_after = shift;

    use OpenXPKI::DateTime;
    my $to_epoch = sub {
        return OpenXPKI::DateTime::get_validity({
            VALIDITY => shift,
            VALIDITYFORMAT => 'detect',
        })->epoch
    };

    my $after = $to_epoch->($after_input) if $after_input;
    my $before = $to_epoch->($before_input) if $before_input;

    my $condition;
    if ($after and $before) {
        $condition = { -between => [ $after, $before ] };
    } elsif ($after) {
        $condition = $include_empty_after
            ? [ { '>' => $after }, undef ] # "> $after OR undef"
            : { '>' => $after };
    } elsif ($before) {
        $condition = { '<' => $before };
    }

    return $condition;
}

sub _make_db_query {
    my ($self, $params, $with_metadata, $with_values) = @_;

    # convert asterisk wildcard to SQL percent
    my $key_name = $params->has_key_name
        ? OpenXPKI::Util->asterisk_to_sql_wildcard($params->key_name)
        : undef;

    # convert mtime_* and expires_* to WHERE clause
    my %additional_where;

    $additional_where{last_update} = $self->_validity_to_condition(
        $params->mtime_after, $params->mtime_before
    ) if ($params->mtime_after or $params->mtime_before);

    if ($params->expires_after or $params->expires_before) {
        $additional_where{notafter} = $self->_validity_to_condition(
            $params->expires_after, $params->expires_before, 1
        );
    } else {
        $additional_where{notafter} = [ { '>' => time }, undef ]; # "> time OR undef"
    }

    # assemble query
    return {
        from   => 'datapool',
        columns => [
            'namespace',
            'datapool_key',
            $with_metadata ? (
                'last_update',
                'notafter',
                'CASE WHEN encryption_key IS NULL THEN 0 ELSE 1 END AS encrypted',
            ) : (),
            $with_values ? (
                'datapool_value'
            ) : (),
        ],
        where => {
            pki_realm => $params->pki_realm,
            $params->has_namespace ? (namespace => $params->namespace) : (),
            defined($key_name) ? (datapool_key => { -like => $key_name }) : (),
            %additional_where,
        },
        order_by => [ 'datapool_key', 'namespace' ],
    };
}

__PACKAGE__->meta->make_immutable;
