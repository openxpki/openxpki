package OpenXPKI::Server::API2::Plugin::Profile::list_used_profiles;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Profile::list_used_profiles

=head1 COMMANDS

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );

=head2 list_used_profiles

List profiles that are used for entity certificates in specified PKI realm.

B<Parameters>

=over

=item * C<pki_realm> I<Str> - PKI realm to query, defaults to the session realm

=back

=cut
command "list_used_profiles" => {
    pki_realm => { isa => 'AlphaPunct' },
} => sub {
    my ($self, $params) = @_;

    my $pki_realm = $params->has_pki_realm ? $params->pki_realm : CTX('session')->data->pki_realm;

    my $profiles = CTX('dbi')->select(
        from => 'csr',
        columns => [ -distinct => 'profile' ],
        where => { pki_realm => $pki_realm },
    )->fetchall_arrayref({});

    return [
        map {
            {
                value => $_->{profile},
                label => CTX('config')->get(['profile', $_->{profile}, 'label']) || $_->{profile},
            }
        } @$profiles
    ];
};

__PACKAGE__->meta->make_immutable;
