use strict;
use warnings;
use Test;

my @files = ();

foreach my $cadir (qw( ca1 ca2 cagost canciph )) {
    push @files, 
    "t/25_crypto/$cadir/cakey.pem",
    "t/25_crypto/$cadir/cacert.pem",
    
    "t/25_crypto/$cadir/passwd.txt",
    "t/25_crypto/$cadir/dsa.pem",
    "t/25_crypto/$cadir/ec.pem",
    "t/25_crypto/$cadir/rsa.pem",
    "t/25_crypto/$cadir/pkcs10.pem",
    "t/25_crypto/$cadir/cert.pem",
    "t/25_crypto/$cadir/crl.pem",
    "t/25_crypto/$cadir/key_94.pem",

    "t/25_crypto/$cadir/key_2001.pem",
    "t/25_crypto/$cadir/pkcs10_2001.pem",
    "t/25_crypto/$cadir/cert_2001.pem",

    "t/25_crypto/$cadir/key_94cp.pem",
    "t/25_crypto/$cadir/pkcs10_94cp.pem",
    "t/25_crypto/$cadir/cert_94cp.pem",

    "t/25_crypto/$cadir/key_2001cp.pem",
    "t/25_crypto/$cadir/pkcs10_2001cp.pem",
    "t/25_crypto/$cadir/cert_2001cp.pem",

    "t/25_crypto/$cadir/utf8.0.pkcs10.pem",
    "t/25_crypto/$cadir/utf8.0.cert.pem",
    "t/25_crypto/$cadir/utf8.0.crl.pem",
    
    "t/25_crypto/$cadir/utf8.1.pkcs10.pem",
    "t/25_crypto/$cadir/utf8.1.cert.pem",
    "t/25_crypto/$cadir/utf8.1.crl.pem",
    
    "t/25_crypto/$cadir/utf8.2.pkcs10.pem",
    "t/25_crypto/$cadir/utf8.2.cert.pem",
    "t/25_crypto/$cadir/utf8.2.crl.pem",
    
    "t/25_crypto/$cadir/index.txt.attr",
    "t/25_crypto/$cadir/index.txt",
    "t/25_crypto/$cadir/serial",
    "t/25_crypto/$cadir/index.txt.attr.old",
    "t/25_crypto/$cadir/index.txt.old",
    "t/25_crypto/$cadir/serial.old",
    "t/25_crypto/$cadir/crlnumber",
}

## 4 * number of files
BEGIN { plan tests => 280 };

print STDERR "OpenXPKI::Crypto Cleanup\n";

foreach my $filename (@files)
{
    ok(not -e $filename or unlink ($filename));
    ok(not -e $filename);
}

1;
