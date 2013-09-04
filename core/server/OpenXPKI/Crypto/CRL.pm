## OpenXPKI::Crypto::CRL
## Rewritten 2005 by Michael Bell for the OpenXPKI project
## (C)opyright 2003-2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::CRL;

use OpenXPKI::Debug;
use DateTime::Format::DateParse;

use base qw(OpenXPKI::Crypto::Object);

sub new
{
    my $self = shift;
    my $class = ref($self) || $self;
    $self = {};
    bless $self, $class;

    my $keys = { @_ };
    $self->{DATA}  = $keys->{DATA};
    $self->{TOKEN} = $keys->{TOKEN};

    if (not $self->{DATA})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_CRL_NEW_MISSING_DATA");
    }
    if (not $self->{TOKEN})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_CRL_NEW_MISSING_TOKEN");
    }

    $self->__init();

    return $self;
}

sub __init
{
    my $self = shift;
    ##! 1: "start"

    ##########################
    ##     init objects     ##
    ##########################

    $self->{header} = OpenXPKI::Crypto::Header->new (DATA  => $self->{DATA});
    $self->{crl} = $self->{TOKEN}->get_object({DATA  => $self->{header}->get_body(),
                                               TYPE  => "CRL"});

    ##########################
    ##     core parsing     ##
    ##########################

    $self->{PARSED}->{HEADER} = $self->{header}->get_parsed();
    foreach my $attr ("version", "issuer", "next_update", "last_update",
                      "signature_algorithm", "revoked", "serial")
    {
        $self->{PARSED}->{BODY}->{uc($attr)} = $self->{TOKEN}->get_object_function ({
                                                   OBJECT   => $self->{crl},
                                                   FUNCTION => $attr});
    }

    $self->{PARSED}->{BODY}->{NEXT_UPDATE}
        = DateTime::Format::DateParse->parse_datetime($self->{PARSED}->{BODY}->{NEXT_UPDATE})->epoch();
    $self->{PARSED}->{BODY}->{LAST_UPDATE}
        = DateTime::Format::DateParse->parse_datetime($self->{PARSED}->{BODY}->{LAST_UPDATE})->epoch();
    $self->{TOKEN}->free_object ($self->{crl});
    delete $self->{crl};
    ##! 2: "loaded crl attributes"
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
        $self->{PARSED}->{LIST} = \@list;
    }

    return 1;
}

sub get_serial {
    my $self = shift;

    # return the serial (undef if not present)
    return $self->get_parsed("BODY", "SERIAL");
}

sub get_converted
{
    my $self   = shift;
    my $format = shift;

    if (not $format)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_CRL_GET_CONVERTED_MISSING_FORMAT");
    }
    if ($format ne "PEM" and $format ne "DER" and $format ne "TXT")
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_CRL_GET_CONVERTED_WRONG_FORMAT",
            params  => {"FORMAT" => $format});
    }

    if ($format eq 'PEM' ) {
        return $self->get_body();
    }
    else
    {
        return $self->{TOKEN}->command ({COMMAND => "convert_crl",
                                         DATA    => $self->get_body(),
                                         OUT     => $format});
    }
}

sub to_db_hash {
    my $self = shift;

    my %insert_hash;
    $insert_hash{'DATA'} = $self->get_body();
    $insert_hash{'LAST_UPDATE'} = $self->get_parsed("BODY", "LAST_UPDATE");
    $insert_hash{'NEXT_UPDATE'} = $self->get_parsed("BODY", "NEXT_UPDATE");
    return %insert_hash;
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::CRL

=head1 Description

This is the module for managing CRLs. You can use this module to parse
and convert CRLs. If you are missing some functions here please check
OpenXPKI::Crypto::Object. OpenXPKI::Crypto::Object inherits from
OpenXPKI::Crypto::Object several functions.

=head1 Functions

=head2 new

The constructor supports two options - DATA and TOKEN.
DATA is a PEM encoded CRL. TOKEN is a token from the token manager
(OpenXPKI::TokenManager). The token is needed to parse the CRL.

=head2 get_serial

returns the serial of the CRL. If there is no serial in the CRL,
undef will be returned.

=head2 get_converted

The functions supports three formats - PEM, DER and TXT. All other
formats create errors (or better exceptions). The CRL will be
returned in the specified format on success.

=head2 to_db_hash

Converts the CRL into a hash that can (with a few additions) be
inserted in to a database using $dbi->insert()

