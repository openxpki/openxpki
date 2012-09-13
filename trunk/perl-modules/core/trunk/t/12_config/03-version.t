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
    $ver1 = '99e79dbe0e2d0560cd5ab3be93e56ecba1b709cc';
    $ver2 = '179c9b7b30306b44617483a2af6875013796a144';
    $ver3 = '64510ebec38db5581cb2f18001c9307d6595cf08';
}
elsif ( $tpath eq '12_config' ) {
    $ver1 = 'c52317a1beacaaec5b51b90dbf2e0006d5a614ff';
    $ver2 = 'a489ae574608006e97ba88932523d6b06f1e50b5';
    $ver3 = '3cb0ae44ae1422c9e5b189495ae228191bdd797c';
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
