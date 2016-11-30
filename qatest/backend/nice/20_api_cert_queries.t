#!/usr/bin/perl
#
# 045_activity_tools.t
#
# Tests misc workflow tools like WFObject, etc.
#
# Note: these tests are non-destructive. They create their own instance
# of the tools workflow, which is exclusively for such test purposes.

use strict;
use warnings;

use lib qw(../../lib);

use Carp;
use English;
use Data::Dumper;
use Config::Std;
use File::Basename;
use File::Temp qw( tempfile );

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);

use OpenXPKI::Test::More;
use Test::More;
use TestCfg;
use utf8;

our %cfg = ();
my $testcfg = new TestCfg;
$testcfg->read_config_path( '9x_nice.cfg', \%cfg, dirname($0) );

#
# Fetch ID of certificate created by 10_nice_signing_request.t
#
BAIL_OUT "Test data file not found. Run 10_nice_signing_request.t first."
    unless -f $cfg{instance}{buffer};
my $buffer = do { local $/; open my $HANDLE, '<', $cfg{instance}{buffer}; <$HANDLE> }; # slurp
my $input_data = OpenXPKI::Serialization::Simple->new->deserialize($buffer);
my $cert_id = $input_data->{'cert_identifier'};

#
# Init
#
my $test = OpenXPKI::Test::More->new({
    socketfile => $cfg{instance}{socketfile},
    realm      => $cfg{instance}{realm},
}) or die "Error creating new test instance: $@";
$test->set_verbose($cfg{instance}{verbose});

$test->plan( tests => 3 );

$test->connect_ok(user => $cfg{user}{name}, password => $cfg{user}{password})
    or die "Error - connect failed: $@";

#
# Tests
#

# Fetch certificate profile
$test->runcmd_ok('get_profile_for_cert', { IDENTIFIER => $cert_id }, "Get profile for certificate");
$test->is($test->get_msg()->{PARAMS}, $cfg{csr}{profile}, "Certificate profile match");

$test->disconnect();
