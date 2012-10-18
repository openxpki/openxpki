## OpenXPKI::Crypto::Secret::Plain.pm 
##
## Written 2006 by Martin Bartosch for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project

package OpenXPKI::Crypto::Secret::Plain;

use strict;
use warnings;
use utf8;
use English;

use Class::Std;

use base qw( OpenXPKI::Crypto::Secret );

use Regexp::Common;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Server::Context qw( CTX );

{
    my %totalparts  : ATTR( :default(1) );
    my %parts       : ATTR();

    sub BUILD {
        my ($self, $ident, $arg_ref) = @_;

        if (defined $arg_ref && defined $arg_ref->{PARTS}) {
            if ($arg_ref->{PARTS} !~ m{ \A $RE{num}{int} \z }xms
            || $arg_ref->{PARTS} < 1) {
                OpenXPKI::Exception->throw(
                    message => "I18N_OPENXPKI_CRYPTO_SECRET_PLAIN_INVALID_PARAMETER",
                    params  => 
                    {
                        PARTS => $arg_ref->{PARTS},
                    }
                );
            }
            $totalparts{$ident} = $arg_ref->{PARTS};
        }
    }

    sub set_secret {
        my $self = shift;
        my $ident = ident $self;
        my $arg = shift;
        
        if (! defined $arg) {
            OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_CRYPTO_SECRET_PLAIN_MISSING_PARAMETER",
            );
        }

        if (ref $arg eq '') {
            if ($totalparts{$ident} != 1) {
            OpenXPKI::Exception->throw(
                message => "I18N_OPENXPKI_CRYPTO_SECRET_PLAIN_INVALID_PARAMETER",
                );
            }
            $parts{$ident}->[0] = $arg;
            return 1;
        }

        if (ref $arg eq 'HASH') {
            my $part = $arg->{PART};

            if ($part !~ m{ \A $RE{num}{int} \z }xms) {
            OpenXPKI::Exception->throw(
                message => "I18N_OPENXPKI_CRYPTO_SECRET_PLAIN_INVALID_PARAMETER",
                params  => 
                {
                PART => $part,
                });
            }

            if ($part < 1 || $part > $totalparts{$ident}) {
            OpenXPKI::Exception->throw(
                message => "I18N_OPENXPKI_CRYPTO_SECRET_PLAIN_INVALID_PARAMETER",
                params  => 
                {
                PART => $part,
                });
            }
            
            if (! exists $arg->{SECRET}
            || ref $arg->{SECRET} ne '') {
            OpenXPKI::Exception->throw(
                message => "I18N_OPENXPKI_CRYPTO_SECRET_PLAIN_INVALID_PARAMETER",
                params  => 
                {
                SECRET => $arg->{SECRET},
                });
            }

            $parts{$ident}->[$part - 1] = $arg->{SECRET};

            return 1;
        }

        OpenXPKI::Exception->throw(
	        message => "I18N_OPENXPKI_CRYPTO_SECRET_PLAIN_INVALID_PARAMETER",
	    );
    }

    sub is_complete {
        ##! 1: 'start'
        my $self = shift;
        my $ident = ident $self;
        
        for (my $ii = 0; $ii < $totalparts{$ident}; $ii++) {
            ##! 16: $ii . ' defined? ' . ( defined $parts{$ident}->[$ii] ? '1' : '0' )
            return 0 unless defined $parts{$ident}->[$ii];
        }
        return 1;
    }

    sub get_secret {
        my $self = shift;
        my $ident = ident $self;

        return unless $self->is_complete();

        return join('', @{$parts{$ident}});
    }

    sub get_serialized
    {
        my $self  = shift;
        my $ident = ident $self;
        return undef if (not $parts{$ident});
        my %result = ();
        my $obj = OpenXPKI::Serialization::Simple->new();
        return CTX('volatile_vault')->encrypt($obj->serialize($parts{$ident}));
    }

    sub set_serialized
    {
        my $self  = shift;
        my $ident = ident $self;
        my $dump  = shift;
	    return if (not defined $dump or not length $dump);
        return if (not CTX('volatile_vault')->can_decrypt($dump));
        my $obj = OpenXPKI::Serialization::Simple->new();
        $parts{$ident} = $obj->deserialize(CTX('volatile_vault')->decrypt($dump));
        return 1;
    }
}

1;

=head1 Name

OpenXPKI::Crypto::Secret::Plain - Simple PIN concatenation

=head1 Description

Simple PIN container that supports "secret splitting" by dividing
the PIN in n components that are simply concatenated.


Usage example: simple one-part pin (not very useful)

  my $secret = OpenXPKI::Crypto::Secret->new();   # 'Plain' pin, one part

  $secret->is_complete()               # returns undef
  my $result = $secret->get_secret();  # undef

  $secret->set_secret('foobar');

  $secret->is_complete()               # returns true
  $result = $secret->get_secret();     # 'foobar'



Usage example: simple multi-part pin

  my $secret = OpenXPKI::Crypto::Secret->new(
      {
          TYPE => 'Plain',
          PARTS => 3,
      });   # 'Plain' pin, three part

  my $result = $secret->get_secret();  # undef

  $secret->set_secret(
      {
          PART => 1,
          SECRET => 'foo',
      });
  $secret->set_secret(
      {
          PART => 3,
          SECRET => 'baz',
      });

  $secret->is_complete();           # returns undef
  $result = $secret->get_secret();  # still undef

  $secret->set_secret(
      {
          PART => 2,
          SECRET => 'bar',
      });

  $secret->is_complete();              # returns true
  $result = $secret->get_secret();     # 'foobarbaz'



=head2 Methods

=head3 new

Constructor. If a hash reference is given the following named parameters
are accepted:

=over

=item * TYPE

Must be 'Plain'

=item * PARTS

Integer, defaults to 1. Specifies the total number of secret parts.

=back


=head3 is_complete

Returns true once all secret componentents are available.

=head3 get_secret

Returns the complete secret or undef if not yet available.

=head3 set_secret

Sets (part of) the secret.
