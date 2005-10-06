## OpenXPKI::Crypto::CRR
## (C)opyright 2005 Michael Bell
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::CRR;

use Math::BigInt;

use base qw(OpenXPKI::Crypto::Object);
our ($errno, $errval);

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
        $self->set_error ("I18N_OPENXPKI_CRYPTO_CRR_NEW_MISSING_DATA");
        return undef;
    }

    return undef if (not $self->__init());

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
