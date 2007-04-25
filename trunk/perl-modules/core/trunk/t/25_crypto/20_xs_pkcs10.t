use strict;
use warnings;
use Test;
BEGIN { plan tests => 19 };

print STDERR "OpenXPKI::Crypto::Backend::OpenSSL::PKCS10\n";

use OpenXPKI::Crypto::TokenManager;

our $cache;
our $basedir;
our $cacert;
eval `cat t/25_crypto/common.pl`;

ok(1);

## parameter checks for TokenManager init

my $mgmt = OpenXPKI::Crypto::TokenManager->new('IGNORE_CHECK' => 1);
ok (1);

## parameter checks for get_token

my $token = $mgmt->get_token (
    TYPE => "CA", 
    ID => "INTERNAL_CA_1", 
    PKI_REALM => "Test Root CA",
    CERTIFICATE => $cacert,
);
ok (1);

## create PKCS#10 request
my $csr = OpenXPKI->read_file ("$basedir/ca1/pkcs10.pem");
ok(1);

## get object
$csr = $token->get_object ({DATA => $csr, TYPE => "CSR"});
ok(1);

## check that all required functions are available and work
foreach my $func ("version", "subject", "subject_hash", "fingerprint",
                  "emailaddress", "extensions", # "attributes",
                  "pubkey_algorithm", "pubkey", "keysize", "modulus", "exponent",
                  "pubkey_hash",
                  "signature_algorithm", "signature")
{
    ## FIXME: this is a bypass of the API !!!
    my $result = $csr->$func();
    if (defined $result)
    {
        ok(1);
        print STDERR "$func: $result\n" if ($ENV{DEBUG});
    }
    elsif (grep /$func/, ("extensions", "emailaddress"))
    {
        ok(1);
        print STDERR "$func: not available\n" if ($ENV{DEBUG});
    } else {
        ok(0);
        print STDERR "Error: function $func failed\n";
    }
}

1;
