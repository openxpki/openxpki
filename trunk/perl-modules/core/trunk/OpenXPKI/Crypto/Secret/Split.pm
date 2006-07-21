## OpenXPKI::Crypto::Secret::Split.pm 
##
## Written 2006 by Martin Bartosch for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project
## $Revision: 269 $

package OpenXPKI::Crypto::Secret::Split;

use strict;
use warnings;
use utf8;
use English;

use Class::Std;

use base qw( OpenXPKI::Crypto::Secret );

use Regexp::Common;

use OpenXPKI::Debug 'OpenXPKI::Crypto::Secret::Split';
use OpenXPKI::Exception;

{
    sub BUILD {
	my ($self, $ident, $arg_ref) = @_;

	OpenXPKI::Exception->throw(
	    message => "I18N_OPENXPKI_CRYPTO_SECRET_SPLIT_NOT_YET_IMPLEMENTED",
	    );
    }

    sub set_secret {
	my $self = shift;
	my $ident = ident $self;
	my $arg = shift;

	return;
    }

    sub is_complete {
	my $self = shift;
	my $ident = ident $self;
	my $arg = shift;

	return;
    }

    sub get_secret {
	my $self = shift;
	my $ident = ident $self;
	my $arg = shift;

	return;
    }
}

1;

=head1 Name

OpenXPKI::Crypto::Secret::Split - Secret splitting

=head1 Description

This class implements a secret splitting algorithm that allows to specify
a K out of N quorum that must be presented in order to obtain the secret.


Usage example: secret splitting

  my $secret = OpenXPKI::Crypto::Secret->new(
      {
          TYPE => 'Split',
          QUORUM => {
              K => 3,
              N => 5,
          },
      });   # 'Split' pin, requiring 3 out of 5 secrets

  # determine the 5 shares from the plain text
  my @components = $secret->compute('foobarbaz');

  # ... and later...

  $secret->is_complete();              # returns undef
  my $result = $secret->get_secret();  # undef

  $secret->set_secret($components[2]);
  $secret->set_secret($components[4]);

  $secret->is_complete();              # returns undef
  $result = $secret->get_secret();  # still undef

  $secret->set_secret($components[1]);

  $secret->is_complete();              # returns true
  $result = $secret->get_secret();     # 'foobarbaz'



=head2 Methods

=head new

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

Accepts a scalar argument and returns an array containing N secret
shares of which K must be fed to set_secret in order to reveal the
secret.

=head3 is_complete

Returns true once all secret componentents are available.

=head3 get_secret

Returns the complete secret or undef if not yet available.

=head3 set_secret

Sets (part of) the secret.
