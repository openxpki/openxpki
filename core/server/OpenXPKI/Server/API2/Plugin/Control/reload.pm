package OpenXPKI::Server::API2::Plugin::Control::reload;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Control::reload

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::Control;

=head1 COMMANDS

=head2 reload

Send a reload command to the server which will terminate all childs.

This is the same as "openxpkictl reload".

B<Parameters>

none

=cut
command "reload" => {
} => sub {

    my ($self, $params) = @_;

    OpenXPKI::Control::reload();
    return 1;

};

__PACKAGE__->meta->make_immutable;
