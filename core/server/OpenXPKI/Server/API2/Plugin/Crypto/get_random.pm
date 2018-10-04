package OpenXPKI::Server::API2::Plugin::Crypto::get_random;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Crypto::get_random

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 get_random

Generates and returns Base64 encoded pseudo-random bytes.

B<Parameters>

=over

=item * C<length> I<Int> - length in bytes.

Please note that the returned string is Base64 encoded an thus longer.

=back

=cut
command "get_random" => {
    length => { isa => 'Int', required => 1, },
} => sub {
    my ($self, $params) = @_;
    my $length  = $params->length;
    ##! 4: 'length: ' . $length

    my $random = CTX('api')->get_default_token->command({
        COMMAND => 'create_random',
        RETURN_LENGTH => $length,
        RANDOM_LENGTH => $length,
    });
    ## DO NOT debug print $random here as it will possibly be used as a password!
    return $random;
};

__PACKAGE__->meta->make_immutable;
