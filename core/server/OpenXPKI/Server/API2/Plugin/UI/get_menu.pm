package OpenXPKI::Server::API2::Plugin::UI::get_menu;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::UI::get_menu

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 get_menu

Returns the UI menu definition (I<HashRef>) for the current role (or for pseudo
role I<_default> if there is no config for the current role).

=cut
command "get_menu" => {
} => sub {
    my ($self, $params) = @_;

    my $role = CTX('session')->data->role;
    $role = '_default' unless CTX('config')->exists( ['uicontrol', $role ] );

    # we silently assume that the config layer node can return a deep hash ;)
    return CTX('config')->get_hash( [ 'uicontrol', $role ], { deep => 1 });
};

__PACKAGE__->meta->make_immutable;
