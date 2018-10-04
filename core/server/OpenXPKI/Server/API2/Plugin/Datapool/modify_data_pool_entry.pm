package OpenXPKI::Server::API2::Plugin::Datapool::modify_data_pool_entry;
use OpenXPKI::Server::API2::EasyPlugin;

with 'OpenXPKI::Server::API2::Plugin::Datapool::Util';

=head1 NAME

OpenXPKI::Server::API2::Plugin::Datapool::modify_data_pool_entry

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



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
    );

=back

B<Parameters>

=over

=item * C<pki_realm> I<Str> - PKI realm. Optional, default: current realm

=item * C<namespace> I<Str> - datapool namespace (custom string to organize entries)

=item * C<key> I<Str> - key of entry

=item * C<newkey> I<Str> - new key (for renaming operation)

=item * C<expiration_date> I<Int> - UNIX epoch timestamp when the entry shall be
deleted. If set I<undef>, the entry is kept infinitely.

=back

B<Changes compared to API v1:>

Previously the parameter C<namespace> was optional which was a bug.

=cut
command "modify_data_pool_entry" => {
    pki_realm       => { isa => 'AlphaPunct', default => sub { CTX('session')->data->pki_realm } },
    namespace       => { isa => 'AlphaPunct', required => 1, },
    key             => { isa => 'Str', matching => qr/(?^msx: \A \$? [ \w \- \. : \s ]* \z )/, required => 1, },
    newkey          => { isa => 'Str', matching => qr/(?^msx: \A \$? [ \w \- \. : \s ]* \z )/, },
    expiration_date => { isa => 'Str|Undef', matching => sub { defined $_ ? ($_ =~ qr/(?^msx: \A (?:(?:[-+]?)(?:[0123456789]+))* \z )/) : 1 }, },
} => sub {
    my ($self, $params) = @_;

    my $requested_pki_realm = $params->pki_realm;

    # when called from a workflow we only allow the current realm
    # NOTE: only check direct caller. if workflow is deeper in the caller
    # chain we assume it's ok.
    $self->assert_current_pki_realm_within_workflow($requested_pki_realm);

    my $new_values = {
        $params->has_newkey ? ('datapool_key' => $params->newkey) : (),
        'last_update' => time,
    };

    if ($params->has_expiration_date) {
        my $exp = $params->expiration_date;
        $new_values->{notafter} = $exp; # may be undef

        if (defined $exp) {
            if ($exp < 0 or ($exp > 0 and $exp < time)) {
                OpenXPKI::Exception->throw(
                    message => 'Invalid expiration date',
                    params => {
                        pki_realm       => $requested_pki_realm,
                        namespace       => $params->namespace,
                        key             => $params->key,
                        expiration_date => $exp,
                    },
                );
            }
        }
    }

    ##! 16: 'update database condition: ' . Dumper \%condition
    ##! 16: 'update database values: ' . Dumper \%values

    my $result = CTX('dbi')->update(
        table => 'datapool',
        set   => $new_values,
        where => {
            pki_realm    => $requested_pki_realm,
            datapool_key => $params->key,
            namespace    => $params->namespace,
        },
    );

    return 1;
};

__PACKAGE__->meta->make_immutable;
