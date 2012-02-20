# t/12_config/02-readonly.t
#
# vim: syntax=perl

use Test::More tests => 3;

use strict;
use warnings;
use DateTime;
use Path::Class;

my $tpath = dir($0)->parent;
my $gitdb = $tpath . '/01-initdb.git';
my ( $ver1, $ver2, $ver3 );

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

if ( not -d $gitdb ) {
    die "Test repo not found - did you run 01-initdb.t already?";
}

$ENV{OPENXPKI_CONF_DB} = $gitdb;

#$ENV{OPENXPKI_CONF_PATH}     = dir($0)->parent . '/01-initdb.d';

use_ok('OpenXPKI::Config');

# Setting 'path' to an empty list should force the config subsystem to not try to
# import any config
my $cfg = OpenXPKI::Config->new( { path => [] } );

ok( $cfg, 'create new config instance' );
is( $cfg->version, $ver3, 'check version of HEAD' );
