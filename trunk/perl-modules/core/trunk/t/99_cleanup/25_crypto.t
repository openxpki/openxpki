use strict;
use warnings;
use Test;

my @files = (
             "t/25_crypto/cakey.pem",
             "t/25_crypto/cacert.pem",

             "t/25_crypto/passwd.txt",
             "t/25_crypto/dsa.pem",
             "t/25_crypto/ec.pem",
             "t/25_crypto/rsa.pem",
             "t/25_crypto/pkcs10.pem",
             "t/25_crypto/cert.pem",
             "t/25_crypto/crl.pem",

             "t/25_crypto/utf8.0.pkcs10.pem",
             "t/25_crypto/utf8.0.cert.pem",
             "t/25_crypto/utf8.0.crl.pem",

             "t/25_crypto/utf8.1.pkcs10.pem",
             "t/25_crypto/utf8.1.cert.pem",
             "t/25_crypto/utf8.1.crl.pem",

             "t/25_crypto/utf8.2.pkcs10.pem",
             "t/25_crypto/utf8.2.cert.pem",
             "t/25_crypto/utf8.2.crl.pem",

             "t/25_crypto/index.txt.attr",
             "t/25_crypto/index.txt",
             "t/25_crypto/serial",
             "t/25_crypto/index.txt.attr.old",
             "t/25_crypto/index.txt.old",
             "t/25_crypto/serial.old",
             "t/25_crypto/crlnumber",
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
