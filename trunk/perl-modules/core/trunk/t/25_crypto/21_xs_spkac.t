use strict;
use warnings;
use English;
use Test::More;
plan tests => 13;

diag "OpenXPKI::Crypto::Backend::OpenSSL::SPKAC\n";

use OpenXPKI::Debug;
if ($ENV{DEBUG_LEVEL}) {
    $OpenXPKI::Debug::LEVEL{'.*'} = $ENV{DEBUG_LEVEL};
}

use OpenXPKI::Crypto::TokenManager;

our $cache;
our $basedir;
our $cacert;
eval `cat t/25_crypto/common.pl`;

is($EVAL_ERROR, '', 'common.pl evaluation');

## parameter checks for TokenManager init

my $mgmt = OpenXPKI::Crypto::TokenManager->new('IGNORE_CHECK' => 1);
ok ($mgmt, 'TokenManager creation');

## parameter checks for get_token

my $token = $mgmt->get_token (
    TYPE => "CA", 
    ID => "INTERNAL_CA_1", 
    PKI_REALM => "Test Root CA",
    CERTIFICATE => $cacert,
);
ok ($mgmt, 'get_token()');

## create SPKAC request
$ENV{pwd} = OpenXPKI->read_file ("$basedir/ca1/passwd.txt");
ok($ENV{pwd}, 'Password reading from file');

my $shell_path = `cat t/cfg.binary.openssl`; # openssl executable to use
my $spkac = `$shell_path spkac -key $basedir/ca1/rsa.pem -passin env:pwd`;
ok($spkac, 'OpenSSL SPKAC conversion');

# SPKAC needs the raw SPKAC data without the SPKAC= openssl 'header'
$spkac =~ s{\A SPKAC=}{}xms;

## get object
$spkac = $token->get_object ({DATA => $spkac, TYPE => "CSR", FORMAT => "SPKAC"});
ok($spkac, 'get_object()');

## check that all required functions are available and work
foreach my $func ("pubkey_algorithm", "pubkey", "keysize", "modulus", "exponent", "pubkey_hash", "signature_algorithm")
{
    ## FIXME: this is a bypass of the API !!!
    my $result = $spkac->$func();
    ok($result, "SPKAC object method $func");
    diag "$func: $result\n" if ($ENV{DEBUG});
}

1;
