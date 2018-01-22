package OpenXPKI::Server::API2::Plugin::Token::get_default_token;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Token::get_default_token

=head1 COMMANDS

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;

=head2 get_default_token

Returns the default token from the system namespace.

=cut
command "get_default_token" => {
} => sub {
    my ($self, $params) = @_;
    return CTX('crypto_layer')->get_system_token({ TYPE => "DEFAULT" });
};

__PACKAGE__->meta->make_immutable;
