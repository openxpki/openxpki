#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use Carp;
use English;
use Data::Dumper;
use File::Basename;
use FindBin qw( $Bin );

# CPAN modules
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
use Test::More;
use Test::Deep;

# Project modules
use lib "$Bin/../../lib";
use TestCfg;
use OpenXPKI::Test::More;
use OpenXPKI::Test::CertHelper;

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
$test->plan( tests => 5 );

$test->connect_ok(
    user => $cfg->{operator}{name},
    password => $cfg->{operator}{password},
) or die "Error - connect failed: $@";

#
# Tests
#

# Create test certificates
OpenXPKI::Test::CertHelper->via_workflow(
    tester => $test,
    hostname => "127.0.0.1",
    profile => "I18N_OPENXPKI_PROFILE_TLS_SERVER",
);
OpenXPKI::Test::CertHelper->via_workflow(
    tester => $test,
    hostname => "127.0.0.1",
    application_name => "Joust",
    profile => "I18N_OPENXPKI_PROFILE_TLS_CLIENT",
);

$test->runcmd_ok('list_used_profiles')
    or die Dumper($test->get_msg);

cmp_deeply $test->get_msg->{PARAMS}, superbagof(
    superhashof( { value => "I18N_OPENXPKI_PROFILE_TLS_SERVER" } ),
    superhashof( { value => "I18N_OPENXPKI_PROFILE_TLS_CLIENT" } ),
), "Show expected profiles";
