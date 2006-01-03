use strict;
use warnings;
use Test;

my @files = (
             "t/25_crypto/ca1/cakey.pem",
             "t/25_crypto/ca1/cacert.pem",

             "t/25_crypto/ca1/passwd.txt",
             "t/25_crypto/ca1/dsa.pem",
             "t/25_crypto/ca1/ec.pem",
             "t/25_crypto/ca1/rsa.pem",
             "t/25_crypto/ca1/pkcs10.pem",
             "t/25_crypto/ca1/cert.pem",
             "t/25_crypto/ca1/crl.pem",

             "t/25_crypto/ca1/utf8.0.pkcs10.pem",
             "t/25_crypto/ca1/utf8.0.cert.pem",
             "t/25_crypto/ca1/utf8.0.crl.pem",

             "t/25_crypto/ca1/utf8.1.pkcs10.pem",
             "t/25_crypto/ca1/utf8.1.cert.pem",
             "t/25_crypto/ca1/utf8.1.crl.pem",

             "t/25_crypto/ca1/utf8.2.pkcs10.pem",
             "t/25_crypto/ca1/utf8.2.cert.pem",
             "t/25_crypto/ca1/utf8.2.crl.pem",

             "t/25_crypto/ca1/index.txt.attr",
             "t/25_crypto/ca1/index.txt",
             "t/25_crypto/ca1/serial",
             "t/25_crypto/ca1/index.txt.attr.old",
             "t/25_crypto/ca1/index.txt.old",
             "t/25_crypto/ca1/serial.old",
             "t/25_crypto/ca1/crlnumber",
            );

## 2 * number of file
BEGIN { plan tests => 50 };

print STDERR "OpenXPKI::Crypto Cleanup\n";

foreach my $filename (@files)
{
    ok(not -e $filename or unlink ($filename));
    ok(not -e $filename);
}

1;
