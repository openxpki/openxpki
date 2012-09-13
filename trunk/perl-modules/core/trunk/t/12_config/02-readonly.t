# t/12_config/02-readonly.t
#
# vim: syntax=perl

use Test::More tests => 5;

use strict;
use warnings;
use DateTime;
use Path::Class;

my $tpath = dir($0)->parent;
my $gitdb = $tpath . '/01-initdb.git';
my ( $ver1, $ver2, $ver3 );

if ( $tpath eq 't/12_config' ) {
    $ver3 = '64510ebec38db5581cb2f18001c9307d6595cf08';
}
elsif ( $tpath eq '12_config' ) {
    $ver3 = '3cb0ae44ae1422c9e5b189495ae228191bdd797c';
}
 

$ENV{OPENXPKI_CONF_DB} = $gitdb;

ok( -d $gitdb, "Test repo exists" );

use_ok('OpenXPKI::Config');

my $cfg = OpenXPKI::Config->new( );

ok( $cfg, 'create new config instance' );
is( $cfg->get_version(), $ver3, 'check version of HEAD' );

is( $cfg->get('some.test'), '43', "HEAD version of some.test" );
