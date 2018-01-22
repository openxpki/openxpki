package OpenXPKI::Server::API2::Plugin::Token::is_token_usable;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Token::is_token_usable

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 is_token_usable

Checks if the token with the given alias is usable and returns true (1) or
false (undef).

By default, a pkcs7 encrypt / decrypt cycle is used to test if the token is
working (i.e. "online").

If you set C<engine> to 1 the crypto engine's C<key_usable> method is used instead.

B<Parameters>

=over

=item * C<alias> I<Str> - Token alias. Required.

=item * C<engine> I<Bool> - Use the crypto engine's C<key_usable> method to test
the token. Default: 0

=back

=cut
command "is_token_usable" => {
    alias  => { isa => 'AlphaPunct', required => 1, },
    engine => { isa => 'Bool',       },
} => sub {
    my ($self, $params) = @_;

    my %types = reverse %{ CTX('config')->get_hash('crypto.type') };

    my $alias = $params->alias;
    # strip off the generation number
    $alias =~ /^(.*)-(\d+)$/;
    if (not $1 or not $types{$1}) {
        OpenXPKI::Exception->throw (
            message => 'Unable to determine token type by alias',
            params => { alias => $alias },
        );
    }
    my $token = CTX('crypto_layer')->get_token({ TYPE => $types{$1}, NAME => $params->alias });

    # Shortcut method, ask the token engine
    if ($params->engine) {
        CTX('log')->application()->debug('Check if token is usable using engine');
        return $token->key_usable()
    }

    return OpenXPKI::Server::API2::Plugin::Token::Util->is_token_usable($token);
};

__PACKAGE__->meta->make_immutable;
