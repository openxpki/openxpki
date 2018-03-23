#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;

# Project modules
use lib $Bin, "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;

plan tests => 12;

#
# Init helpers
#
my $oxitest = OpenXPKI::Test->new(
    with => [qw( CryptoLayer )],
    #log_level => 'trace',
);
my $tempdir = $oxitest->testenv_root;

sub is_encrypted_key {
    my ($key_enc, $password, $algo) = @_;
    my $algo_uc = uc($algo);
    my $skip_decoding = 0;
    subtest "key headers" => sub {
        like $key_enc, qr/^-----BEGIN ENCRYPTED PRIVATE KEY-----/, "encrypted key header"
            or $skip_decoding = 1;
        SKIP: {
            skip "Previous test failed, so this is useless", 1 if $skip_decoding;
            skip "OpenSSL executable not found", 1 if not `which openssl`;
            # write encrypted key
            open my $fh, ">", "$tempdir/key_enc"
                or BAIL_OUT "Error creating temporary file $tempdir/key_enc";
            print $fh $key_enc;
            close $fh;
            # decrypt key
            `OPENSSL_CONF=/dev/null openssl $algo -in "$tempdir/key_enc" -passin "pass:$password" -out "$tempdir/key_dec" > /dev/null 2>&1`;
            # read decrypted key
            open $fh, '<', "$tempdir/key_dec"
                or BAIL_OUT "Error reading temporary file $tempdir/key_dec";
            local $/;
            my $key_dec = <$fh>;
            close $fh;

            like $key_dec, qr/^-----BEGIN \Q$algo_uc\E PRIVATE KEY-----/, "decrypted key header ($algo)";
        }
    };
}

my $password = "towhom?";
my $key;

#
# RSA
#

# key with default arguments
lives_ok {
    $key = $oxitest->api2_command("generate_key" => {
        password  => $password,
    });
} "create RSA key (as default)";
is_encrypted_key $key, $password, "rsa";

# RSA key with KEY_LENGTH
lives_ok {
    $key = $oxitest->api2_command("generate_key" => {
        password  => $password,
        key_alg => "RSA",
        enc_alg => "AES256",
        key_length => 1024,
    });
} "create RSA key with 'key_length'";
is_encrypted_key $key, $password, "rsa";

# RSA key with PKEYOPT
lives_ok {
    $key = $oxitest->api2_command("generate_key" => {
        password  => $password,
        key_alg => "RSA",
        enc_alg => "AES256",
        pkeyopt => { rsa_keygen_bits => 1024 }
    });
} "create RSA key with 'pkeyopt'";
is_encrypted_key $key, $password, "rsa";

#
# DSA
#
# DSA key with KEY_LENGTH
lives_ok {
    $key = $oxitest->api2_command("generate_key" => {
        password  => $password,
        key_alg => "DSA",
        enc_alg => "AES256",
        key_length => 1024,
    });
} "create DSA key with 'key_length'";
is_encrypted_key $key, $password, "dsa";

#
# EC
#

# EC key with CURVE_NAME
lives_ok {
    $key = $oxitest->api2_command("generate_key" => {
        password  => $password,
        key_alg => "EC",
        enc_alg => "AES256",
        curve => "sect571r1",
    });
} "create EC key with 'curve'";
is_encrypted_key $key, $password, "ec";

# EC key with readily prepared ECPARAM
my $params = $oxitest->api2_command("get_default_token")->command({
    COMMAND => 'create_params',
    TYPE    => 'EC',
    PKEYOPT => { ec_paramgen_curve => "sect571r1" }
});
lives_ok {
    $key = $oxitest->api2_command("generate_key" => {
        password  => $password,
        key_alg => "EC",
        enc_alg => "AES256",
        paramset => $params,
    });
} "create EC key with 'paramset'";
is_encrypted_key $key, $password, "ec";

