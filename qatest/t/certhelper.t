#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use File::Path qw(make_path);

BEGIN { use_ok( 'CertHelper' ); };
#require_ok( 'CertHelper' );

my $ch;


foreach my $dir ( qw( t/certhelper.d t/certhelper.d2 ) ) {
    make_path($dir, { error => \my $err} );
    if ( @{ $err } ) {
        for my $diag (@{ $err }) {
            my ($file, $message) = %{ $diag };
            if ( $file eq '' ) {
                die "Error running make_path: $message";
            } else {
                die "Error making dir $file: $message";
            }
        }
    }
    my $fh;
    open( $fh, '>' . $dir . '/key.pas') or die "Error opening $dir/key.pas: $!";
    print($fh 'mysecrettestpassword') or die "Error writing $dir/key.pas: $!";
    close($fh) or die "Error closing $dir/key.pas: $!";
}

ok($ch = CertHelper->new( basedir => 't/certhelper.d' ), 'create new CH instance');
ok($ch->createcert(), 'create cert');
foreach my $f ( qw( openssl.conf key.der crt.pem key.pas ) ) {
    ok(-f 't/certhelper.d/'.$f, 'created ' . $f);
}

ok($ch = CertHelper->new( basedir => 't/certhelper.d2', commonName => 'test2.openxpki.org' ), 'create second CH instance');
ok($ch->createcert(), 'create second cert');
foreach my $f ( qw( openssl.conf key.der crt.pem key.pas ) ) {
    ok(-f 't/certhelper.d2/'.$f, 'created ' . $f);
}

done_testing();






