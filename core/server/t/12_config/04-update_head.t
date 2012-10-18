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

plan tests => 10;

my $tpath = dir($0)->parent;
my $gitdb = $tpath . '/01-initdb.git';
my ( $ver3, $ver4 );

if ( $tpath eq 't/12_config' ) {    
    $ver3 = '6f4174802f28e61ac23274f5adae0f3dcd681573';
    $ver4 = '2e2e70e1b98ef6076cce277759d6b08c53e8b3dd';
}
elsif ( $tpath eq '12_config' ) {    
    $ver3 = '931c7a4cf2b0454cce67276605551eb47bc62997';    
    $ver4 = '730bd546ba24ce018c3942805bf35c724cd25d7c';
}
 

$ENV{OPENXPKI_CONF_DB} = $gitdb;

ok( -d $gitdb, "Test repo exists" );

use_ok('OpenXPKI::Config');

my $cfg = OpenXPKI::Config->new( );

ok( $cfg, 'create new config instance' );


SKIP: {
    skip 'Please rerun 01-initdb (test ran before?)', 7 if ($cfg->get_version() ne $ver3);

    is( $cfg->get_version(), $ver3, 'check version of HEAD' );
     
    is( $cfg->get( 'some.test' ),
        '43', "current version of some.test" );
           
    # Update the git repo in background
    use_ok('OpenXPKI::Config::Merge');
    
    # Load the second config again on top
    $ENV{OPENXPKI_CONF_PATH} = dir($0)->parent . '/01-initdb-2.d';
    my $cfg_update = OpenXPKI::Config::Merge->new(
        {
            dbpath => $gitdb,                  
            commit_time => DateTime->from_epoch( epoch => 1347540098 ),
            author_name => 'Test User',
            author_mail => 'test@example.com',        
        }
    );
                 
    # Still the old data
    is( $cfg->get( 'some.test' ),
        '43', "current version of some.test" );
                 
    # Advance the head
    ok ($cfg->update_head());
    
    is( $cfg->get( 'some.test' ),
        '42', "current version of some.test" );
        
    is( $cfg->get_version(), $ver4, 'check version of HEAD' ); 
    
};   