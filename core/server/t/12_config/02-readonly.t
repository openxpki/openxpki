# t/12_config/02-readonly.t
#
# vim: syntax=perl

use Test::More tests => 5;

use strict;
use warnings;
use DateTime;
use Path::Class;

use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init($ERROR);

my $tpath = dir($0)->parent;
my $gitdb = $tpath . '/01-initdb.git';
my ( $ver1, $ver2, $ver3 );

if ( $tpath eq 't/12_config' ) {
    $ver3 = '6f4174802f28e61ac23274f5adae0f3dcd681573';
}
elsif ( $tpath eq '12_config' ) {
    $ver3 = '931c7a4cf2b0454cce67276605551eb47bc62997';
}
 

$ENV{OPENXPKI_CONF_DB} = $gitdb;

ok( -d $gitdb, "Test repo exists" );

use_ok('OpenXPKI::Config');

my $cfg = OpenXPKI::Config->new( );

ok( $cfg, 'create new config instance' );
is( $cfg->get_version(), $ver3, 'check version of HEAD' );

is( $cfg->get('some.test'), '43', "HEAD version of some.test" );
