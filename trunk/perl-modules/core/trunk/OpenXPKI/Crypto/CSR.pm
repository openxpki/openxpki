## OpenXPKI::Crypto::CSR
## Rewritten 2005 by Michael Bell for the OpenXPKI project
## (C) Copyright 2003-2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Crypto::CSR;

use OpenXPKI::DN;
use OpenXPKI::Debug;
use Math::BigInt;
use Data::Dumper;
use English;

use base qw(OpenXPKI::Crypto::Object);

sub new
{
    my $self = shift;
    my $class = ref($self) || $self;
    $self = {};
    bless $self, $class;

    my $keys = { @_ };
    $self->{DATA}   = $keys->{DATA};
    $self->{TOKEN}  = $keys->{TOKEN};
    $self->{FORMAT} = $keys->{FORMAT};

    if (not $self->{DATA})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_CSR_NEW_MISSING_DATA");
    }
    if (not $self->{TOKEN})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_CSR_NEW_MISSING_TOKEN");
    }
    if (not $self->{TYPE})
    {
        if ($self->{DATA} =~ /^-----BEGIN/m)
        {
            $self->{TYPE} = "PKCS10";
        } else {
            $self->{TYPE} = "SPKAC";
        }
    }
    if ($self->{TYPE} ne "PKCS10" and $self->{TYPE} ne "SPKAC")
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_CSR_NEW_WRONG_TYPE",
            params  => {"TYPE" => $self->{TYPE}});
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
    $self->{PARSED}->{HEADER} = $self->{header}->get_parsed();
    if (not $self->{header}->get_body())
    {
        $self->{TYPE} = "HEADER" if ($self->{header}->get_body());
        return 1;
    }
    $self->{csr} = $self->{TOKEN}->get_object({DATA   => $self->{header}->get_body(),
                                               TYPE   => "CSR",
                                               FORMAT => $self->{TYPE}});

    ##########################
    ##     core parsing     ##
    ##########################

    my @attrlist;
    if ($self->{TYPE} eq "SPKAC")
    {
        @attrlist = ("pubkey", "keysize", "pubkey_algorithm", "exponent", "modulus",
                     "pubkey_hash", "signature_algorithm");
    } else {
        @attrlist = ("subject", "version", "signature_algorithm",
                     "pubkey", "pubkey_hash", "keysize", "pubkey_algorithm",
                     "exponent", "modulus", "extensions");
    }
    foreach my $attr (@attrlist)
    {
        ##! 16: 'OBJECT: ' . Dumper $self->{csr}
        ##! 16: 'attr: ' . $attr
        $self->{PARSED}->{BODY}->{uc($attr)} = $self->{TOKEN}->get_object_function ({
                                                   OBJECT   => $self->{csr},
                                                   FUNCTION => $attr});
        ##! 16: 'result: ' . $self->{PARSED}->{BODY}->{uc($attr)}
    }
    $self->{TOKEN}->free_object ($self->{csr});
    delete $self->{csr};
    ##! 2: "loaded CSR attributes"
    my $ret = $self->{PARSED}->{BODY};

    ###########################
    ##     parse subject     ##
    ###########################
 

    ## handle some missing data for SPKAC request
    if ( $self->{TYPE} eq "SPKAC" ) {
        ## this has probably never been tested!!! FIXME FIXME
        ## There is no subject in SPKAC, AFAIK ...
        my @reqLines = split /\n/, $self->get_body();
        #$ret->{SUBJECT} = "";
        $ret->{SUBJECT} = "CN=SPKAC";
	#for my $tmp (@reqLines)
        #{
        #    $tmp =~ s/\r$//;
        #    my ($key,$val)=($tmp =~ /([\w]+)\s*=\s*(.*)\s*/ );
        #    if ($key =~ /SPKAC/i)
        #    {
        #        $ret->{SPKAC} = $val;
        #    } else {
        #        $ret->{SUBJECT} .= ", " if ($ret->{SUBJECT});
        #        $ret->{SUBJECT} .= "$key=$val";
        #    }
        #}
        $ret->{VERSION}	= 1;
    }

    ## the subject in the header is more important
    if ($self->{PARSED}->{HEADER}->{SUBJECT}) {
        $self->{PARSED}->{SUBJECT} = $self->{PARSED}->{HEADER}->{SUBJECT};
    } else {
        $self->{PARSED}->{SUBJECT} = $ret->{SUBJECT};
    }
    ##! 2: "SUBJECT: ".$self->{PARSED}->{SUBJECT}

    ## load the differnt parts of the DN into DN_HASH
    if ($ret->{SUBJECT})
    {
        my $obj = OpenXPKI::DN->new ($ret->{SUBJECT});
        %{$ret->{SUBJECT_HASH}} = $obj->get_hashed_content();
    } else {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_CSR_INIT_MISSING_SUBJECT");
    }

    ##################################
    ##     parse emailaddresses     ##
    ##################################

    ## set emailaddress

    $self->{PARSED}->{EMAILADDRESSES} = [ $self->get_emails ($ret) ];
    $self->{PARSED}->{EMAILADDRESS} = $ret->{EMAILADDRESSES}->[0];

    if ($self->{PARSED}->{HEADER}->{SUBJECT_ALT_NAME})
    {
        ##! 4: "SUBJECT_ALT_NAME: ".$self->{PARSED}->{HEADER}->{SUBJECT_ALT_NAME}
    }
    if ($self->{PARSED}->{EMAILADDRESS})
    {
        ##! 4: "EMAILADDRESS: ".$self->{PARSED}->{EMAILADDRESS}
    }

    ###############################
    ##     extension parsing     ##
    ###############################

    return 1 if (not $ret->{EXTENSIONS});

    ## load all extensions
    $ret->{PLAIN_EXTENSIONS} = $ret->{EXTENSIONS};
    delete $ret->{EXTENSIONS};
    $ret->{OPENSSL_EXTENSIONS} = {};

    my ($val, $key);
    my @lines = split(/\n/, $ret->{PLAIN_EXTENSIONS});

    my $i = 0;
    while($i < @lines)
    {
        if ($lines[$i] =~ /^\s*([^:]+):\s*(?:critical|)\s*$/i)
        {
            $key = $1;
            $ret->{OPENSSL_EXTENSIONS}->{$key} = [];
            $i++;
            while(exists $lines[$i] and $lines[$i] !~ /^\s*[^:]+:\s*(?:critical|)\s*$/ && $i < @lines)
            {
                $val = $lines[$i];
                $val =~ s/^\s+//;
                $val =~ s/\s+$//;
                $i++;
                next if $val =~ /^$/;
		if ($key eq 'X509v3 Subject Alternative Name') {
		    # when OpenSSL encounters CSR IP Subject Alternative Names
		    # the parsed output contains "IP Address:d.d.d.d", however
		    # OpenSSL expects "IP:d.d.d.d" in a config file for
		    # certificate issuance if you intend to issue a certificate
		    # we hereby declare that "IP" is the canonical identifier
		    # for an IP Subject Alternative Name
		    $val =~ s{ \A IP\ Address: }{IP:}xms;
		}
                push(@{$ret->{OPENSSL_EXTENSIONS}->{$key}}, $val);
            }
        } else {
            ## FIXME: can this every happen?
            $i++;
        }
    }

    ##! 2: "show all extensions and their values"
    while(($key, $val) = each(%{$ret->{OPENSSL_EXTENSIONS}}))
    {
        ##! 4: "found extension: $key"
        foreach(@{$val})
        {
            ##! 8: "with value(s): $_"
        }
    }

    return 1;
}

sub get_serial
{
    my $self = shift;
    return $self->{PARSED}->{HEADER}->{SERIAL};
}

sub get_emails
{
    my $self = shift;
    my $parsed = $self->{PARSED};
    $parsed = shift if ($_[0]);

    my @emails = ();

    ## extract emails from subject alt name

    if ( $parsed->{HEADER}->{SUBJECT_ALT_NAME} ) {
        my @subjectAltNames = split (/,\s*/, $parsed->{HEADER}->{SUBJECT_ALT_NAME});
        foreach my $h (@subjectAltNames) {
            next if ($h !~ /^\s*email(|\.[0-9]+)[:=]/is);
            $h =~ s/^\s*email(|\.[0-9]+)[:=]//i;
            push (@emails, $h);
        }
    }

    ## extract emails from subject

    ## pkcs#9 emailAddress
    if (exists $parsed->{SUBJECT_HASH}->{EMAILADDRESS})
    {
        foreach my $mail (@{$parsed->{SUBJECT_HASH}->{EMAILADDRESS}})
        {
            push @emails, $mail;
        }
    }
    ## rfc822Mailbox
    if (exists $parsed->{SUBJECT_HASH}->{MAIL})
    {
        foreach my $mail (@{$parsed->{SUBJECT_HASH}->{MAIL}})
        {
            push @emails, $mail;
        }
    }

    return @emails;
}

sub get_converted
{
    my $self   = shift;
    my $format = shift;

    if ($self->{TYPE} eq "SPKAC")
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_CSR_GET_CONVERTED_SPKAC_DETECTED");
    }
    if (not $format)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_CSR_GET_CONVERTED_MISSING_FORMAT");
    }
    if ($format ne "PEM" and $format ne "DER" and $format ne "TXT")
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_CSR_GET_CONVERTED_WRONG_FORMAT",
            params  => {"FORMAT" => $format});
    }

    if ($format eq 'PEM' ) {
        return $self->get_body();
    }
    else
    {
        return $self->{TOKEN}->command ({COMMAND => "convert_pkcs10",
                                         DATA    => $self->get_body(),
                                         OUT     => $format});
    }
}

sub get_info_hash
{
    ##! 1: "start"
    my $self = shift;

    ##! 2: "create dump for deep copy"
    my $help = Dumper($self->{PARSED});
    ##! 2: "fix dump"
    $help =~ s/^\s*\$VAR1\s*=//s;
    ##! 2: "create deep copy"
    $help = eval ($help);
    if ($EVAL_ERROR)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_CSR_GET_INFO_HASH_EVAL_OF_DUMP_FAILED",
            params  => {"MESSAGE" => $EVAL_ERROR});
    }

    ##! 1: "finished"
    return $help;
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::CSR

=head1 Description

This is the module for managing CSRs. You can use this module to parse
and convert CSRs. If you are missing some functions here please check
OpenXPKI::Crypto::Object. OpenXPKI::Crypto::Object inherits from
OpenXPKI::Crypto::Object several functions.

=head1 Functions

=head2 new

The constructor supports three options - DATA, FORMAT and TOKEN.
FORMAT is optional but can be specified. It can be set to PKCS10 or
SPKAC. If the FORMAT is missing then the module tries to determine the
type of the request from DATA with some REGEX. DATA is a the CSR.
Please note that even PKCS#10 requests are only supported in PEM format.
TOKEN is a token from the token manager (OpenXPKI::TokenManager).
The token is needed to parse the requests.

=head2 get_serial

returns the serial of the CSR. The serial will be extracted from the
header.

=head2 get_converted

The functions supports three formats - PEM, DER and TXT. All other
formats create errors (or better exceptions). The CSR will be
returned in the specified format on success. This functionality
is only supported for PKCS#10 requests. If you try this with a SPKAC
request then an exception will occur.

=head2 get_emails

returns an array with all available email addresses. Pleae note that
this include PKCS#9 emailAddress, rfc822Mailbox and the subject
alternative name email extensions.

=head2 get_info_hash

returns a hash reference with all parsed informations. Please note that
this function makes a deep copy of the parsed information to protect
the object. This costs time. So please only do this if you really need
it.
