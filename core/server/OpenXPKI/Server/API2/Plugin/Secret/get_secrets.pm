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
        },
        'mykey' => {
            'label' => 'Main password',
            'type' => 'plain'
        },
    }

B<Changes compared to API v1:>

The returned I<HashRef> now contains lowercase keys.

=cut
command "get_secrets" => {
} => sub {
    my ($self, $params) = @_;
    my %secrets = CTX('crypto_layer')->get_secret_groups;
    # convert key case
    return { map {
        $_ => {
            label => $secrets{$_}->{LABEL},
            type =>  $secrets{$_}->{TYPE},
        }
    } keys %secrets };
};

__PACKAGE__->meta->make_immutable;
