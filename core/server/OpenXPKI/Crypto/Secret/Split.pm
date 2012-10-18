## OpenXPKI::Crypto::Secret::Split.pm 
##
## Written 2006 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project

package OpenXPKI::Crypto::Secret::Split;

use strict;
use warnings;
use utf8;
use English;

use Class::Std;
use Math::BigInt;
use Digest::SHA1 qw( sha1_hex );
use MIME::Base64;

use base qw( OpenXPKI::Crypto::Secret );

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Server::Context qw( CTX );

{
    my $DEFAULT_SECRET_BITLENGTH = 128;
    my %n_of               :ATTR; # the n
    my %k_of               :ATTR; # and k parameters for the algorithm
    my %received_shares_of :ATTR; # an array of shares acquired using 
                                  # set_secret
    my %prime_of           :ATTR; # the prime used for Z/Zp
    my %coefficient_of     :ATTR; # an array of coefficients
    my %token_of           :ATTR; # a token for random numbers + prime test

    sub BUILD {
	my ($self, $ident, $arg_ref) = @_;
	if (defined $arg_ref && defined $arg_ref->{QUORUM}) {
            if (defined $arg_ref->{QUORUM}->{N} && defined $arg_ref->{QUORUM}->{K}) {
                $n_of{$ident} = $arg_ref->{QUORUM}->{N};
                $k_of{$ident} = $arg_ref->{QUORUM}->{K};
            }
            else {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_CRYPTO_SECRET_SPIT_N_OR_K_MISSING',
                );
            }
	}
        else {
            OpenXPKI::Exception->throw(
                message => "I18N_OPENXPKI_CRYPTO_SECRET_SPLIT_QUORUM_MISSING",
            );
        }
        if (defined $arg_ref && defined $arg_ref->{TOKEN}) {
            $token_of{$ident} = $arg_ref->{TOKEN};
        }
        else {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_CRYPTO_SECRET_SPLIT_TOKEN_MISSING',
            );
        }
    }

    sub compute {
        my $self    = shift;
        my $ident   = ident $self;
        my $arg_ref = shift;
        my $bitlength = $DEFAULT_SECRET_BITLENGTH;

        if (defined $arg_ref->{BITLENGTH}) {
            $bitlength = $arg_ref->{BITLENGTH};
        }
        my $secret = $self->__get_random_number({
                BIT_LENGTH     => $bitlength,
                HIGHEST_BIT_ONE => 1,
        });
        $coefficient_of{$ident}[0] = $secret;

        my $secret_bitlength = length($secret->as_bin()) - 3;

        # round up to next nibble
        my $next_nibble_bitlength = $secret_bitlength;
        if (! $next_nibble_bitlength % 4 == 0) {
            $next_nibble_bitlength += (4 - $next_nibble_bitlength % 4);
        }

        my $prime_bitlength = $next_nibble_bitlength + 1;
        $prime_of{$ident} = $self->__get_smallest_prime_of_bitlength({
            BIT_LENGTH => $prime_bitlength,
        });

        # compute random coefficients
        for (my $i = 1; $i < $k_of{$ident}; $i++) {
            $coefficient_of{$ident}[$i] = $self->__get_random_number({
                BIT_LENGTH => $bitlength,
            });
        }

        my @shares; # array of strings of shares in the specified format
        for (my $i = 1; $i < $n_of{$ident} + 1; $i++) {
            $shares[$i-1] = $self->__construct_share({
                X               => $i,
                PRIME_BITLENGTH => $prime_bitlength,
            });
        }
        return @shares;
    }

    sub set_secret {
	my $self    = shift;
	my $ident   = ident $self;
	my $share   = shift;

        if ($share eq '') {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_CRYPTO_SECRET_SPLIT_EMPTY_SHARE',
            )
        }
        if (! defined $received_shares_of{$ident}) {
            ${$received_shares_of{$ident}}[0] = $share;
            # reconstruct prime number used
            my $deconstructed_share = $self->__deconstruct_share($share);
            $prime_of{$ident} = $self->__get_smallest_prime_of_bitlength({
                BIT_LENGTH => $deconstructed_share->{BITLENGTH_PRIME},
            });
        }
        else {
            ${$received_shares_of{$ident}}
                [scalar @{$received_shares_of{$ident}}]
                = $share;
        }
	return 1;
    }

    sub is_complete {
	my $self = shift;
	my $ident = ident $self;
	my $arg = shift;

	if (defined $received_shares_of{$ident} && ($k_of{$ident} <= scalar @{$received_shares_of{$ident}})) {
            return 1;
        }
        else {
            return 0;
        }
    }

    sub get_secret {
	my $self  = shift;
	my $ident = ident $self;

        if (defined $coefficient_of{$ident}) {
            # this is during the phase where the secret is created initially
            # thus we can just return a[0] in uppercase hex
	    return uc(substr($coefficient_of{$ident}[0]->as_hex(), 2));
        }
        else { # we have to reconstruct the secret
            if ($self->is_complete()) {
                my $reconstructed = $self->__reconstruct_secret({
                    SHARES => \@{$received_shares_of{$ident}},
                });
                return uc(substr($reconstructed->as_hex(), 2));
            }
            else {
                return; # not enough shares yet
            }
        }
    }


    sub __get_random_number :PRIVATE {
        my $self    = shift;
        my $ident   = ident $self;
        my $arg_ref = shift;
        my $bit_length = $arg_ref->{BIT_LENGTH};

        # get _bytes_ of random data from openssl, thus round bitlength
        # up to next number divisible by 8
        my $bit_length_next = $bit_length;
        if (!$bit_length_next % 8 == 0) {
            $bit_length_next += 8 - ($bit_length_next % 8);
        }
        my $byte_length = $bit_length_next / 8;

        my $random = $token_of{$ident}->command({
            COMMAND       => 'create_random',
            RETURN_LENGTH => $byte_length,
            RANDOM_LENGTH => $byte_length,
	    INCLUDE_PADDING => 1,
        });

        my $secret_data = decode_base64($random);
        #open my $OPENSSL, "openssl rand $byte_length|";
        #my $secret_data = <$OPENSSL>;
        #close($OPENSSL);

        my $hex_length = $byte_length * 2;
        my $secret_hex = '0x' . unpack "H$hex_length", $secret_data;
        my $secret     = Math::BigInt->new($secret_hex);

        # and with 11...1 to get back correct bitwidth
        my $bitmask = Math::BigInt->new("2");
        $bitmask->bpow(Math::BigInt->new("$bit_length"));
        $bitmask->bsub(Math::BigInt->bone());
        $secret->band($bitmask);

        if (defined $arg_ref->{HIGHEST_BIT_ONE}) {
            my $high_bit_bitmask = Math::BigInt->new("2");
            $bitmask->bpow(Math::BigInt->new($bit_length - 1));
            # bitmask is 100...000
            $secret->bxor($high_bit_bitmask);
        }
        return $secret;
    }


    sub __get_smallest_prime_of_bitlength :PRIVATE {
        my $self    = shift;
        my $ident   = ident $self;
        my $arg_ref = shift;
        my $bit_length = Math::BigInt->new("$arg_ref->{BIT_LENGTH}");
    
        my $TWO = Math::BigInt->new("2");
        my $ONE = Math::BigInt->bone();
    
        my $test_prime = $TWO->copy();
        $test_prime->bpow($bit_length);
        $test_prime->badd($ONE);
        # start with 2^bit_length + 1

        my $prime_found;
        while (! defined $prime_found) {
            my $hex_test_prime = substr($test_prime->as_hex(), 2);
            $prime_found = $token_of{$ident}->command({
                COMMAND => 'is_prime',
                PRIME   => $hex_test_prime,
            });

            if (! defined $prime_found) {
                $test_prime->badd($TWO); # next, please
            }
        }
        return $test_prime;
    }


    sub __construct_share :PRIVATE {
        # for a format description please see the POD documentation
        my $SHARE_FORMAT_VERSION = "0"; # the version as a nibble in hex
        my $self    = shift;
        my $ident   = ident $self;
        my $arg_ref = shift;
        my $prime_bits = $arg_ref->{PRIME_BITLENGTH};

        my $prime_nibbles = ($prime_bits - 1) / 4; # in nibbles to save space
        my $x               = uc(sprintf("%02x", $arg_ref->{X}));
        my $prime_bitlength = uc(sprintf("%02x", $prime_nibbles));
        my $p_x = uc(substr(
            $self->__evaluate_polynomial($arg_ref->{X})->as_hex(),
            2
        ));
        my $checksum = uc(substr(sha1_hex($p_x), 0, 4));
        return $SHARE_FORMAT_VERSION . $x . $p_x . $checksum . $prime_bitlength;
    }
    

    sub __evaluate_polynomial :PRIVATE {
        my $self  = shift;
        my $ident = ident $self;
        my $x     = shift;
        my $x_bigint = Math::BigInt->new("$x");
        
        my $sum = Math::BigInt->bzero();
        if ($x == 0) { # Math::BigInt sets 0^i, i>0 = 1 ?
            return $coefficient_of{$ident}[0];
        }
        else {
            for (my $i = 0; $i < scalar(@{$coefficient_of{$ident}}); $i++) {
                my $x_pow_i = $x_bigint->copy();
                my $i_bigint = Math::BigInt->new("$i");
                $x_pow_i->bmodpow($i_bigint, $prime_of{$ident});
                # x_pow_i = x^i mod p
                my $summand = $coefficient_of{$ident}[$i]->copy();
                $summand->bmul($x_pow_i);             # summand = a[i]*x^i
                $sum->badd($summand);
                $sum->bmod($prime_of{$ident});
            }
        }
        return $sum;
    }

    sub __deconstruct_share :PRIVATE {
        my $self  = shift;
        my $ident = ident $self;
        my $share = shift;
        my $share_length = length($share);
    
        my $version = hex(substr($share, 0, 1)); # first char is version number
        if ($version != 0) {
            OpenXPKI::Exception->throw(
                message =>
                    'I18N_OPENXPKI_CRYPTO_SECRET_SPLIT_INVALID_SHARE_VERSION',
                params  => {
                    VERSION => $version,
                },
            );
        }
        my $x = hex(substr($share, 1, 2)); # next two characters are x
        # prime bitlength is saved in nibbles and is actually one more
        my $bitlength_p = 4 * hex(substr($share, -2, 2)) + 1;
        my $p_x_string = substr($share, 3, $share_length - 9);
        my $correct_checksum = uc(substr(sha1_hex($p_x_string), 0, 4));
        my $entered_checksum = uc(substr($share, $share_length - 6, 4));
    
        if ($correct_checksum ne $entered_checksum) {
            OpenXPKI::Exception->throw(
                message =>
                    'I18N_OPENXPKI_CRYPTO_SECRET_SPLIT_WRONG_CHECKSUM',
                params => {
                    RECEIVED_CHECKSUM => $entered_checksum,
                    COMPUTED_CHECKSUM => $correct_checksum,
                },
            );
        }
        my $p_x = Math::BigInt->new("0x" . $p_x_string);
    
        my $result_ref = {
            X               => $x,
            BITLENGTH_PRIME => $bitlength_p,
            P_X             => $p_x,
        };
        return $result_ref;
    } 
    
    sub __reconstruct_secret :PRIVATE {
        my $self    = shift;
        my $ident   = ident $self;
        my $arg_ref = shift; 
        
        my @shares = @{$arg_ref->{SHARES}};
        my $deconstructed_share = $self->__deconstruct_share($shares[0]);
        my $prime = $self->__get_smallest_prime_of_bitlength({
            BIT_LENGTH => $deconstructed_share->{BITLENGTH_PRIME},
        });
        
        my %points;
        foreach my $share (@shares) {
            my $decon_share = $self->__deconstruct_share($share);
            my $x = $decon_share->{X};
            my $y = $decon_share->{P_X};
            $points{$x} = $y;
        }
        # %points is a hash of points (Math::BigInt objects) to interpolate
        # with in P[Z/Zp].
    
        my $secret = Math::BigInt->bzero();
        foreach my $x_j (keys %points) { # do Lagrange interpolation at 0
            my $y_j = $points{$x_j};
            my $summand = $y_j->copy();
            $summand->bmul($self->__l({
               X_J    => $x_j,
               POINTS => \%points,
               PRIME  => $prime,
            })); # $summand = y_j * l_j(0)
            $summand->bmod($prime);
            $secret->badd($summand);
            $secret->bmod($prime);
        }
        return $secret;
    }
    
    sub __l :PRIVATE { # this is l_j(0), i.e.
                       # \prod_{x_j \neq x_i} \frac{-x_i}{x_j - x_i}
                       # for more information compare Wikipedia:
                       # http://en.wikipedia.org/wiki/Lagrange_form
        my $self    = shift;
        my $ident   = ident $self;
        my $arg_ref = shift;
    
        my $x_j    = $arg_ref->{X_J};
        my %points = %{$arg_ref->{POINTS}};
        my $prime  = $arg_ref->{PRIME};
    
        my $MINUS_ONE = Math::BigInt->new("-1");
    
        my $product = Math::BigInt->bone();
        foreach my $point (keys %points) {
            my $x_i         = Math::BigInt->new("$point");
            my $denominator = Math::BigInt->new("$x_j");
            $denominator->bsub($x_i);          # $denominator = x_j - x_i
            my $numerator   = $x_i->copy();
            $numerator->bmul($MINUS_ONE);      # $numerator   = -x_i
            if (! $denominator->is_zero()) {   # multiply
                $denominator->bmodinv($prime); # $denominator = (x_j - x_i)^-1
                $numerator->bmul($denominator);
                $product->bmul($numerator);
                $product->bmod($prime);
            }
        }
        return $product;
    }

    sub get_serialized
    {
        my $self  = shift;
        my $ident = ident $self;
        my %result = ();
        my $obj = OpenXPKI::Serialization::Simple->new();
        return CTX('volatile_vault')->encrypt($obj->serialize($received_shares_of{$ident}));
    }

    sub set_serialized
    {
        my $self  = shift;
        my $ident = ident $self;
        my $dump  = shift;
        return if (not CTX('volatile_vault')->can_decrypt($dump));
        my $obj = OpenXPKI::Serialization::Simple->new();
        my $array = $obj->deserialize(CTX('volatile_vault')->decrypt($dump));
        foreach my $item (@{$array})
        {
            # only add the secret part if it was not yet present
            if (! grep { $_ eq $item } @{ $received_shares_of{$ident} }) {
                $self->set_secret($item);
            }
        }
        return 1;
    }
}

1;

=head1 Name

OpenXPKI::Crypto::Secret::Split - Secret splitting

=head1 Description

This class implements a secret splitting algorithm that allows to specify
a K out of N quorum that must be presented in order to obtain the secret.
It uses Shamir's secret splitting algorithm, for more information see
http://www.cs.tau.ac.il/~bchor/Shamir.html or
http://en.wikipedia.org/wiki/Secret_sharing#Shamir.27s_scheme

Usage example: secret splitting

  my $secret = OpenXPKI::Crypto::Secret->new(
      {
          TYPE => 'Split',
          QUORUM => {
              K => 3,
              N => 5,
          },
      });   # 'Split' pin, requiring 3 out of 5 secrets

  # determine the 5 shares with the default bitlength
  my @components = $secret->compute()

  # ... and later...

  $secret->is_complete();              # returns undef
  my $result = $secret->get_secret();  # undef

  $secret->set_secret($components[2]);
  $secret->set_secret($components[4]);

  $secret->is_complete();              # returns undef
  $result = $secret->get_secret();     # still undef

  $secret->set_secret($components[1]);

  $secret->is_complete();              # returns true
  $result = $secret->get_secret();     # returns the secret



=head2 Methods

=head3 new

Constructor. If a hash reference is given the following named parameters
are accepted:

=over

=item * TYPE

Must be 'Split'

=item * QUORUM

Hash reference, containing elements K and N. N is the total number of
secret shares, whereas K denotes the number of shares required to
reveal the secret.

=back

=head3 compute

If a hash reference is given with the named parameter BITLENGTH given, the
parameter is used as the bitlength of the secret. If no parameter is given,
the default bitlength of 128 is used. Note that the maximum bitlength is
1024, as it is saved in the secret shares.

Returns an array containing N secret shares of which K must be fed to
set_secret in order to reveal the (randomly generated) secret.

The secret shares are uppercase hexadecimal strings of the following format:

A First nibble (= first character): version number of the format,
                                    currently fixed to 0.
B Next byte (next two characters) : x-coordinate of the point used
                                    for interpolation
B Next variable length of bytes   : y-coordinate of the point used
                                    for interpolation
C Next two bytes                  : the two highest bytes of the SHA1-hash
                                    on the string representing the y-coordinates
D Next two bytes                  : bitlength of the prime number in nibbles

Actually, the algorithm always uses the smallest prime number of bitlength
4*D + 1. This is useful as so, little space is wasted for saving the prime
number. Note that the prime number is not a security parameter, so it may be
known publicly.

The part of the SHA-1 hash (C) is used as a checksum to safeguard against typos.

=head3 is_complete

Returns true once enough secret shares are available to compute the secret.

=head3 get_secret

Returns the complete secret or undef if not yet available.

=head3 set_secret

Sets (part of) the secret. Accepts a secret share string generated by
compute().
