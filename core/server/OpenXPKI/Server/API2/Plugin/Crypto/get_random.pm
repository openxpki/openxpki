package OpenXPKI::Server::API2::Plugin::Crypto::get_random;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Crypto::get_random

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::Random;


=head1 COMMANDS

=head2 get_random

Generates and returns Base64/Hex encoded (pseudo-)random bytes which are
considered cryptographically secure unless mode=fast is set.

See OpenXPKI::Random for details.

B<Parameters>

=over

=item * C<length> I<Int> - length in bytes.

Please note that the returned string is Base64/Hex encoded an thus longer.

=item * C<format> I<Str>

The default is to return the random data with Base64 encoding (I<base64>).
Set to I<hex> for lowercase hex. Note, the binary flag is superior
to the format flag.

=item * C<binary> I<Bool>

Return the random as raw binary, overwrites any value given to format.

=item * C<mode> I<String>

One of I<fast|regular|strong>, default is regular.

=back

=cut

command "get_random" => {
    length => { isa => 'Int', required => 1, },
    binary => { isa => 'Bool', default => 0, },
    format => { isa => 'Str', matching => qr{ \A ( bin | base64 | hex ) \Z }x,, default => 'base64' },
    mode => { isa => 'Str',  matching => qr{ \A ( fast | regular | strong ) \Z }x, default => 'regular' },
} => sub {

    my ($self, $params) = @_;
    my $length  = $params->length;
    ##! 4: 'length: ' . $length

    return OpenXPKI::Random->new()->get_random(
        $length,
        $params->binary ? 'bin' : $params->format,
        $params->mode,
    );

};

__PACKAGE__->meta->make_immutable;
