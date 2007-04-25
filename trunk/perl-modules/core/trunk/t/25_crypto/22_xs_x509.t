use strict;
use warnings;
use Test;
BEGIN { plan tests => 24 };

print STDERR "OpenXPKI::Crypto::Backend::OpenSSL::X509\n";

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

## create cert
my $cert = OpenXPKI->read_file ("$basedir/ca1/cert.pem");
ok(1);

## get object
$cert = $token->get_object ({DATA => $cert, TYPE => "X509"});
ok(1);

## check that all required functions are available and work
foreach my $func ("version", "serial", "subject", "openssl_subject", "issuer",
                  "notbefore", "notafter", "fingerprint", #"alias",
                  "subject_hash", "emailaddress", "extensions",
                  "pubkey_algorithm", "pubkey", "keysize", "modulus", "exponent",
                  "pubkey_hash", "signature_algorithm", "signature")
{
    ## FIXME: this is a bypass of the API !!!
    my $result = $cert->$func();
    if (defined $result)
    {
        ok(1);
        print STDERR "$func: $result\n" if ($ENV{DEBUG});
    }
    elsif (grep /$func/, ("emailaddress"))
    {
        ok(1);
        print STDERR "$func: not available\n" if ($ENV{DEBUG});
    } else {
        ok(0);
        print STDERR "Error: function $func failed\n";
    }
}

1;
