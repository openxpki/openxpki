## OpenXPKI::Crypto::CRR
## (C)opyright 2005 Michael Bell
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::CRR;

use Math::BigInt;

use base qw(OpenXPKI::Crypto::Object);

sub new
{
    my $self = shift;
    my $class = ref($self) || $self;
    $self = {};
    bless $self, $class;

    my $keys = { @_ };
    $self->{DEBUG} = 1 if ($keys->{DEBUG});
    $self->{DATA}  = $keys->{DATA};

    if (not $self->{DATA})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_CRR_NEW_MISSING_DATA");
    }

    $self->__init();

    return $self;
}

sub __init
{
    my $self = shift;
    $self->debug ("entering function");

    ##########################
    ##     init objects     ##
    ##########################

    $self->{header} = OpenXPKI::Crypto::Header->new (DEBUG => $self->{DEBUG},
                                                     DATA  => $self->{DATA});

    ##########################
    ##     core parsing     ##
    ##########################

    $self->{PARSED}->{HEADER} = $self->{header}->get_parsed();

    return 1;
}

sub get_serial
{
    my $self = shift;
    return $self->get_parsed ("HEADER", "SERIAL");
}

1;
__END__

=head1 Description

This class is used for the handling of certifcate revocation requests (CRR).
All functions of OpenXPKI::Crypto::Object are supported. All functions
which differ from the base class OpenXPKI::Crypto::Object are
described below.

=head1 Functions

=head2 new

The constructor supports three options - DEBUG and DATA.
DEBUG is optional and must be a true or false value. Default is false. 
The parameter DATA must contain an OpenXPKI::Crypto::Header. This is
the base of the object because a CRR includes no cryptographic standard body.

=head2 get_serial

returns the serial which is stored in the header because CRRs get their
serial directly from the database and do not store it in a cryptographic
body because a CRR has no cryptographic body.
