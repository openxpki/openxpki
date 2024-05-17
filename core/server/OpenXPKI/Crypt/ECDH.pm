package OpenXPKI::Crypt::ECDH;

use Moose;

use Data::Dumper;
use English;
use Crypt::PK::ECC;
use Digest::SHA qw( sha1_hex );
use MIME::Base64;

=head1 Name

OpenXPKI::Crypt::ECDH

=head1 Description

Helper class to generate a shared secret using ECDH key exchange.

You must pass the public key of the other side at constuction time,
instead of setting the I<pub_key> attribute you can pass s single
scalar argument to the constructor holding the key as string.

In case you do not provide a private key, a new key will be generated
when you access the secret the first time.

=head1 Attributes

=head2 pub_key

An instance of C<Crypt::PK::ECC> representing the public key of the
other side. Mandatory at construction time.

=cut

has pub_key => (
    is => 'ro',
    required => 1,
    isa => 'Crypt::PK::ECC',
);

=head2 key

An instance of C<Crypt::PK::ECC> holding the private key of our side
matching the public key that was / will be send to the other side.

Can only be set at construction time, will be auto-generated if not set.

=cut

has key => (
    is => 'ro',
    required => 0,
    isa => 'Crypt::PK::ECC',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $pk = Crypt::PK::ECC->new();
        return $pk->generate_key($self->pub_key()->curve2hash());
    }
);

=head2 secret

The shared secret generated from the two keys in binary form.

=cut

has secret => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->key()->shared_secret($self->pub_key());
    }
);

around BUILDARGS => sub {

    my $orig  = shift;
    my $class = shift;

    # Take a public key as pem block
    my @data = @_;
    if (scalar(@data) == 1) {
        my $key = shift;
        @data = ( pub_key => Crypt::PK::ECC->new(\$key) );
    }
    return $class->$orig( @data );

};

__PACKAGE__->meta->make_immutable;

__END__;
