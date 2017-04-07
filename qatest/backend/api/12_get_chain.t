#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw( $Bin );
use lib "$Bin/../../lib";

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
use Test::Deep;
use TestCfg;
use OpenXPKI::Test::CertHelper;

our %cfg = ();
my $testcfg = new TestCfg;
$testcfg->read_config_path( 'api.cfg', \%cfg, dirname($0) );

my $test = OpenXPKI::Test::More->new({
    socketfile => $cfg{instance}{socketfile},
    realm => $cfg{instance}{realm},
}) or die "Error creating new test instance: $@";

$test->set_verbose($cfg{instance}{verbose});
$test->plan( tests => 7 );

$test->connect_ok(
    user => $cfg{operator}{name},
    password => $cfg{operator}{password},
) or die "Error - connect failed: $@";

# Create certificate
my $cert_info = OpenXPKI::Test::CertHelper->via_workflow(
    tester => $test,
    hostname => "127.0.0.1",
);

# Fetch certificate - HASH Format
$test->runcmd_ok('get_chain', { START_IDENTIFIER => $cert_info->{identifier}, OUTFORMAT => 'HASH' }, "Fetch certificate chain");
my $params = $test->get_msg()->{PARAMS};

$test->is(scalar @{$params->{CERTIFICATES}}, 3, "Chain contains 3 certificates");

$test->is(
    $params->{CERTIFICATES}->[0]->{IDENTIFIER},
    $cert_info->{identifier},
    "First cert in chain equals requested start cert"
);

$test->is(
    $params->{CERTIFICATES}->[0]->{AUTHORITY_KEY_IDENTIFIER},
    $params->{CERTIFICATES}->[1]->{SUBJECT_KEY_IDENTIFIER},
    "Server cert was signed by CA cert"
);

$test->is(
    $params->{CERTIFICATES}->[1]->{AUTHORITY_KEY_IDENTIFIER},
    $params->{CERTIFICATES}->[2]->{SUBJECT_KEY_IDENTIFIER},
    "CA cert was signed by Root cert"
);

# TODO Test get_chain with BUNDLE => 1

# OUTFORMAT, which can be either 'PEM', 'DER' or 'HASH' (full db result).
# Result:
#    IDENTIFIERS   the chain of certificate identifiers as an array
#    SUBJECT       list of subjects for the returned certificates
#    CERTIFICATES  the certificates as an array of data in outformat
#                  (if requested)
#    COMPLETE      1 if the complete chain was found in the database
#                  0 otherwise
#
# By setting "BUNDLE => 1" you will not get a hash but a PKCS7 encoded bundle
# holding the requested certificate and all intermediates (if found). Add
# "KEEPROOT => 1" to also have the root in PKCS7 container.

$test->disconnect;
