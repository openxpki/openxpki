## OpenXPKI::Crypto::Backend::API
## Written 2006 by Michael Bell
## (C)opyright 2006 OpenXPKI
## $Revision: 151 $
	
use strict;
use warnings;

package OpenXPKI::Crypto::Backend::API;

use OpenXPKI qw(debug);
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use English;

sub new
{
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {DEBUG => CTX('debug')};
    bless $self, $class;

    my $keys = shift;

    $self->{DEBUG}  = 1 if ($keys->{DEBUG});
    $self->{CLASS}  = $keys->{CLASS};
    $self->{PARAMS} = $keys->{PARAMS};

    eval "require ".$self->{CLASS};
    if ($@)
    {
        my $text = $@;
        $self->debug ("compilation of driver ".$self->{CLASS}." failed\n$text");
        OpenXPKI::Exception->throw (message => $text);
    }
    $self->debug ("class: ".$self->{CLASS});

    ## get the token
    eval { 
	$self->{INSTANCE} = $self->{CLASS}->new (%{$self->{PARAMS}}) 
    };
    if (my $exc = OpenXPKI::Exception->caught())
    {
        ## really stupid dummy exception handling
        $self->debug ("cannot get new instance of driver ".$self->{CLASS});
        $exc->rethrow();
    }
    $self->debug ("no exception during new()");

    return $self;
}

sub command
{
    my $self = shift;
    my $keys = shift;

    my $command = $keys->{COMMAND};

    ## 0 means the parameter is optional
    ## 1 means the parameter is required
    ## an array represent the allowed parameters
    ## "__undef" in the array means that the parameter is optional
    ## FIXME: actually we only check the correct names
    my %params = (
                  "convert_cert"    => {"DATA" => 1,
                                        "OUT"  => ["DER","TXT"]},
                  "convert_crl"     => {"DATA" => 1,
                                        "OUT"  => ["DER","TXT"]},
                  "convert_key"     => {"PASSWD"     => 1,
                                        "OUT_PASSWD" => 0,
                                        "ENC_ALG"    => ["__undef", "aes256","aes192","aes128","idea","des3","des"],
                                        "IN"         => ["RSA","DSA","PKCS8"],
                                        "OUT"        => ["PEM","DER","PKCS8"],
                                        "DATA"       => 1},
                  "convert_pkcs10"  => {"DATA" => 1,
                                        "OUT"  => ["DER","TXT"]},
                  "create_cert"     => {"PROFILE" => 1,
                                        "PASSWD"  => 0,
                                        "KEY"     => 0,
                                        "SUBJECT" => 1,
                                        "CSR"     => 1,
                                        "DAYS"    => 1},
                  "create_key"      => {"ENC_ALG"    => ["__undef", "aes256","aes192","aes128","idea","des3","des"],
                                        "PASSWD"     => 0,
                                        "TYPE"       => ["RSA","DSA","EC"],
                                        "CURVE_NAME" => 0,
                                        "KEY_LENGTH" => [512, 768, 1024, 2048, 4096]},
                  "create_pkcs10"   => {"PASSWD"  => 0,
                                        "KEY"     => 0,
                                        "SUBJECT" => 1},
                  "create_pkcs12"   => {"PKCS12_PASSWD"  => 0,
                                        "PASSWD"         => 1,
                                        "ENC_ALG"        => ["__undef", "aes256","aes192","aes128","idea","des3","des"],
                                        "KEY"            => 1,
                                        "CERT"           => 1,
                                        "CHAIN"          => 0},
                  "create_random"   => {"RETURN_LENGTH" => 0,
                                        "RANDOM_LENGTH" => 0},
                  "issue_cert"      => {"PROFILE" => 1,
                                        "CSR"     => 1},
                  "issue_crl"       => {"PROFILE" => 1,
                                        "REVOKED" => 0},
                  "pkcs7_decrypt"   => {"PASSWD" => 0,
                                        "KEY"    => 0,
                                        "CERT"   => 0,
                                        "PKCS7"  => 1},
                  "pkcs7_encrypt"   => {"CERT"    => 0,
                                        "ENC_ALG" => ["__undef", "aes256","aes192","aes128","idea","des3","des"],
                                        "CONTENT" => 1},
                  "pkcs7_get_chain" => {"SIGNER" => 1,
                                        "PKCS7"  => 1},
                  "pkcs7_sign"      => {"PASSWD"  => 0,
                                        "KEY"     => 0,
                                        "CERT"    => 0,
                                        "CONTENT" => 1},
                  "pkcs7_verify"    => {"CHAIN"   => 0,
                                        "CONTENT" => 1,
                                        "PKCS7"   => 1}
                 );

    ## FIXME: actually we check only for the allowed parameter
    ## FIXME: if want to make this a real API enforcer then we must check the content too
    ## FIXME: perhaps Sergei or Julia could do this?

    foreach my $param (keys %{$keys})
    {
        next if ($param eq "DEBUG");
        next if ($param eq "COMMAND");
        if (not exists $params{$command}->{$param})
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_COMMAND_ILLEGAL_PARAM",
                params  => {COMMAND => $command, PARAM => $param});
        }
    }

    return $self->{INSTANCE}->command ($keys);
}

sub get_object
{
    my $self = shift;
    my $keys = shift;

    foreach my $param (keys %{$keys})
    {
        if ($param ne "DATA" and
            $param ne "DEBUG" and
            $param ne "FORMAT" and
            $param ne "TYPE")
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_GET_OBJECT_ILLEGAL_PARAM",
                params  => {NAME => $param, VALUE => $keys->{$param}});
        }
    }

    if (not defined $keys->{DATA} or
        not length $keys->{DATA})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_GET_OBJECT_MISSING_DATA");
    }

    if ($keys->{TYPE} ne "X509" and
        $keys->{TYPE} ne "CSR" and
        $keys->{TYPE} ne "CRL")
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_GET_OBJECT_ILLEGAL_TYPE",
            params  => {TYPE => $keys->{TYPE}});
    }

    if (not $keys->{DEBUG})
    {
        $keys->{DEBUG} = CTX('debug');
    }

    $keys->{FORMAT} = "PEM" if (not $keys->{FORMAT});
    $keys->{FORMAT} = "PEM" if ($keys->{TYPE} eq "CSR" and $keys->{FORMAT} eq "PKCS10");

    if ($keys->{FORMAT} ne "PEM" and
        $keys->{FORMAT} ne "DER" and
        ($keys->{TYPE} ne "CSR" or $keys->{FORMAT} ne "SPKAC")
       )
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_GET_OBJECT_ILLEGAL_FORMAT",
            params  => {TYPE => $keys->{TYPE}, FORMAT => $keys->{FORMAT}});
    }

    my $ref = $self->{INSTANCE}->get_object ($keys);
    if ($keys->{TYPE} eq "CSR" and $keys->{FORMAT} eq "SPKAC")
    {
        $self->{OBJECT_CACHE}->{$ref} = "SPKAC"
    } else {
        $self->{OBJECT_CACHE}->{$ref} = $keys->{TYPE};
    }
    return $ref;
}

sub get_object_function
{
    my $self = shift;
    my $keys = shift;

    foreach my $param (keys %{$keys})
    {
        if ($param ne "DEBUG" and
            $param ne "OBJECT" and
            $param ne "FUNCTION")
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_GET_OBJECT_FUNCTION_ILLEGAL_PARAM",
                params  => {NAME => $param, VALUE => $keys->{$param}});
        }
    }

    if (not $keys->{DEBUG})
    {
        $keys->{DEBUG} = CTX('debug');
    }

    if (not ref $keys->{OBJECT})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_GET_OBJECT_FUNCTION_OBJECT_NO_REF");
    }

    if (not exists $self->{OBJECT_CACHE} or
        not exists $self->{OBJECT_CACHE}->{$keys->{OBJECT}})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_GET_OBJECT_FUNCTION_OBJECT_NOT_IN_CACHE");
    }

    my $type = $self->{OBJECT_CACHE}->{$keys->{OBJECT}};

    my @functions = ();
    if ($type eq "X509")
    {
        @functions = ("serial", "subject", "issuer", "notbefore", "notafter",
                      "alias", "modulus", "pubkey", "fingerprint", "emailaddress",
                      "version", "pubkey_algorithm", "signature_algorithm", "exponent",
                      "keysize", "extensions", "openssl_subject"
                     );
    }
    elsif ($type eq "CSR")
    {
        @functions = ("subject", "version", "signature_algorithm",
                      "pubkey", "pubkey_hash", "keysize", "pubkey_algorithm",
                      "exponent", "modulus", "extensions");
    }
    elsif ($type eq "SPKAC")
    {
        @functions = ("pubkey", "keysize", "pubkey_algorithm", "exponent", "modulus",
                      "pubkey_hash", "signature_algorithm");
    }
    else ## CRL
    {
        @functions = ("version", "issuer", "next_update", "last_update",
                      "signature_algorithm", "revoked", "serial");
    }

    if (not grep (/$keys->{FUNCTION}/, @functions))
    {
         OpenXPKI::Exception->throw (
             message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_GET_OBJECT_FUNCTION_ILLEGAL_FUNCTION",
             params  => {FUNCTION => $keys->{FUNCTION}, TYPE => $type});
    }

    return $self->{INSTANCE}->get_object_function ($keys);
}

sub free_object
{
    my $self   = shift;
    my $object = shift;

    if (not ref $object)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_FREE_OBJECT_NO_REF");
    }

    if (not exists $self->{OBJECT_CACHE} or
        not exists $self->{OBJECT_CACHE}->{$object})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_FREE_OBJECT_NOT_IN_CACHE");
    }

    delete $self->{OBJECT_CACHE}->{$object};
    return $self->{INSTANCE}->free_object ($object);
}

sub login
{
    my $self = shift;

    if (@_)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_LOGIN_ILLEGAL_PARAM");
    }
    $self->{INSTANCE}->login();
}

sub logout
{
    my $self = shift;

    if (@_)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_LOGOUT_ILLEGAL_PARAM");
    }
    $self->{INSTANCE}->logout();
}

sub online
{
    my $self = shift;

    if (@_)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_ONLINE_ILLEGAL_PARAM");
    }
    $self->{INSTANCE}->online();
}

sub key_online
{
    my $self = shift;

    if (@_)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_KEY_ONLINE_ILLEGAL_PARAM");
    }
    $self->{INSTANCE}->key_online();
}

sub get_mode
{
    my $self = shift;

    if (@_)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_GET_MODE_ILLEGAL_PARAM");
    }
    $self->{INSTANCE}->get_mode();
}

sub get_certfile
{
    my $self = shift;

    if (@_)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_GET_CERTFILE_ILLEGAL_PARAM");
    }
    $self->{INSTANCE}->get_certfile();
}

sub DESTROY
{
    my $self = shift;

    ## enforce destruction of backend instance
    delete $self->{INSTANCE};
}

our $AUTOLOAD;
sub AUTOLOAD {
    my $self = shift;

    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_UNSUPPORTED_FUNCTION",
        params  => {"FUNCTION" => $AUTOLOAD});
}

1;
__END__
