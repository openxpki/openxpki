#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use Carp;
use English;
use Data::Dumper;
use File::Basename;
use File::Temp qw( tempdir );

# CPAN modules
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
use Test::More;
use Test::Deep;
use Math::BigInt;
use Data::UUID;

# Project modules
use lib qw(../../lib);
use TestCfg;
use OpenXPKI::Test::More;
use OpenXPKI::Test::CertHelper;
use OpenXPKI::Test::CertHelper::Database;

#
# Init client
#
our $cfg = {};
TestCfg->new->read_config_path( 'api.cfg', $cfg, dirname($0) );

my $test = OpenXPKI::Test::More->new({
    socketfile => $cfg->{instance}{socketfile},
    realm => $cfg->{instance}{realm},
}) or die "Error creating new test instance: $@";

$test->set_verbose($cfg->{instance}{verbose});
$test->plan( tests => 3 );

$test->connect_ok(
    user => $cfg->{operator}{name},
    password => $cfg->{operator}{password},
) or die "Error - connect failed: $@";

#
# Init helpers
#

# Import test certificates
my $dbdata = OpenXPKI::Test::CertHelper->via_database;

# By PROFILE
$test->runcmd_ok('search_cert_count', {
    PKI_REALM => $dbdata->cert("acme_root")->db->{pki_realm},
}, "Search and count certificates") or diag Dumper($test->get_msg);

is $test->get_msg->{PARAMS}, 3, "Correct number";

$dbdata->delete_all; # only deletes those from OpenXPKI::Test::CertHelper::Database
$test->disconnect;
