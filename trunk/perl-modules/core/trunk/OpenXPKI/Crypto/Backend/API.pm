## OpenXPKI::Crypto::Backend::API
## Written 2006 by Michael Bell for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project
## $Revision$
	
use strict;
use warnings;

package OpenXPKI::Crypto::Backend::API;

use OpenXPKI::Debug 'OpenXPKI::Crypto::Backend::API';
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use English;

## scalar value:
##     - 0 means the parameter is optional
##     - 1 means the parameter is required
## array values:
##     - an array represent the allowed parameters
##     - element "__undef" in the array means that the parameter is optional
## hash values:
##     - "" => {...} (these are the default parameters
##     - "TYPE:EC" => {...} means parameters if TYPE => "EC" is used

our %COMMAND_PARAMS =
(
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
    "create_key"      => {"PASSWD"     => 0,
                          "TYPE"       => ["RSA","DSA","EC"],
                          "PARAMETERS" => {"TYPE:RSA" =>
                                              {"ENC_ALG" =>
                                                  ["__undef",
                                                   "aes256",
                                                   "aes192",
                                                   "aes128",
                                                   "idea",
                                                   "des3",
                                                   "des"
                                                  ],
                                               "KEY_LENGTH" =>
                                                  [512, 768, 1024,
                                                   2048, 4096
                                                  ]
                                              },
                                           "TYPE:DSA" =>
                                              {"ENC_ALG" =>
                                                  ["__undef",
                                                   "aes256",
                                                   "aes192",
                                                   "aes128",
                                                   "idea",
                                                   "des3",
                                                   "des"
                                                  ],
                                               "KEY_LENGTH" =>
                                                  [512, 768, 1024,
                                                   2048, 4096
                                                  ]
                                              },
                                           "TYPE:EC" =>
                                              {"ENC_ALG" =>
                                                  ["__undef",
                                                   "aes256",
                                                   "aes192",
                                                   "aes128",
                                                   "idea",
                                                   "des3",
                                                   "des"
                                                  ],
                                               "CURVE_NAME" => 0
                                              },
                                          }
                         },
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

sub new
{
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};
    bless $self, $class;

    my $keys = shift;

    ## check for missing but required parameters

    if (not $keys->{CLASS})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_NEW_MISSING_CLASS");
    }
    if (not $keys->{NAME})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_NEW_MISSING_NAME");
    }
    if (not exists $keys->{PKI_REALM_INDEX})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_NEW_MISSING_PKI_REALM_INDEX");
    }
    if (not $keys->{TOKEN_TYPE})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_NEW_MISSING_TOKEN_TYPE");
    }
    if (not exists $keys->{TOKEN_INDEX})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_NEW_MISSING_TOKEN_INDEX");
    }

    $self->{CLASS} = $keys->{CLASS};
    delete $keys->{CLASS};

    foreach my $key (keys %{$keys})
    {
        next if (grep /^$key$/, ("TMP", "NAME",
                                 "PKI_REALM_INDEX",
                                 "TOKEN_TYPE", "TOKEN_INDEX"));
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_NEW_ILLEGAL_PARAMETER",
            params  => {NAME => $key, VALUE => $keys->{$key}});
    }

    eval "require ".$self->{CLASS};
    if ($@)
    {
        my $text = $@;
        ##! 4: "compilation of driver ".$self->{CLASS}." failed\n$text"
        OpenXPKI::Exception->throw (message => $text);
    }
    ##! 2: "class: ".$self->{CLASS}

    ## get the token
    $self->{INSTANCE} = $self->{CLASS}->new ($keys);
    ##! 1: "end - no exception during new()"

    return $self;
}

sub command
{
    my $self = shift;
    my $keys = shift;

    my $command = $keys->{COMMAND};


    ## FIXME: actually we check only for the allowed parameter
    ## FIXME: if want to make this a real API enforcer then we must check the content too
    ## FIXME: perhaps Sergei or Julia could do this?

    foreach my $param (keys %{$keys})
    {
        next if ($param eq "COMMAND");

        ## FIXME: missing parameters must be detected by the command itself

        $self->__check_command_param ({
            PARAMS       => $keys,
            PARAM_PATH   => [ $param ],
            COMMAND      => $command,
            COMMAND_PATH => [ $param ]});
    }

    return $self->{INSTANCE}->command ($keys);
}

sub __check_command_param
{
    my $self = shift;
    my $keys = shift;

    ## we need a hash ref with path to actual hash ref
    ## we need the command and the actual parameter path

    my $params = $keys->{PARAMS};
    foreach my $key (@{$keys->{PARAM_PATH}})
    {
        $params = $params->{$key};
    }

    my $cmd = $COMMAND_PARAMS{$keys->{COMMAND}};
    foreach my $key (@{$keys->{COMMAND_PATH}})
    {
        ## check if the used parameter is legal (parameter => 0)
        if (not exists $cmd->{$key})
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_COMMAND_ILLEGAL_PARAM",
                params  => {COMMAND => $keys->{COMMAND},
                            PARAM   => join (", ", @{$keys->{COMMAND_PATH}})});
        }
        $cmd = $cmd->{$key};
    }

    ## this is only a check for the existence
    return 1 if (not ref $cmd);

    ## if we have an array which we can check then do it
    if (ref $cmd and ref $cmd eq "ARRAY")
    {
        if (not grep (/^$params$/, @{$cmd}))
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_COMMAND_ILLEGAL_VALUE",
                params  => {COMMAND => $keys->{COMMAND},
                            PARAM   => join (", ", @{$keys->{PARAM_PATH}}),
                            VALUE   => $params});
        } else {
            return 1;
        }
    }

    ## if we have a hash here then there is substructure in the config
    if (ref $cmd    and ref $cmd    eq "HASH" and
        ref $params and ref $params eq "HASH")
    {
        my $next = undef;

        ## first try to identify the correct hash
        foreach my $key (keys %{$cmd})
        {
            my $name = $key;
               $name =~ s/:.*$//;
            my $value = $key;
               $value =~ s/^[^\:]*://;
            my @path = @{$keys->{PARAM_PATH}};
            pop @path;
            push @path, $name;
            my $root = $keys->{PARAMS};
            foreach my $elem (@path)
            {
                $root = $root->{$elem} if ($root and ref $root and
                                           exists $root->{$elem});
            }
            if ($root eq $value)
            {
                $next = $key;
                last;
            }
        }

        ## use the default if present and nothing else is found
        $next = ""
            if (not defined $next and exists $cmd->{""});
        $next = ":"
            if (not defined $next and exists $cmd->{":"});

        ## restart the check
        foreach my $key (keys %{$params})
        {
            $self->__check_command_param ({
                PARAMS       => $keys->{PARAMS},
                PARAM_PATH   => [ @{$keys->{PARAM_PATH}}, $key ],
                COMMAND      => $keys->{COMMAND},
                COMMAND_PATH => [ @{$keys->{COMMAND_PATH}}, $next, $key ]});
        }

        ## anything looks ok
        return 1;
    }

    ## no more checks to perform and no error detected
    ## nevertheless there is a wrong config
    OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_COMMAND_WRONG_CONFIG",
        params  => {COMMAND => $keys->{COMMAND}});
}

sub get_object
{
    my $self = shift;
    my $keys = shift;

    foreach my $param (keys %{$keys})
    {
        if ($param ne "DATA" and
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
        if ($param ne "OBJECT" and
            $param ne "FUNCTION")
        {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_GET_OBJECT_FUNCTION_ILLEGAL_PARAM",
                params  => {NAME => $param, VALUE => $keys->{$param}});
        }
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

=head1 Description   
    
this is the basic class for crypto backend API.
        
=head1 Functions
     
=head2 new
 
is the constructor.
