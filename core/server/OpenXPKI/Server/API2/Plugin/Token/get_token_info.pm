package OpenXPKI::Server::API2::Plugin::Token::get_token_info;
use OpenXPKI -plugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Token::get_token_info

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );



=head1 COMMANDS

=head2 get_token_info

Returns a hash with information on the token such as name and storage
of the key. Actual output depends on the used token backend.

B<Parameters>

=over

=item * C<alias> I<Str> - Token alias. Required.

=back

=cut
command "get_token_info" => {
    alias  => { isa => 'AlphaPunct', required => 1, },
} => sub {
    my ($self, $params) = @_;

    my $token = CTX('crypto_layer')->get_token({ NAME => $params->alias });

    my $info = $token->get_key_info();

    # if th token exposes a cert we add the identifier
    if ($info->{key_cert}) {
        $info->{key_cert_identifier} = $self->api->get_cert_identifier( cert => $info->{key_cert} );
    }
    return $info;
};

__PACKAGE__->meta->make_immutable;
