use strict;
use warnings;
use Test::More;
use English;

plan tests => 19;

print STDERR "OpenXPKI::Crypto::Backend::OpenSSL::PKCS10\n" if $ENV{VERBOSE};

use OpenXPKI::Crypto::TokenManager;

our $cache;
our $basedir;
our $cacert;
eval `cat t/25_crypto/common.pl`;

is($EVAL_ERROR, '', 'common.pl evaluated correctly');

SKIP: {
    skip 'crypt init failed', 18 if $EVAL_ERROR;

## parameter checks for TokenManager init

my $mgmt = OpenXPKI::Crypto::TokenManager->new({'IGNORE_CHECK' => 1});
ok ($mgmt, 'Create OpenXPKI::Crypto::TokenManager instance');

my $token = $mgmt->get_token ({
   TYPE => 'certsign',
   NAME => 'test-ca',
   CERTIFICATE => {
        DATA => $cacert,
        IDENTIFIER => 'ignored',
   }
});

ok (defined $token, 'Parameter checks for get_token');

## create PKCS#10 request
my $csr = OpenXPKI->read_file ("$basedir/test-ca/pkcs10.pem");
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

}
1;
