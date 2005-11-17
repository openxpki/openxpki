## OpenXPKI::Crypto::X509
## (C)opyright 2003-2005 Michael Bell
## $Revision$

use strict;
use warnings;

package OpenXPKI::Crypto::X509;

use OpenXPKI::DN;
use Math::BigInt;
## use Date::Parse;

use base qw(OpenXPKI::Crypto::Object);
use English;

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
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_X509_NEW_MISSING_DATA");
    }
    if (not $self->{TOKEN})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_X509_NEW_MISSING_TOKEN");
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
    eval
    {
        $self->{x509} = $self->{TOKEN}->get_object(DATA => $self->{header}->get_body(),
                                                   TYPE => "X509");
    };
    if (my $exc = OpenXPKI::Exception->caught())
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_X509_INIT_OBJECT_FAILED",
            child   => $exc);
    } elsif ($EVAL_ERROR) {
        $EVAL_ERROR->rethrow();
    }

    ##########################
    ##     core parsing     ##
    ##########################

    $self->{PARSED}->{HEADER} = $self->{header}->get_parsed();
    foreach my $attr ( "serial", "subject", "issuer", "notbefore", "notafter",
                       "alias", "modulus", "pubkey", "fingerprint", "emailaddress",
                       "version", "pubkey_algorithm", "signature_algorithm", "exponent",
                       "keysize", "extensions", "openssl_subject" )
    {
        $self->{PARSED}->{BODY}->{uc($attr)} = $self->{TOKEN}->get_object_function (
                                                   OBJECT   => $self->{x509},
                                                   FUNCTION => $attr);
    }
    $self->{TOKEN}->free_object ($self->{x509});
    delete $self->{x509};
    $self->debug ("loaded cert attributes");
    my $ret = $self->{PARSED}->{BODY};

    ###########################
    ##     parse subject     ##
    ###########################

    ## load the differnt parts of the DN into SUBJECT_HASH
    my $obj = OpenXPKI::DN->new ($ret->{SUBJECT});
    %{$ret->{SUBJECT_HASH}} = $obj->get_hashed_content();

    ## FIXME: the following comment and code are wrong
    ## FIXME: the second equal sign has not to be escaped because
    ## FIXME: because it is no special character
    ## FIXME: if there is a problem with a DN parser then this
    ## FIXME: parser has a bug
    #	## OpenSSL includes a bug in -nameopt RFC2253
    #	## = signs are not escaped if they are normal values
    #	my $i = 0;
    #	my $now = "name";
    #	while ($i < length ($ret->{DN}))
    #	{
    #		if (substr ($ret->{DN}, $i, 1) =~ /\\/)
    #		{
    #			$i++;
    #		} elsif (substr ($ret->{DN}, $i, 1) =~ /=/) {
    #			if ($now =~ /value/)
    #			{
    #				## OpenSSL forgets to escape =
    #				$ret->{DN} = substr ($ret->{DN}, 0, $i)."\\".substr ($ret->{DN}, $i);
    #				$i++;
    #			} else {
    #				$now = "value";
    #			}
    #		} elsif (substr ($ret->{DN}, $i, 1) =~ /[,+]/) {
    #			$now = "name";
    #		}
    #		$i++;
    #	}

    ##################################
    ##     parse emailaddresses     ##
    ##################################

    if ($ret->{EMAILADDRESS})
    {
        if (index ($ret->{EMAILADDRESS}, "\n") < 0 )
        {
            $ret->{EMAILADDRESSES}->[0] = $ret->{EMAILADDRESS};
        } else {
            my @harray = split /\n/, $ret->{EMAILADDRESS};
            $ret->{EMAILADDRESSES} = \@harray;
            $ret->{EMAILADDRESS}   = $ret->{EMAILADDRESSES}->[0];
        }
    }
    # OpenSSL's get_email has a bug so we must add rfc822Mailbox by ourselves
    if (not $ret->{EMAILADDRESS} and
        exists $ret->{SUBJECT_HASH}->{MAIL} and
        $ret->{SUBJECT_HASH}->{MAIL}[0])
    {
        $ret->{EMAILADDRESS}   = $ret->{SUBJECT_HASH}->{MAIL}[0];
        $ret->{EMAILADDRESSES} = \@{$ret->{SUBJECT_HASH}->{MAIL}};
    }

    ###############################
    ##     extension parsing     ##
    ###############################

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
                push(@{$ret->{OPENSSL_EXTENSIONS}->{$key}}, $val);
            }
        } else {
            ## FIXME: can this ever happen?
            $i++;
        }
    }

    $self->debug ("show all extensions and their values");
    while(($key, $val) = each(%{$ret->{OPENSSL_EXTENSIONS}}))
    {
        $self->debug ("found extension: $key");
        $self->debug ("with value(s): $_") foreach(@{$val});
    }

    ## signal CA certiticate
    my $h = $ret->{OPENSSL_EXTENSIONS}->{"X509v3 Basic Constraints"}[0];
    $h ||= "";
    $h =~ s/\s//g;
    if ($h =~ /CA:TRUE/i)
    {
        $ret->{IS_CA} = 1;
        $ret->{EXTENSIONS}->{BASIC_CONSTRAINTS}->{CA} = 1;
    } else {
        $ret->{IS_CA} = 0;
        $ret->{EXTENSIONS}->{BASIC_CONSTRAINTS}->{CA} = 0;
    }

    ## add extensions for chain tracking
    foreach my $item (@{$ret->{OPENSSL_EXTENSIONS}->{"X509v3 Authority Key Identifier"}})
    {
        next if (not defined $item or not length ($item));
        my ($value) = ($item =~ /^[^:]+:(.*)$/);
        $ret->{EXTENSIONS}->{AUTHORITY_KEY_IDENTIFIER}->{CA_KEYID} = $value
            if ($item =~ /^keyid:/);
        $ret->{EXTENSIONS}->{AUTHORITY_KEY_IDENTIFIER}->{CA_ISSUER_NAME} = $value
            if ($item =~ /^DirName:/);
            
        if ($item =~ /^serial:/)
        {
            $value =~ s/://g;
            $value = "0x$value";
            $value = Math::BigInt->new ($value);
            $value = $value->bstr();
            $ret->{EXTENSIONS}->{AUTHORITY_KEY_IDENTIFIER}->{CA_ISSUER_SERIAL} = $value
        }
    }
    if ($ret->{OPENSSL_EXTENSIONS}->{"X509v3 Subject Key Identifier"}[0])
    {
        $ret->{EXTENSIONS}->{SUBJECT_KEY_IDENTIFIER} =
            $ret->{OPENSSL_EXTENSIONS}->{"X509v3 Subject Key Identifier"}[0];
        $ret->{EXTENSIONS}->{SUBJECT_KEY_IDENTIFIER} =~ s/^\s*//;
    }
    ## make them visible for the database interface
    foreach $key (keys %{$ret->{EXTENSIONS}->{AUTHORITY_KEY_IDENTIFIER}})
    {
        next if (not $key);
        $ret->{$key} = $ret->{EXTENSIONS}->{AUTHORITY_KEY_IDENTIFIER}->{$key};
    }
    $ret->{KEYID} = $ret->{EXTENSIONS}->{SUBJECT_KEY_IDENTIFIER}
        if (exists $ret->{EXTENSIONS}->{SUBJECT_KEY_IDENTIFIER});

    return 1;
}

sub get_converted
{
    my $self   = shift;
    my $format = shift;

    if (not $format)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_X509_GET_CONVERTED_MISSING_FORMAT");
    }
    if ($format ne "PEM" and $format ne "DER" and $format ne "TXT")
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_X509_GET_CONVERTED_WRONG_FORMAT",
            params  => {"FORMAT" => $format});
    }

    if ($format eq 'PEM' ) {
        return $self->get_body();
    }
    else
    {
        my $result = eval {$self->{TOKEN}->command ("convert_cert",
                                                    DATA => $self->get_body(),
                                                    OUT  => $format)};
        if (my $exc = OpenXPKI::Exception->caught())
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_X509_GET_CONVERTED_CONVERSION_FAILED",
                child   => $exc);
        } elsif ($EVAL_ERROR) {
            $EVAL_ERROR->rethrow();
        }
        return $result;
    }
}

1;
__END__

=head1 Description

This class is used for the handling of X.509v3 certificates. All
functions of OpenXPKI::Crypto::Object are supported. All functions
which differ from the base class OpenXPKI::Crypto::Object are
described below.

=head1 Functions

=head2 new

The constructor supports three options - DEBUG, TOKEN and DATA.
DEBUG is optional and must be a true or false value. Default is
false. TOKEN must be a crypto token from the token manager. This
is necessary to extract some informations from the data. The
parameter DATA must contain a PEM encoded certificate. This is
the base of the object.

=head2 get_converted

expects only one value - the requested format of the certificate.
PEM, TXT and DER are supported. TXT is a plain text representation
which can be directly displayed to the user.
