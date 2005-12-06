use strict;
use warnings;
use Test;
use File::Spec;

our $basedir;
require 't/25_crypto/common.pl';

BEGIN { plan tests => 2 };

print STDERR "Cleanup\n";

my @testfiles = qw(cakey.pem         cacert.pem        passwd.txt
                   index.txt.attr    index.txt         index.txt.attr.old
                   index.txt.old     serial            serial.old
                   crlnumber         dsa.pem           ec.pem
                   rsa.pem           crl.pem           pkcs10.pem
                   cert.pem
                   utf8.0.cert.pem   utf8.1.cert.pem   utf8.2.cert.pem
                   utf8.0.crl.pem    utf8.1.crl.pem    utf8.2.crl.pem
                   utf8.0.pkcs10.pem utf8.1.pkcs10.pem utf8.2.pkcs10.pem
);

for my $dir (qw(ca1 ca2)) {

    my $cleanup_error = 0;
    # clean up CA specific files
    for my $file (@testfiles) {

	my $topurge = File::Spec->catfile($basedir, $dir, $file);
	if (-e $topurge && !unlink $topurge) {
	    $cleanup_error++;
	}

	if (-e $topurge) {
	    $cleanup_error++;
	}
    }

    ok(! $cleanup_error);
}

1;
