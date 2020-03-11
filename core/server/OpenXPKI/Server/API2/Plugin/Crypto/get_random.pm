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

Generates and returns Base64 encoded (pseudo-)random bytes by calling the
system token I<create_random> method (equal to `openssl rand` when using
the default modules).

B<Parameters>

=over

=item * C<length> I<Int> - length in bytes.

Please note that the returned string is Base64 encoded an thus longer.

=item * C<binary> I<Bool>

If set the raw binary value is returned

=item * C<fast> I<Bool>

Pass I<NOENGINE> to ignore the ENGINE usage settings of the crypto backend.
This will make calls faster but reduces the entropy to the internal openssl
mechanisms. This flag has no effect if engine_usage does not include the
I<RANDOM> flag.

=back

=cut

command "get_random" => {
    length => { isa => 'Int', required => 1, },
    binary => { isa => 'Bool', default => 0, },
    fast => { isa => 'Bool', default => 0, },
} => sub {
    my ($self, $params) = @_;
    my $length  = $params->length;
    ##! 4: 'length: ' . $length

    my $random = $self->api->get_default_token->command({
        COMMAND => 'create_random',
        RANDOM_LENGTH => $length,
        BINARY => $params->binary,
        NOENGINE => $params->fast,
    });
    ## DO NOT debug print $random here as it will possibly be used as a password!
    return $random;
};

__PACKAGE__->meta->make_immutable;
