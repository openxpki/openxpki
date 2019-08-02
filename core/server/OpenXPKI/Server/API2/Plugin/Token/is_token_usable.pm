package OpenXPKI::Server::API2::Plugin::Token::is_token_usable;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Token::is_token_usable

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );



=head1 COMMANDS

=head2 is_token_usable

Checks if the token with the given alias is usable and returns true (1) or
false (undef).

B<Parameters>

=over

=item * C<alias> I<Str> - Token alias. Required.

=item * C<operation> I<Str> - type of operation to use for the key check,
optional - default depends on token type.

=over

=item sign

Do a pkcs7 sign and verify cycle. This is the default.

=item encrypt

Do a pkcs7 encrypt / decrypt cycle.
Default if the token is of type I<datasafe>.

=item engine

Use the crypto engine's C<key_usable> method to test the token.

=back

=item * C<engine> I<Bool> - Default: 0

Same as operation=<engine, deprecated, provided for backward compatibility.

=back

=cut
command "is_token_usable" => {
    alias  => { isa => 'AlphaPunct', required => 1, },
    engine => { isa => 'Bool', },
    operation => { isa => 'Str', matching => qr{ \A ( sign | encrypt | engine ) \Z }x },

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
    my $token_type = $types{$1};

    my $token = CTX('crypto_layer')->get_token({ TYPE => $token_type, NAME => $params->alias });

    my $operation;
    if ($params->engine) {
        $operation = 'engine';
    } elsif ($params->operation) {
        $operation = $params->operation;
    } elsif ($token_type eq 'datasafe') {
        $operation = 'encrypt';
    } else {
        $operation = 'sign';
    }

    # Shortcut method, ask the token engine
    if ($operation eq 'engine') {
        CTX('log')->application()->debug('Check if token is usable using engine');
        return $token->key_usable()
    }

    return OpenXPKI::Server::API2::Plugin::Token::Util->is_token_usable($token, $operation);
};

__PACKAGE__->meta->make_immutable;
