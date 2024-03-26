package OpenXPKI::Server::API2::Plugin::Token::get_token_info;
use OpenXPKI::Server::API2::EasyPlugin;

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

    my $info = $token->get_key_info();

    $info->{token_type} = $token_type;

    # if th token exposes a cert we add the identifier
    if ($info->{key_cert}) {
        $info->{key_cert_identifier} = $self->api->get_cert_identifier( cert => $info->{key_cert} );
    }
    return $info;
};

__PACKAGE__->meta->make_immutable;
