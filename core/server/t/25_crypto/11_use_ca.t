#!/usr/bin/perl
use strict;
use warnings;
use utf8;

# Core modules
use English;
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;

# Project modules
use OpenXPKI::FileUtils;
use lib "$Bin/../lib";
use OpenXPKI::Test;

plan tests => 17;

#
# Setup env
#
my $oxitest = OpenXPKI::Test->new->setup_env->init_server("crypto_layer");
$oxitest->insert_testcerts;

#
# Tests
#
use_ok "OpenXPKI::Crypto::TokenManager";

my $mgmt;
lives_ok {
    $mgmt = OpenXPKI::Crypto::TokenManager->new;
} 'Create OpenXPKI::Crypto::TokenManager instance';

## parameter checks for get_token
my $ca_token;
lives_and {
    $ca_token = $mgmt->get_token ({
       TYPE => 'certsign',
       NAME => 'alpha-signer-2',
       CERTIFICATE => {
            DATA => $oxitest->certhelper_database->cert("alpha_signer_2")->data,
            IDENTIFIER => 'ignored',
       }
    });
    ok $ca_token;
} 'Get CA token';

my $default_token;
lives_and {
    $default_token = $mgmt->get_system_token({ TYPE => "DEFAULT" });
    ok $default_token;
} 'Get default token';

## create PIN (128 bit == 16 byte)
my $passwd;
lives_and {
    $passwd = $default_token->command({
        COMMAND  => "create_random",
        RANDOM_LENGTH => 16
    });
    ok $passwd;
} 'Create random password';


# TODO Should $default_token->command({COMMAND => "create_pkey"}) be replaced with "generate_key" API method (OpenXPKI::Server::API::Object)?

## create DSA key
lives_and {
    # OpenSSL <= 1.0.1 needs a separate parameter file for DSA keys
    my $params = $default_token->command({
        COMMAND => "create_params",
        TYPE    => "DSA",
        PKEYOPT => {
            dsa_paramgen_bits => "2048",
        },
    });
    my $key = $default_token->command({
        COMMAND => "create_pkey",
        ENC_ALG => "AES256",
        PASSWD  => $passwd,
        PARAM   => $params,
    });
    like $key, qr/^-----BEGIN ENCRYPTED PRIVATE KEY-----/;
} 'Create DSA key';

# TODO test DSA/RSA key creation with wrong parameters (should fail if/once we use "generate_key" API method)
# - wrong KEY_LENGTH value
# - wrong ENC_ALG value

## create EC key
lives_and {
    # OpenSSL <= 1.0.1 needs a separate parameter file for EC keys
    my $params = $default_token->command({
        COMMAND => "create_params",
        TYPE    => "EC",
        PKEYOPT => {
            ec_paramgen_curve => "sect571r1",
        },
    });
    my $key = $default_token->command({
        COMMAND => "create_pkey",
        ENC_ALG => "AES256",
        PASSWD  => $passwd,
        PARAM   => $params,
    });
    like $key, qr/^-----BEGIN ENCRYPTED PRIVATE KEY-----/;
} 'Create EC key';


## create RSA key
my $rsa_key;
lives_and {
    $rsa_key = $default_token->command({
        COMMAND => "create_pkey",
        KEY_ALG => "RSA",
        ENC_ALG => "AES256",
        PASSWD  => $passwd,
        PKEYOPT => {
            rsa_keygen_bits => 2048,
        },
    });
    like $rsa_key, qr/^-----BEGIN ENCRYPTED PRIVATE KEY-----/;
} 'Create RSA key';

## try to create UNSUPPORTED_ALGORITHM key
throws_ok {
    $default_token->command({
        COMMAND => "create_pkey",
        KEY_ALG => "ROT13",
        ENC_ALG => "AES256",
        PASSWD  => $passwd,
    });
} 'OpenXPKI::Exception', 'Refuse to create key with unknown algorithm';

## create CSR (PKCS#10)
my $subject = "cn=John Dö,dc=OpenXPKI,dc=org";
die "Test string is not UTF-8 encoded" unless Encode::is_utf8($subject);
my $csr;
lives_and {
    $csr = $default_token->command({
        COMMAND => "create_pkcs10",
        KEY     => $rsa_key,
        PASSWD  => $passwd,
        SUBJECT => $subject,
    });
    like $csr, qr/^-----BEGIN CERTIFICATE REQUEST-----/;
} 'Create PKCS#10';

## create profile
my $cert_profile;
use_ok "OpenXPKI::Crypto::Profile::Certificate";
lives_and {
    my $cert = $oxitest->certhelper_database->cert("alpha_signer_2");
    $cert_profile = OpenXPKI::Crypto::Profile::Certificate->new(
        TYPE  => "ENDENTITY",
        ID    => "I18N_OPENXPKI_PROFILE_USER",
        CA    => "alpha",
        CACERTIFICATE => {
            DATA        => $cert->data,
            SUBJECT     => $cert->db->{subject},
            IDENTIFIER  => $cert->db->{identifier},
            NOTBEFORE   => $cert->db->{notbefore},
            NOTAFTER    => $cert->db->{notafter},
        },
    );
    $cert_profile->set_serial(1);
    $cert_profile->set_subject($subject);
    is $cert_profile->{PROFILE}->{SUBJECT}, $subject;
} "Create certificate profile";

## create cert
my $cert;
lives_and {
    $cert = $ca_token->command({
        COMMAND => "issue_cert",
        CSR     => $csr,
        PROFILE => $cert_profile,
    });
    like $cert, qr/^-----BEGIN CERTIFICATE-----/;
} "Issue certificate";

## build the PKCS#12 file
lives_and {
    my $pkcs12 = $default_token->command({
        COMMAND => "create_pkcs12",
        PASSWD  => $passwd,
        KEY     => $rsa_key,
        CERT    => $cert,
        CHAIN   => [ $cert ],
    });
    ok $pkcs12;
} "Create PKCS#12";

## create CRL profile
my $crl_profile;
use_ok "OpenXPKI::Crypto::Profile::CRL";
lives_and {
    $crl_profile = OpenXPKI::Crypto::Profile::CRL->new(
        CA => "alpha",
        VALIDITY => {
            VALIDITYFORMAT => 'relativedate',
            VALIDITY => "+000014",
        },
        CACERTIFICATE => $oxitest->certhelper_database->cert("alpha_signer_2")->data,
    );
    is $crl_profile->{PROFILE}->{DAYS}, 14;
} "Create CRL profile";

## otherwise test 34 fails
$crl_profile->set_serial (23);




#### issue crl...
my $crl;
lives_and {
    $crl = $ca_token->command({
        COMMAND => "issue_crl",
        REVOKED => [$cert],
        PROFILE => $crl_profile,
    });
    like $crl, qr/^-----BEGIN X509 CRL-----/;
} "Create CRL";

1;
