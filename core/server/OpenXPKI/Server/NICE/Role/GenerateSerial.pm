package OpenXPKI::Server::NICE::Role::GenerateSerial;
use OpenXPKI -role;

use Math::BigInt;
use OpenXPKI::Server::Context qw( CTX );

=head1 NAME

OpenXPKI::Server::NICE::Role::GenerateSerial

=head1 DESCRIPTION

Provides the L</generate_serial> method for generating a certificate serial
number. Serial configuration is read directly from the config layer
(C<profile.default>).

=head2 Methods

=head3 generate_serial()

Reads C<increasing_serials> and C<randomized_serial_bytes> from
C<profile.default> in the config layer and returns a L<Math::BigInt> serial
number.

If C<increasing_serials> is set (default: 1), the serial is based on a
monotonically increasing counter obtained from the database.  The counter
value is then left-shifted by C<rand_length * 8> bits and the random
component is OR-ed into the low-order bits, guaranteeing both global
uniqueness and unpredictability.

If C<randomized_serial_bytes> is 0, only the increasing counter value is
used without any random component.

Returns a L<Math::BigInt> containing the generated serial number.

=cut

sub generate_serial {
    my ($self) = @_;

    my $config = CTX('config');

    my $rand_length = $config->get(['profile', 'default', 'randomized_serial_bytes']) // 8;
    my $increasing  = $config->get(['profile', 'default', 'increasing_serials'])      // 1;

    my $base = 0;
    $base = CTX('dbi')->next_id('certificate')
        if ($increasing);

    my $serial = Math::BigInt->new( $base );
    if ($rand_length > 0) {
        my $rand_hex = CTX('api2')->get_random(
            length => $rand_length,
            format => 'hex',
        );
        ##! 16: 'random part: ' . $rand_hex
        # left shift the existing serial by the size of the random part and
        # add it to the right
        $serial->blsft($rand_length * 8);
        ##! 16: 'bit shifted serial: ' . $serial->as_hex
        $serial->bior(Math::BigInt->new('0x' . $rand_hex));
    }
    ##! 32: 'propagating serial number: ' . $serial->as_hex
    return $serial;
}

1;
