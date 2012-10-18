## OpenXPKI::Crypto::Backend::OpenSSL::XS
## Written 2005 by Michael Bell for the OpenXPKI project
## Rewritten 2006 by Julia Dubenskaya for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project
	
use strict;
use warnings;
use utf8; ## pack/unpack is too slow

package OpenXPKI::Crypto::Backend::OpenSSL::XS;

use OpenXPKI::Server::Context qw( CTX );

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use English;

use File::Spec;
use DateTime;
use DateTime::Format::DateParse;

sub new
{
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};
    bless $self, $class;

    return $self;
}

sub set_config
{
    my $self   = shift;
    my $config = shift;
    OpenXPKI::Crypto::Backend::OpenSSL::set_config ($config);
    return 1;
}

sub get_object
{
    my $self = shift;
    my $keys = shift;

    my $format = ($keys->{FORMAT} or "PEM");
    my $data   = $keys->{DATA};
    my $type   = $keys->{TYPE};

    if ($format)
    {
        ##! 2: "format: $format"
    }
    ##! 2: "data:   $data"
    ##! 2: "type:   $type"

    my $object = undef;
    if ($type eq "X509")
    {
        ##! 16: 'X509'
        if ($format eq "DER")
        {
            ##! 16: 'DER'
            $object = OpenXPKI::Crypto::Backend::OpenSSL::X509::_new_from_der ($data);
        } else {
            ##! 16: 'PEM'
            $object = OpenXPKI::Crypto::Backend::OpenSSL::X509::_new_from_pem ($data);
        }
    } elsif ($type eq "CSR")
    {
        ##! 16: 'CSR'
        if ($format eq "DER")
        {
            ##! 16: 'DER'
            $object = OpenXPKI::Crypto::Backend::OpenSSL::PKCS10::_new_from_der ($data);
        }
        elsif ($format eq "SPKAC")
        {
            ##! 16: 'SPKAC'
            #$data =~ s/.*SPKAC\s*=\s*([^\s\n]*).*/$1/s;
            ###! 8: "spkac is ".$data
            ###! 8: "length of spkac is ".length($data)
            ###! 8: "data is ".$data
            $object = OpenXPKI::Crypto::Backend::OpenSSL::SPKAC::_new ($data);
        } else {
            ##! 16: 'PEM'
            $object = OpenXPKI::Crypto::Backend::OpenSSL::PKCS10::_new_from_pem ($data);
        }
    } elsif ($type eq "CRL")
    {
        if ($format eq "DER")
        {
            $object = OpenXPKI::Crypto::Backend::OpenSSL::CRL::_new_from_der ($data);
        } else {
            $object = OpenXPKI::Crypto::Backend::OpenSSL::CRL::_new_from_pem ($data);
        }
    } else {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_GET_OBJECT_UNKNOWN_TYPE",
            params  => {"TYPE" => $type});
    }
    if (not $object)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_OPENSSL_GET_OBJECT_NO_REF");
    }

    ##! 2: "returning object"
    return $object;
}

sub get_object_function
{
    my $self   = shift;
    my $keys   = shift;
    my $object = $keys->{OBJECT};
    my $func   = $keys->{FUNCTION};
    ##! 2: "object:   $object"
    ##! 2: "function: $func"

    if ($func eq "free")
    {
        return $self->free_object ($object);
    }

    my $result = $object->$func();
    ##! 128: 'result: ' . $result
    ##without pack/unpack the conversion does not work
    ##utf8::upgrade($result) if (defined $result);
    if (defined $result)
    {
        ## if the XS code returns NULL
        ## then it makes not sense to convert it to UTF8
        $result = pack "U0C*", unpack "C*", $result;
    }

    ## fix proprietary "DirName:" of OpenSSL
    if (defined $result and $func eq "extensions")
    {
        my @lines = split /\n/, $result;
        $result = "";
        foreach my $line (@lines)
        {
            if ($line !~ /^\s*DirName:/)
            {
                $result .= $line."\n";
            } else {
                my ($name, $value) = ($line, $line);
                $name  =~ s/^(\s*DirName:).*$/$1/;
                $value =~ s/^\s*DirName:(.*)$/$1/;
                my $dn = OpenXPKI::DN::convert_openssl_dn ($value);
                $result .= $name.$dn."\n";
            }
        }
    }

    ## parse dates
    if (defined $result && (($func eq "notbefore") || ($func eq "notafter"))) {
        ##! 16: 'result: ' . $result
        my $dt_object = DateTime::Format::DateParse->parse_datetime($result, 'UTC');
        if (! defined $dt_object || ref $dt_object ne 'DateTime') {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_OPENSSL_GET_OBJECT_FUNCTION_DATE_PARSING_ERROR",
                params  => {
                    DATE => $result,
                },
            );
        }
        $result = $dt_object;
    }
    
    return $result;
}

sub free_object
{
    my $self   = shift;
    my $object = shift;
    $object->free();
    return 1;
}

sub DESTROY
{
    my $self = shift;
    return;
}

1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::OpenSSL::XS

=head1 Description

This is the basic XS class to provide OpenXPKI with an OpenSSL based
library.

=head1 Functions

=head2 new

is the constructor. It requires no parameters.

=head2 set_config

sets the file name of the OpenSSL configuration. This is necessary
if you want to use a special engine for the parsing of the crypto
objects.

=head2 get_object

is used to get access to a cryptographic object. The following objects
are supported today:

=over

=item * SPKAC

=item * PKCS10

=item * X509

=item * CRL

=back

You must specify the type of the object in the parameter TYPE. Additionally
you must specify the format if several different formats are supported. If
you do not do this then PEM is assumed. The most important parameter is
DATA which contains the plain object data which must be parsed.

The returned value can be a scalar or a reference. You must not use this value
directly. You have to use the functions get_object_function or free_object
to access the object.

=head2 get_object_function

is used to execute functions on the object. The function expects two
parameters the OBJECT and the FUNCTION which should be called. All
functions have no parameters. The result of the function will be
returned.

When parsing an X.509 certificate the NotBefore and NotAfter dates are
returned as hash references containing the following keys:
  raw         => date as returned by the OpenSSL parser
  epoch       => seconds since the epoch
  object      => blessed DateTime object with TimeZone set to UTC
  iso8601     => string containing the ISO8601 formatted date (UTC)
  openssltime => string containing an OpenSSL compatible date string (UTC)

=head2 free_object

frees the object internally. The only parameter is the object which
was returned by get_object.
