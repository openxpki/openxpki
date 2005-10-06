## OpenXPKI::Crypto::CRL
## (C)opyright 2003-2005 Michael Bell
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::CRL;

use Date::Parse;

use OpenXPKI::Crypto::Object;
use vars qw(@ISA);
@ISA = qw(OpenXPKI::Crypto::Object);

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
    $self->{TOKEN} = $keys->{TOKEN};

    if (not $self->{DATA})
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_CRL_NEW_MISSING_DATA");
        return undef;
    }
    if (not $self->{TOKEN})
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_CRL_NEW_MISSING_TOKEN");
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
    $self->{crl} = $self->{TOKEN}->get_object(DATA => $self->{header}->get_body(),
                                              TYPE => "CRL");
    if (not $self->{crl})
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_CRL_INIT_OBJECT_FAILED",
                          "__ERRVAL__", $self->{TOKEN}->errval());
        return undef;
    }

    ##########################
    ##     core parsing     ##
    ##########################

    $self->{PARSED}->{HEADER} = $self->{header}->get_parsed();
    foreach my $attr ("version", "issuer", "next_update", "last_update",
                      "signature_algorithm", "revoked", "serial")
    {
        $self->{PARSED}->{BODY}->{uc($attr)} = $self->{crl}->$attr();
    }
    $self->{crl}->free();
    delete $self->{crl};
    $self->debug ("loaded crl attributes");
    my $ret = $self->{PARSED}->{BODY};

    #################################
    ##     parse revoked certs     ##
    #################################

    if ($ret->{REVOKED})
    {
        ## parse revoked certificates
        my @list = ();
        my @certs = split ( /\n/i, $ret->{REVOKED} );
        for (my $i=0; $i<scalar @certs; $i++)
        {
            my $serial = $certs[$i++];
            my $date   = $certs[$i];
            my $ext    = "";
            while ($i+1<scalar @certs && $certs[$i+1] =~ /^  /) {
                $ext .= $certs[++$i]."\n";
            }
            my $entry = {SERIAL     => $serial,
                         DATE       => $date,
                         EXTENSIONS => $ext}; 
            @list = ( @list, $entry );
        }
        $self->{PARSED}->{LIST} = @list;
    }

    return 1;
}

sub get_serial {
    my $self = shift;

    # return the serial if one is present
    return $self->get_parsed("BODY", "SERIAL")
        if ($self->get_parsed("BODY", "SERIAL") != -1);

    # new numbering by timestamp
    return str2time($self->get_parsed("BODY", "LAST_UPDATE"));

}

sub get_converted
{
    my $self   = shift;
    my $format = shift;

    if (not $format)
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_CRL_GET_CONVERTED_MISSING_FORMAT");
        return undef;
    }
    if ($format ne "PEM" and $format ne "DER" and $format ne "TXT")
    {
        $self->set_error ("I18N_OPENXPKI_CRYPTO_CRL_GET_CONVERTED_WRONG_FORMAT",
                          "__FORMAT__", $format);
        return undef;
    }

    if ($format eq 'PEM' ) {
        return $self->get_body();
    }
    else
    {
        my $result = $self->{TOKEN}->command ("convert_crl",
                                              DATA => $self->get_body(),
                                              OUT  => $format);
        if (not defined $result)
        {
            $self->set_error ("I18N_OPENXPKI_CRYPTO_CRL_GET_CONVERTED_CONVERSION_FAILED",
                              "__ERRVAL__", $self->{TOKEN}->errval());
            return undef;
        }
        return $result;
    }
}

1;
