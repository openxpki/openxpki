use Test;
BEGIN { plan tests => 2 };

print STDERR "Cleanup\n";

unlink ("t/crypto/cakey.pem");
unlink ("t/crypto/cacert.pem");

unlink ("t/crypto/passwd.txt");
unlink ("t/crypto/dsa.pem");
unlink ("t/crypto/rsa.pem");
unlink ("t/crypto/pkcs10.pem");
unlink ("t/crypto/cert.pem");
unlink ("t/crypto/crl.pem");

unlink ("t/crypto/index.txt.attr");
unlink ("t/crypto/index.txt");
unlink ("t/crypto/serial");
unlink ("t/crypto/index.txt.attr.old");
unlink ("t/crypto/index.txt.old");
unlink ("t/crypto/serial.old");
unlink ("t/crypto/crlnumber");

ok(1);

if (-e "t/crypto/cakey.pem" or
    -e "t/crypto/cacert.pem" or
    -e "t/crypto/passwd.txt" or
    -e "t/crypto/dsa.pem" or
    -e "t/crypto/rsa.pem" or
    -e "t/crypto/pkcs10.pem" or
    -e "t/crypto/cert.pem" or
    -e "t/crypto/crl.pem" or
    -e "t/crypto/index.txt.attr" or
    -e "t/crypto/index.txt" or
    -e "t/crypto/serial" or
    -e "t/crypto/index.txt.attr.old" or
    -e "t/crypto/index.txt.old" or
    -e "t/crypto/serial.old" or
    -e "t/crypto/crlnumber")
{
    ok(0);
} else {
    ok(1);
}

1;
