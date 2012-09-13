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
    $ver1 = '99e79dbe0e2d0560cd5ab3be93e56ecba1b709cc';
    $ver2 = '179c9b7b30306b44617483a2af6875013796a144';
    $ver3 = '64510ebec38db5581cb2f18001c9307d6595cf08';
}
elsif ( $tpath eq '12_config' ) {
    $ver1 = 'c52317a1beacaaec5b51b90dbf2e0006d5a614ff';
    $ver2 = 'a489ae574608006e97ba88932523d6b06f1e50b5';
    $ver3 = '3cb0ae44ae1422c9e5b189495ae228191bdd797c';
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

