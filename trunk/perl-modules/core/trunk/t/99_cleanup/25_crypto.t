use strict;
use warnings;
use Test;
BEGIN { plan tests => 2 };

print STDERR "OpenXPKI::Crypto Cleanup\n";

unlink ("t/25_crypto/cakey.pem");
unlink ("t/25_crypto/cacert.pem");

unlink ("t/25_crypto/passwd.txt");
unlink ("t/25_crypto/dsa.pem");
unlink ("t/25_crypto/ec.pem");
unlink ("t/25_crypto/rsa.pem");
unlink ("t/25_crypto/pkcs10.pem");
unlink ("t/25_crypto/cert.pem");
unlink ("t/25_crypto/crl.pem");

unlink ("t/25_crypto/index.txt.attr");
unlink ("t/25_crypto/index.txt");
unlink ("t/25_crypto/serial");
unlink ("t/25_crypto/index.txt.attr.old");
unlink ("t/25_crypto/index.txt.old");
unlink ("t/25_crypto/serial.old");
unlink ("t/25_crypto/crlnumber");

ok(1);

if (-e "t/25_crypto/cakey.pem" or
    -e "t/25_crypto/cacert.pem" or
    -e "t/25_crypto/passwd.txt" or
    -e "t/25_crypto/dsa.pem" or
    -e "t/25_crypto/rsa.pem" or
    -e "t/25_crypto/pkcs10.pem" or
    -e "t/25_crypto/cert.pem" or
    -e "t/25_crypto/crl.pem" or
    -e "t/25_crypto/index.txt.attr" or
    -e "t/25_crypto/index.txt" or
    -e "t/25_crypto/serial" or
    -e "t/25_crypto/index.txt.attr.old" or
    -e "t/25_crypto/index.txt.old" or
    -e "t/25_crypto/serial.old" or
    -e "t/25_crypto/crlnumber")
{
    ok(0);
} else {
    ok(1);
}

1;
