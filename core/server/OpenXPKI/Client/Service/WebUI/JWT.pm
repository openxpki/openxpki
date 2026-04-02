package OpenXPKI::Client::Service::WebUI::JWT;
use OpenXPKI -class;

=head1 NAME

OpenXPKI::Client::Service::WebUI::JWT - JWT encrypt/decrypt helpers

=head1 DESCRIPTION

Stateless helper class that encrypts and decrypts JWTs using a per-session key
stored under the C<jwt_encryption_key> session parameter.

=cut

# CPAN modules
use Crypt::JWT qw( encode_jwt decode_jwt );
use Crypt::PRNG;

=head2 encrypt( $session, $value )

Encrypt the given data into a JWT using the encryption key stored in the
session parameter C<jwt_encryption_key>.  The key is initialised to a random
32-byte value the first time it is needed.

=cut

sub encrypt ($class, $session, $value) {
    my $key = $session->param('jwt_encryption_key');
    if (not $key) {
        $key = Crypt::PRNG::random_bytes(32);
        $session->param('jwt_encryption_key', $key);
    }

    return encode_jwt(
        payload => $value,
        enc => 'A256CBC-HS512',
        alg => 'PBES2-HS512+A256KW', # uses "HMAC-SHA512" as the PRF and "AES256-WRAP" for the encryption scheme
        key => $key, # can be any length for PBES2-HS512+A256KW
        extra_headers => {
            p2c => 8000, # PBES2 iteration count
            p2s => 32,   # PBES2 salt length
        },
    );
}

=head2 decrypt( $session, $token )

Decrypt the given JWT using the encryption key stored in the session parameter
C<jwt_encryption_key>.  Returns C<undef> if C<$token> is false or the session
contains no decryption key.

=cut

sub decrypt ($class, $session, $token) {
    return unless $token;

    my $jwt_key = $session->param('jwt_encryption_key');
    return unless $jwt_key;

    return decode_jwt(token => $token, key => $jwt_key);
}

__PACKAGE__->meta->make_immutable;
