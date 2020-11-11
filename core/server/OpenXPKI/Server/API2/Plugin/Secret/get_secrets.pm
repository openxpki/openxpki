package OpenXPKI::Server::API2::Plugin::Secret::get_secrets;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Secret::get_secrets

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 get_secrets

Return a I<HashRef> with type and name of all secret groups in the current realm.

Example:

    {
        'default' => {
            'label' => 'Default secret group of this realm',
            'type' => 'literal'
            'complete' => 1,
            'required_parts' => 3,
            'inserted_parts' => 3,
        },
        'mykey' => {
            'label' => 'Main password',
            'type' => 'plain'
            'complete' => 0,
            'required_parts' => 1,
            'inserted_parts' => 0,
        },
    }

B<Changes compared to API v1:>

The returned I<HashRef> now contains lowercase keys.

=cut
command "get_secrets" => {
} => sub {
    my ($self, $params) = @_;

    return CTX('crypto_layer')->get_secret_infos;
};

__PACKAGE__->meta->make_immutable;
