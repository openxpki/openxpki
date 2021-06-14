#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );
use Digest::SHA qw(sha1_hex);
use MIME::Base64;

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;

# Project modules
use lib $Bin, "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;

plan tests => 2;

#
# Init helpers
#
my $oxitest = OpenXPKI::Test->new(
    with => [qw( CryptoLayer )],
    #log_level => 'trace',
);
my $tempdir = $oxitest->testenv_root;
my $dbdata = $oxitest->certhelper_database;

SKIP: {
    skip "OpenSSL executable not found", 2 if not `which openssl`;
    my $pkcs10;
    my $private_key;
    lives_ok {
        my $token = $oxitest->api2_command("get_default_token");
        $private_key = $token->command({
             COMMAND => 'create_pkey',
             KEY_ALG => "rsa",
             ENC_ALG => "aes256",
             PASSWD  => "blah",
             PKEYOPT => { rsa_keygen_bits => 2048 },
        });
        $pkcs10 = $token->command({
            COMMAND => 'create_pkcs10',
            PASSWD  => "blah",
            KEY     => $private_key,
            SUBJECT => "CN=Dummy Cert,OU=ACME,DC=OpenXPKI,DC=ORG",
        });
    } "Create PKCS10 test certificate request";

    #
    # extract public key bytes via OpenSSL and build reference ID
    #
    open my $fh, ">", "$tempdir/csr.pem" or die("Error creating temporary file $tempdir/csr.pem");
    print $fh $pkcs10 and close $fh;

    $ENV{OPENSSL_CONF} = "/dev/null"; # prevents "WARNING: can't open config file: ..."
    my $csr_info = `openssl req -in "$tempdir/csr.pem" -passin "pass:blah" -text -noout`;

    my ($pub_key_reference) = $csr_info =~ qr{ \A .* Public-Key: [^:]+ Modulus: (.*) (?=Exponent) .* \z }msx;
    # strip whitespace and :
    $pub_key_reference =~ s/[\s:]//gmx;
    # embed bytes in ASN.1 structure like the one returned by Crypt::PKCS10 in "get_key_identifier_from_data"
    $pub_key_reference = join "",
        # 3082 SEQUENCE with 2 byte length spec:
        "3082",
        sprintf("%04X", 4 + 256 + 1 + 5), # length: 266 bytes
            # "modulus": 0282 INTEGER with 2 byte length spec
            "0282",
                "0101",     # length 257 bytes --> aes256 + prefix 00 = positive number
                $pub_key_reference,
            # "publicExponent": 02 INTEGER with 1 byte length spec
            "02",
                "03",       # length: 3 bytes
                "010001";   # 65537 (all RSA public keys use 65537 as exponent)
    # calculate ID like "get_key_identifier_from_data" does
    my $ref_id = uc(join ':', (unpack '(A2)*', sha1_hex(pack('H*', $pub_key_reference))));

    #
    # test command
    #
    my $id = $oxitest->api2_command("get_key_identifier_from_data" => {
        data => $pkcs10,
        format => "PKCS10",
    });
    is $id, $ref_id, "key matches reference";
}
