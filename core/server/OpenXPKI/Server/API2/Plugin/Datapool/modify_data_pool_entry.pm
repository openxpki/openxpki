package OpenXPKI::Server::API2::Plugin::Datapool::modify_data_pool_entry;
use OpenXPKI::Server::API2::EasyPlugin;

with 'OpenXPKI::Server::API2::Plugin::Datapool::Util';

=head1 NAME

OpenXPKI::Server::API2::Plugin::Datapool::modify_data_pool_entry

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::DateTime;
use OpenXPKI::Debug;


=head1 COMMANDS

=head2 modify_data_pool_entry

Modifies the specified datapool entry key.

You B<cannot modify the value> with this command. To do so use
L<OpenXPKI::Server::API2::Plugin::Datapool::set_data_pool_entry/set_data_pool_entry>
with parameter C<force> instead.

This method supports two operations (which can be done simultaneously):

=over

=item Rename entry (change it's key)

Pass the name of the new key in C<newkey>. Commonly used to deal with temporary
keys.

    CTX('api2')->modify_data_pool_entry(
        pki_realm => $pki_realm,
        namespace => 'workflow.foo.bar',
        key       => 'myvariable',
        newkey    => 'myvar',
    );

=item Change expiration information

Set the new C<expiration_date>.

    CTX('api2')->modify_data_pool_entry(
        pki_realm       => $pki_realm,
        namespace       => 'workflow.foo.bar',
        key             => 'myvariable',
        expiration_date => 123456,
        expiration_adjust => 'newer'
    );

=back

In case you pass neither an expiration nor a key update parameter the method
will just touch the I<last_update> timestamp of the item. As this is just a
metadata and not used in the usual workflow logic there is no obvious reason
to do so.

B<Parameters>

=over

=item * C<pki_realm> I<Str> - PKI realm. Optional, default: current realm

=item * C<namespace> I<Str> - datapool namespace (custom string to organize entries)

=item * C<key> I<Str> - key of entry

=item * C<newkey> I<Str> - new key (for renaming operation)

=item * C<expiration_date> I<Int> - UNIX epoch timestamp or OpenXPKI::DataTime
relative date when the entry shall be deleted.
If set I<undef>, the entry is kept infinitely.

=item * C<expiration_adjust> I<Str> (newer|older|strict)

Policy when updating the I<expiration_date>. If set to I<newer>, the expiration
date is only updated if the given value is newer as the one already set. Same
applies to I<older>.

I<strict> always applies the new value which is also the default behaviour.

Please note that with I<expiration_date = undef> this flag is ignored.

The adjustment rules do not interfere with I<newkey>, so a key change is always
done even if the date adjustment rules fail.

=back

B<Changes compared to API v1:>

Previously the parameter C<namespace> was optional which was a bug.

=cut
command "modify_data_pool_entry" => {
    pki_realm       => { isa => 'AlphaPunct', default => sub { CTX('session')->data->pki_realm } },
    namespace       => { isa => 'AlphaPunct', required => 1, },
    key             => { isa => 'AlphaPunct|Email', required => 1, },
    newkey          => { isa => 'AlphaPunct|Email', },
    expiration_date => { isa => 'Str|Undef', matching => sub { defined $_ ? ($_ =~ qr/(?^msx: \A \+?\d+ \z)/) : 1 }, },
    expiration_adjust => { isa => 'Str', matching => qr/newer|older|strict/, default => 'strict' },
    ignore_missing => { isa => 'Bool', default => 0 },
} => sub {
    my ($self, $params) = @_;

    my $requested_pki_realm = $params->pki_realm;

    # when called from a workflow we only allow the current realm
    # NOTE: only check direct caller. if workflow is deeper in the caller
    # chain we assume it's ok.
    $self->assert_current_pki_realm_within_workflow($requested_pki_realm);

    # check if the value is there at all
    my $existing = $self->get_entry($requested_pki_realm, $params->namespace, $params->key);
    ##! 64: $existing

    # no entry found, raise exception unless ignore_missing was set
    if (not $existing) {
        OpenXPKI::Exception->throw(
            message => 'Data pool entry not found',
            params => {
                pki_realm       => $requested_pki_realm,
                namespace       => $params->namespace,
                key             => $params->key,
            },
        ) unless($params->ignore_missing);
        CTX('log')->system()->debug("Data pool entry to modify not found");
        return;
    }

    my $new_values;
    my %extra_where;
    if ($params->has_expiration_date) {
        my $exp = $params->expiration_date;
        my $current = $existing->{notafter} || 0;
        # undef = set to infinity, ignores adjust restriction
        if (not defined $exp) {
            ##! 16: "Infiiiiiinitiy..."
            $new_values->{notafter} = undef;
        } else {
            my $expiry = OpenXPKI::DateTime::get_validity({
                VALIDITY => $exp,
                VALIDITYFORMAT => 'detect',
            })->epoch();

            my $adjust = $params->expiration_adjust;
            # yes we could merge this all in some perlish equotations but this makes it more clear ;)
            ##! 16: "Adjust policy $adjust, new value: $expiry, existing value $current"
            if ($adjust eq 'newer') {
                if ($current > 0 && $expiry > $current) {
                    $new_values->{notafter} = $expiry;
                    $extra_where{notafter} = {'<', $expiry};
                } else {
                    CTX('log')->system()->debug("Ignore new expiration date as it is not newer");
                }
            } elsif ($adjust eq 'older') {
                if ($expiry < $current) {
                    $new_values->{notafter} = $expiry;
                    $extra_where{notafter} = {'>', $expiry};
                } else {
                    CTX('log')->system()->debug("Ignore new expiration date as it is not older");
                }
            } else {
                $new_values->{notafter} = $expiry;
            }
        }
        $new_values->{last_update} = time if (exists $new_values->{notafter});
    } else {
        # if we do not pass anything else we touch the item
        $new_values->{last_update} = time;
    }

    if ($params->has_newkey()) {
        $new_values->{datapool_key} = $params->newkey;
        $new_values->{last_update} = time;
    }

    if (!keys %{$new_values}) {
        CTX('log')->system()->debug("Ignore modify request as there is nothing to update");
        return;
    }

    ##! 32: $new_values

    CTX('dbi')->update(
        table => 'datapool',
        set   => $new_values,
        where => {
            pki_realm    => $requested_pki_realm,
            datapool_key => $params->key,
            namespace    => $params->namespace,
            %extra_where
        },
    );

    return {
        pki_realm    => $requested_pki_realm,
        namespace    => $params->namespace,
        datapool_key => $params->key,
        %{$new_values}
    };
};

__PACKAGE__->meta->make_immutable;
