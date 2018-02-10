package OpenXPKI::Server::API2::Plugin::UI::list_process;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::UI::list_process

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 list_process

Returns informations about all child processes of the server process:

    [
    ]

=cut
command "list_process" => {
} => sub {
    my ($self, $params) = @_;
    return OpenXPKI::Control::list_process();
};

__PACKAGE__->meta->make_immutable;
