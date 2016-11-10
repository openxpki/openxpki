#!/usr/bin/perl
#
# Check contents of a CRL:
# - create a certificate
# - revoke it
# - create new CRL
# - check if certificate serial is included in CRL

use strict;
use warnings;

use lib "../../lib";

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
use utf8;

my $dirname = dirname($0);

our @cfgpath = ( $dirname );
our %cfg = ();

my $testcfg = new TestCfg;
$testcfg->read_config_path( '9x_nice.cfg', \%cfg, @cfgpath );

my $test = OpenXPKI::Test::More->new(
    {
        socketfile => $cfg{instance}{socketfile},
        realm => $cfg{instance}{realm},
    }
) or die "Error creating new test instance: $@";

$test->set_verbose($cfg{instance}{verbose});

$test->plan( tests => 76 );

$test->connect_ok(
    user => $cfg{operator}{name},
    password => $cfg{operator}{password},
) or die "Error - connect failed: $@";

my $serializer = OpenXPKI::Serialization::Simple->new();

my %cert_info = (
    requestor_gname => "Andreas",
    requestor_name => "Anders",
    requestor_email => "andreas.anders\@mycompany.local",
);

my @cert_serials = ();
my %cert_subject_parts;

for my $certno (0..3) {
    #*******************************************************************************
    # Create certificate

    # Request certificate

    %cert_subject_parts = (
        # IP addresses instead of host names will make DNS lookups fail quicker
        hostname => "127.0.0.".(1+$certno*3),
        hostname2 => [ "127.0.0.".(2+$certno*3) , "127.0.0.".(3+$certno*3) ],
    	port => 8080,
    );

    $test->create_ok( 'certificate_signing_request_v2' , {
        cert_profile => $cfg{csr}{profile},
        cert_subject_style => "00_basic_style",
    }, 'Create workflow: certificate signing request (hostname: '.$cert_subject_parts{hostname}.')')
     or die "Workflow Create failed: $@";

    $test->state_is('SETUP_REQUEST_TYPE');
    $test->execute_ok( 'csr_provide_server_key_params', {
        key_alg => "rsa",
        enc_alg => 'aes256',
        key_gen_params => $serializer->serialize( { KEY_LENGTH => 2048 } ),
        password_type => 'client',
        csr_type => 'pkcs10'
    });

    $test->state_is('ENTER_KEY_PASSWORD');
    $test->execute_ok( 'csr_ask_client_password', {
        _password => "m4#bDf7m3abd",
    });

    $test->state_is('ENTER_SUBJECT');
    $test->execute_ok( 'csr_edit_subject', {
        cert_subject_parts => $serializer->serialize( \%cert_subject_parts )
    });

    $test->state_is('ENTER_SAN');
    $test->execute_ok( 'csr_edit_san', {
        cert_san_parts => $serializer->serialize( { } )
    });

    $test->state_is('ENTER_CERT_INFO');
    $test->execute_ok( 'csr_edit_cert_info', {
        cert_info => $serializer->serialize( \%cert_info )
    });

    $test->state_is('SUBJECT_COMPLETE');

    # As the nicetest FQDNs do not validate, we need a policy exception request
    $test->execute_ok( 'csr_enter_policy_violation_comment', { policy_comment => 'This is just a test' } );
    $test->state_is('PENDING_POLICY_VIOLATION');

    # Approve certificate request

    $test->execute_ok( 'csr_approve_csr' );
    $test->state_is('SUCCESS');

    my $cert_identifier = $test->param( 'cert_identifier' );

    # Fetch certificate info as hash
    $test->runcmd('get_cert', { IDENTIFIER => $cert_identifier, FORMAT => 'HASH' });

    push @cert_serials, $test->get_msg()->{PARAMS}->{BODY}->{SERIAL_HEX};

    #*******************************************************************************
    # Revoke certificate

    # First try an autoapproval request

    my $wfparam = {
    	cert_identifier => $cert_identifier,
    	reason_code => 'keyCompromise',
        comment => 'Automated Test',
        invalidity_time => time(),
        flag_auto_approval => 1,
        flag_delayed_revoke => 0,
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
my $data = $test->runcmd('get_crl', { FORMAT => 'HASH' });

# See if our certificate is included in the CRL
# (maybe along with other certificates from previous tests)
my $crl_certs = $data->get_msg()->{PARAMS}->{LIST};
my $matching_certs = 0;
for my $serial (@cert_serials) {
    $matching_certs += scalar grep { Math::BigInt->from_hex($_->{SERIAL}) eq Math::BigInt->from_hex($serial) } @$crl_certs;
}
$test->is($matching_certs, scalar @cert_serials, 'All revoked certificates included in CRL');

$test->disconnect;
