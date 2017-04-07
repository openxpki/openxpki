#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use Carp;
use English;
use Data::Dumper;
use File::Basename qw( dirname );
use File::Temp qw( tempdir );
use FindBin qw( $Bin );

# CPAN modules
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
use Test::More;
use Test::Deep;
use Math::BigInt;
use Data::UUID;

# Project modules
use lib "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use TestCfg;
use OpenXPKI::Test::More;
use OpenXPKI::Test;

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
my $oxitest = OpenXPKI::Test->new;
my $dbdata = $oxitest->certhelper_database;
$oxitest->insert_testcerts;

# By PROFILE
my $realm = $dbdata->cert("beta_root_1")->db->{pki_realm};
$test->runcmd_ok('search_cert_count', {
    PKI_REALM => $dbdata->cert("beta_root_1")->db->{pki_realm},
}, "Search and count certificates") or diag Dumper($test->get_msg);

is $test->get_msg->{PARAMS}, scalar($dbdata->cert_names_where(pki_realm => $realm)), "Correct number";

$oxitest->delete_testcerts; # only deletes those from OpenXPKI::Test::CertHelper::Database
$test->disconnect;
