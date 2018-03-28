package OpenXPKI::Server::API2::Plugin::UI::get_session_info;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::UI::get_session_info

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 get_session_info

B<Parameters>

=over

=item * C<XXX> I<Bool> - XXX. Default: XXX

=back

=cut
command "get_session_info" => {
} => sub {
    my ($self, $params) = @_;

    my $session = CTX('session');
    return {
        name            => $session->data->user,
        role            => $session->data->role,
        role_label      => CTX('config')->get([ 'auth', 'roles', $session->data->role, 'label' ]),
        pki_realm       => $session->data->pki_realm,
        pki_realm_label => CTX('config')->get([ 'system', 'realms', $session->data->pki_realm, 'label' ]),
        lang            => 'en',
        checksum        => CTX('config')->checksum(),
        sid             => substr($session->id,0,4),
    }
};

__PACKAGE__->meta->make_immutable;
