## t/01-initdb.t
##
## Written 2011 by Scott Hardin for the OpenXPKI project
## Copyright (C) 2010, 2011 by Scott T. Hardin
##
## This script is used to populate a sample internal git repo
## for use by the other test scripts
##
## vim: syntax=perl

use Test::More tests => 9;

use strict;
use warnings;
use DateTime;
use Path::Class;

my $tpath = dir($0)->parent;
my $gitdb = $tpath . '/01-initdb.git';
my ( $ver1, $ver2, $ver3 );


# This condition allows for the test script to be called from either
# the trunk/perl-modules/core/trunk or trunk/perl-modules/core/trunk/t
# directory and still work correctly

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

my $commit_time = DateTime->from_epoch( epoch => 1240341682 );
my $author_name = 'Test User';
my $author_mail = 'test@example.com';

BEGIN {

    # Note: I could set these in new(), but I wanted to make sure
    # that using the ENV works correctly
    $ENV{OPENXPKI_CONF_DB}   = dir($0)->parent . '/01-initdb.git';
    $ENV{OPENXPKI_CONF_PATH} = dir($0)->parent . '/01-initdb.d';
}

dir($gitdb)->rmtree;    # yes, this is dangerous!!!!


use_ok('OpenXPKI::Config::Merge');

my $cfg = OpenXPKI::Config::Merge->new(
    {
        dbpath => $gitdb,
        autocreate => 1,                
        commit_time => $commit_time,
        author_name => $author_name,
        author_mail => $author_mail,
    }
);
ok( $cfg, 'create new config instance, which autocreates repo' );
is( $cfg->version, $ver1, 'check version (sha1 hash) of first commit' );

is( $cfg->get('system.database.user'),
    'openxpki', "check single attribute" );

$cfg->parser({
    path        => [ dir($0)->parent . '/01-initdb-2.d' ],
    commit_time => DateTime->from_epoch( epoch => 1240351682 ),
});
is( $cfg->version, $ver2, 'check version of second commit' );

$cfg->parser({
    path        => [ dir($0)->parent . '/01-initdb-3.d' ],
    commit_time => DateTime->from_epoch( epoch => 1240361682 ),
});
is( $cfg->version, $ver3, 'check version of third commit' );

# Try to get different versions of some values
is( $cfg->get('system.database.pass'),
    'newpassword', "newest version of system.database.pass" );
is( $cfg->get('system.database.pass', $ver1 ),
    'oldpassword', "oldest version of system.database.pass" );

# sort 'em just to be on the safe side
my @attrlist = sort( $cfg->listattr('system.database') );
is_deeply( \@attrlist, [ sort(qw( user pass )) ], "check attr list" );

