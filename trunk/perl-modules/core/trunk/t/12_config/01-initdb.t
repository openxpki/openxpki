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
    $ver1 = 'a61e655b17c9d01c08a913c675655fc80c82a130';
    $ver2 = 'ccee79ed78a8a37d25b3e8ae2daf9ef7862f4072';
    $ver3 = '2602da9a04e1d47de6c3ddd2bf4fb3eb2fa8cbc9';
}
elsif ( $tpath eq '12_config' ) {
    $ver1 = 'b3a8fcb82e9f30aa0294e9b0f5ae470532bd4cd4';
    $ver2 = 'ee824d168e7cb8f9ac4a80a9f9d03b14a7ba208d';
    $ver3 = '3eed3adfd6c3c97e85a37202e799a19ec71d6626';
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

use_ok('OpenXPKI::Config');

my $cfg = OpenXPKI::Config->new(
    {
        commit_time => $commit_time,
        author_name => $author_name,
        author_mail => $author_mail,
    }
);
ok( $cfg, 'create new config instance, which autocreates repo' );
is( $cfg->version, $ver1, 'check version (sha1 hash) of first commit' );

is( $cfg->get('group1.ldap1.uri'),
    'ldaps://example1.org', "check single attribute" );

$cfg->_import_cfg(
    path        => [ dir($0)->parent . '/01-initdb-2.d' ],
    commit_time => DateTime->from_epoch( epoch => 1240351682 ),
);
is( $cfg->version, $ver2, 'check version of second commit' );

$cfg->_import_cfg(
    path        => [ dir($0)->parent . '/01-initdb-3.d' ],
    commit_time => DateTime->from_epoch( epoch => 1240361682 ),
);
is( $cfg->version, $ver3, 'check version of third commit' );

# Try to get different versions of some values
is( $cfg->get('group2.ldap2.user'),
    'openxpkiA', "newest version of group2.ldap2.user" );
is( $cfg->get( 'group2.ldap2.user', $ver1 ),
    'openxpki2', "oldest version of group2.ldap2.user" );

# sort 'em just to be on the safe side
my @attrlist = sort( $cfg->listattr('group1.ldap1') );
is_deeply( \@attrlist, [ sort(qw( uri user password )) ], "check attr list" );

