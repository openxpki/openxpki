package OpenXPKI::Role::ACME;

use Moose::Role;

use Crypt::PK::RSA;
use Crypt::PK::ECC;
use Data::Dumper;

=head1 Attributes

=head2 account_id

The account id as used in the kid header

=cut

has account_id => (
    is => 'ro',
    isa => 'Str',
    predicate => 'has_account_id',
);

=head2 account_key

A Crypt::PK::RSA/ECC object representing the ACME account key.

=cut

has account_key => (
    is => 'rw',
    # Should be a Crypt::PK::x object but unions dont work
    # and they dont have a common parent class :(
    isa => 'Object',
);

=head1 Methods

=head2 get_key_thumbprint

Calculate the JWK Thumbprint (RFC 7638) from the key set in account_key.

Will die if key is not set or has an unsupported format.

=cut

sub get_key_thumbprint {

    my $self = shift;
    $self->account_key()->export_key_jwk_thumbprint();

}

=head2 get_key_hash

Return the key as JWS hash structure (RFC 7638) from the key set in account_key.

=cut

sub get_key_hash {

    my $self = shift;
    $self->account_key()->export_key_jwk('public', 1);

}

=head2 get_jwt_algorithm

Get the algorithm for the de/encode_jwt call matching the key.

=cut

sub get_jwt_algorithm {

    my $self = shift;
    my $jwk = $self->account_key()->export_key_jwk('public', 1);

    return 'ES256' if ($jwk->{crv} eq 'P-256');

    return 'RS256' if($jwk->{kty} eq 'RSA');

    return 'ES384' if ($jwk->{crv} eq 'P-384');

    return 'ES512' if ($jwk->{crv} eq 'P-521');

    die "Unsupported key algorithm ";

}

=head1 Internal Methods

=head2 _key_object_from_hash

Transform a JWS key hash into a Crypt::PK::RSA|Crypt::PK::ECC object
representing this key. Will die if the given hash does not describe
a supported key format.

=cut

sub _key_object_from_hash {

    my $self = shift;
    my $key_hash = shift;

    die "No input data for _key_object_from_hash" unless($key_hash);

    if ($key_hash->{kty} eq 'RSA') {
        return Crypt::PK::RSA->new($key_hash);
    }

    if ($key_hash->{kty} eq 'EC') {
        return Crypt::PK::ECC->new($key_hash);
    }

    $self->log->trace(Dumper $key_hash);
    die "Unsupported key format or algorithm ";

}

1;
