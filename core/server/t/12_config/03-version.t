# t/12_config/02-readonly.t
#
# vim: syntax=perl

use strict;
use warnings;
use DateTime;
use Path::Class;
use Test::More; 
use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init($FATAL);

my $session;
eval {
    use OpenXPKI::Server::Context qw( CTX );
    $session = CTX('session');
};
plan skip_all => "OpenXPKI::Server::Session::Mock required" if ($@ || !$session);

plan tests => 9;

my $tpath = dir($0)->parent;
my $gitdb = $tpath . '/01-initdb.git';
my ( $ver1, $ver2, $ver3 );

if ( $tpath eq 't/12_config' ) {
    $ver1 = 'c1a902266a0cd399f165ad5db95886a2c06c7283';
    $ver2 = 'ae46bf124020dc5c9e7769c1b43669c5b3d6280b';
    $ver3 = '6f4174802f28e61ac23274f5adae0f3dcd681573';
}
elsif ( $tpath eq '12_config' ) {
    $ver1 = '38a933ee946889eb8ac3b5e19e34894e463fedd2';
    $ver2 = '2cae7e512aef64f7618b9ba1ce87d592a179f8a7';
    $ver3 = '931c7a4cf2b0454cce67276605551eb47bc62997';
}
 

$ENV{OPENXPKI_CONF_DB} = $gitdb;

ok( -d $gitdb, "Test repo exists" );

use_ok('OpenXPKI::Config');

my $cfg = OpenXPKI::Config->new( );

ok( $cfg, 'create new config instance' );
is( $cfg->get_version(), $ver3, 'check version of HEAD' );

# Test the system namespace
is( $cfg->get('system.database.pass'),
    'newpassword', "current version of password" );

# Test realm namespace (realm is prefix in the config layer)
is( $cfg->get( 'some.test' ),
    '43', "current version of some.test" );
      
# Rewind to first version  
$session->set_config_version($ver1);

# We need to read first to have the head version set
is( $cfg->get( 'some.test' ),
    '42', "oldest version of some.test" );

is( $cfg->get_version(), $ver1, 'check version of HEAD' );

# System namespace is not versioned     
is( $cfg->get('system.database.pass'),
    'newpassword', "current version of password" );
