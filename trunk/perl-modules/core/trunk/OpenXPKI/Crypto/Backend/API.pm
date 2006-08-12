## OpenXPKI::Crypto::Backend::API
## Written 2006 by Michael Bell for the OpenXPKI project
## Converted to use Class::Std and OpenXPKI::Crypto::API
## 2006 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project
## $Revision$
package OpenXPKI::Crypto::Backend::API;
use base qw( OpenXPKI::Crypto::API );
	
use strict;
use warnings;

use Class::Std;
use OpenXPKI::Debug 'OpenXPKI::Crypto::Backend::API';
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use Data::Dumper;
use English;
#use Smart::Comments;

## scalar value:
##     - 0 means the parameter is optional
##     - 1 means the parameter is required
## array values:
##     - an array represent the allowed parameters
##     - element "__undef" in the array means that the parameter is optional
## hash values:
##     - "" => {...} (these are the default parameters
##     - "TYPE:EC" => {...} means parameters if TYPE => "EC" is used


my %object_cache_of :ATTR; # the object cache attribute

sub __init_command_params : PRIVATE {
    ##! 16: 'start'
    my $self = shift;

    $self->set_command_params({
    "convert_cert"    => {"DATA"             => 1,
                          "OUT"              => ["DER","TXT","PEM"],
                          "CONTAINER_FORMAT" => 0,
                          },
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
                          "TYPE"       => ["RSA","DSA","EC","GOST94"],
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
                                               "CURVE_NAME" => 1,
                                              },
                                           "TYPE:GOST94" =>
                                              {"ENC_ALG" =>
                                                  ["__undef",
                                                   "aes256",
                                                   "aes192",
                                                   "aes128",
                                                   "idea",
                                                   "des3",
                                                   "des"
                                                  ],
                                               "PASSWD" => 0,
                                               "PARAMSET" => 0
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
    "is_prime"        => {"PRIME"   => 1,
                         },
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
                          "PKCS7"   => 1},
    "symmetric_cipher" => {"DATA"   => 1,
			   "PASSWD" => 0,
			   "KEY"    => 0,
			   "IV"     => 0,
			   "MODE"   => [ "ENCRYPT", "DECRYPT" ],
			   "ENC_ALG"        => ["__undef",
						"aes-128-cbc",
						"aes-128-cfb",
						"aes-128-cfb1",
						"aes-128-cfb8",
						"aes-128-ecb",
						"aes-128-ofb",
						"aes-192-cbc",
						"aes-192-cfb",
						"aes-192-cfb1",
						"aes-192-cfb8",
						"aes-192-ecb",
						"aes-192-ofb",
						"aes-256-cbc",
						"aes-256-cfb",
						"aes-256-cfb1",
						"aes-256-cfb8",
						"aes-256-ecb",
						"aes-256-ofb",
						"aes128",
						"aes192",
						"aes256",
						"des-ede3",
						"des-ede3-cbc",
						"des-ede3-cfb",
						"des-ede3-ofb",
						"des3",
			       ],
                            },
    });
   ##! 16: 'end'
}

sub START {
    ##! 16: 'start'
    my ($self, $ident, $arg_ref) = @_;

    ## check for missing but required parameters

    $self->__init_command_params();
    
    ##! 16: 'after __init_command_params()'
    ##! 16: 'get_command_params() child: ' . Dumper($self->get_command_params())
    if (not exists $arg_ref->{NAME}) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_NEW_MISSING_NAME");
    }
    if (not exists $arg_ref->{PKI_REALM_INDEX}) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_NEW_MISSING_PKI_REALM_INDEX");
    }
    if (not exists $arg_ref->{TOKEN_TYPE}) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_NEW_MISSING_TOKEN_TYPE");
    }
    if (not exists $arg_ref->{TOKEN_INDEX}) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_NEW_MISSING_TOKEN_INDEX");
    }

    delete $arg_ref->{CLASS};

    foreach my $key (keys %{$arg_ref})
    {
        next if (grep /^$key$/, ("TMP", "NAME",
                                 "PKI_REALM_INDEX",
                                 "TOKEN_TYPE", "TOKEN_INDEX"));
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_NEW_ILLEGAL_PARAMETER",
            params  => {NAME => $key, VALUE => $arg_ref->{$key}});
    }
}

sub get_cmd_param {
    my $self = shift;
    my $arg = shift;

    my $command_params = $self->get_command_params();
    my %rc = %{$command_params->{$arg}};
    ### %rc
    #return $command_params->{$arg};
    return \%rc;
}

sub get_object {
    my $self = shift;
    my $ident = ident $self;
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

    my $ref = $self->get_instance()->get_object($keys);
    if ($keys->{TYPE} eq "CSR" and $keys->{FORMAT} eq "SPKAC")
    {
        $object_cache_of{$ident}->{$ref} = "SPKAC";
    } else {
        $object_cache_of{$ident}->{$ref} = $keys->{TYPE};
    }
    return $ref;
}

sub get_object_function {
    my $self = shift;
    my $ident = ident $self;
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

    if (not exists $object_cache_of{$ident} or
        not exists $object_cache_of{$ident}->{$keys->{OBJECT}})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_GET_OBJECT_FUNCTION_OBJECT_NOT_IN_CACHE");
    }

    my $type = $object_cache_of{$ident}->{$keys->{OBJECT}};

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

    return $self->get_instance()->get_object_function($keys);
}

sub free_object {
    my $self   = shift;
    my $ident  = ident $self;
    my $object = shift;

    if (not ref $object)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_FREE_OBJECT_NO_REF");
    }

    if (not exists $object_cache_of{$ident} or
        not exists $object_cache_of{$ident}->{$object})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_CRYPTO_BACKEND_API_FREE_OBJECT_NOT_IN_CACHE");
    }

    delete $object_cache_of{$ident}->{$object};
    return $self->get_instance()->free_object ($object);
}


1;
__END__

=head1 Name

OpenXPKI::Crypto::Backend::API - API for cryptographic backends.

=head1 Description   
    
this is the basic class for crypto backend API. It inherits from
OpenXPKI::Crypto::API
        
=head1 Functions
     
=head2 START
 
is the constructor.

=head2 get_cmd_param

get the command_params entry for the specified command

