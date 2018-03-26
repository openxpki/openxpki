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

This method has two purposes, both require NAMESPACE and KEY.
B<This method does not modify the value of the entry>.

=over

=item Change the entries key

Used to update the key of entry. Pass the name of the new key in NEWKEY.
I<Commonly used to deal with temporary keys>

=item Change expiration information

Set the new EXPIRATION_DATE, if you set the parameter to undef, the expiration
date is set to infity.

=back

B<Parameters>

=over

=item * C<XXX> I<Bool> - XXX. Default: XXX

=back

=cut
command "modify_data_pool_entry" => {
    namespace       => { isa => 'AlphaPunct', },
    pki_realm       => { isa => 'AlphaPunct', default => sub { CTX('session')->data->pki_realm } },
    key             => { isa => 'Str', matching => qr/(?^msx: \A \$? [ \w \- \. : \s ]* \z )/, required => 1, },
    newkey          => { isa => 'Str', matching => qr/(?^msx: \A \$? [ \w \- \. : \s ]* \z )/, required => 1, },
    expiration_date => { isa => 'Str', matching => qr/(?^msx: \A (?:(?:[-+]?)(?:[0123456789]+))* \z )/, },
} => sub {
    my ($self, $params) = @_;

    my $requested_pki_realm = $params->pki_realm;

    # when called from a workflow we only allow the current realm
    # NOTE: only check direct caller. if workflow is deeper in the caller
    # chain we assume it's ok.
    $self->assert_current_pki_realm_within_workflow($requested_pki_realm);

    my %values = (
        'datapool_key' => $params->newkey,
        'last_update' => time,
    );

    if ($params->has_expiration_date) {
        my $expiration_date = $params->expiration_date;
        $values{notafter} = $expiration_date; # may be undef

        if ( defined $expiration_date ) {
            if (   ( $expiration_date < 0 )
                or ( $expiration_date > 0 and $expiration_date < time ) ) {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SET_DATA_POOL_INVALID_EXPIRATION_DATE',
                    params => {
                        pki_realm       => $requested_pki_realm,
                        namespace       => $params->namespace,
                        key             => $params->key,
                        expiration_date => $expiration_date,
                    },
                );
            }
        }
    }

    ##! 16: 'update database condition: ' . Dumper \%condition
    ##! 16: 'update database values: ' . Dumper \%values

    my $result = CTX('dbi')->update(
        table => 'datapool',
        set   => \%values,
        where => {
            pki_realm    => $requested_pki_realm,
            datapool_key => $params->key,
            $params->has_namespace
                ? ( namespace => $params->namespace ) : (),
        },
    );

    return 1;
};

__PACKAGE__->meta->make_immutable;
