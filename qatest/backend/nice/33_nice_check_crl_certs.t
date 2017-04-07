#!/usr/bin/perl
#
# Check contents of a CRL:
# - create a certificate
# - revoke it
# - create new CRL
# - check if certificate serial is included in CRL

use strict;
use warnings;

use FindBin qw( $Bin );
use lib "$Bin/../../lib";

use Carp;
use English;
use Data::Dumper;
use Config::Std;
use File::Basename;
use Math::BigInt;

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);

use OpenXPKI::Test::More;
use TestCfg;
use OpenXPKI::Test::CertHelper;
use utf8;

my $dirname = dirname($0);

our @cfgpath = ( $dirname );
our %cfg = ();
my $certs_to_create = 4;

my $testcfg = new TestCfg;
$testcfg->read_config_path( '9x_nice.cfg', \%cfg, @cfgpath );

my $test = OpenXPKI::Test::More->new( {
    socketfile => $cfg{instance}{socketfile},
    realm => $cfg{instance}{realm},
} ) or die "Error creating new test instance: $@";

$test->set_verbose($cfg{instance}{verbose});
$test->plan( tests => 4 + $certs_to_create * 3 );

$test->connect_ok(
    user => $cfg{operator}{name},
    password => $cfg{operator}{password},
) or die "Error - connect failed: $@";

my @cert_serials = ();

for my $certno (1..$certs_to_create) {
    # Create certificate
    my $cert_info = OpenXPKI::Test::CertHelper->via_workflow(
        tester          => $test,
        hostname        => "127.0.0.".(1+$certno*3),
        hostname2       => [ "127.0.0.".(2+$certno*3) , "127.0.0.".(3+$certno*3) ],
        profile         => $cfg{csr}{profile},
    );

    # Fetch certificate info as hash
    $test->runcmd('get_cert', { IDENTIFIER => $cert_info->{identifier}, FORMAT => 'HASH' });

    push @cert_serials, $test->get_msg()->{PARAMS}->{BODY}->{SERIAL_HEX};

    # Revoke certificate
    my $wfparam = {
        cert_identifier => $cert_info->{identifier},
    	reason_code => 'keyCompromise',
        comment => 'Automated Test',
        invalidity_time => time(),
        flag_auto_approval => 1,
        flag_batch_mode => 1,
    };

    $test->create_ok( 'certificate_revocation_request_v2' , $wfparam, 'Create workflow: auto-revoke certificate')
        or die "Workflow Create failed: $@";

    # Go to pending
    $test->state_is('CHECK_FOR_REVOCATION');
}

#*******************************************************************************
# Create new CRL

$test->create_ok( 'crl_issuance' , { force_issue => 1 }, 'Create workflow: create CRL')
    or die "Workflow Create failed: $@";

$test->state_is('SUCCESS');

#*******************************************************************************
# Check CRL contents

# Fetch the most recent CRL
my $data = $test->runcmd('get_crl', { FORMAT => 'FULLHASH' });

# See if our certificate is included in the CRL
# (maybe along with other certificates from previous tests)
my $crl_certs = $data->get_msg()->{PARAMS}->{LIST};
my $matching_certs = 0;
for my $serial (@cert_serials) {
    $matching_certs += scalar grep { Math::BigInt->from_hex($_->{SERIAL}) eq Math::BigInt->from_hex($serial) } @$crl_certs;
}
$test->is($matching_certs, scalar @cert_serials, 'All revoked certificates included in CRL');

$test->disconnect;
