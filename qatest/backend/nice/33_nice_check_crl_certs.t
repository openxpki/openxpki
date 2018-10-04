#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;

# Project modules
use lib $Bin, "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;


# Check contents of a CRL:
# - create a certificate
# - revoke it
# - create new CRL
# - check if certificate serial is included in CRL
my $certs_to_create = 4;
plan tests => 3*$certs_to_create + 3;


#
# Init helpers
#
my $oxitest = OpenXPKI::Test->new(
    with => [qw( SampleConfig Workflows WorkflowCreateCert )],
    #log_level => 'debug',
);

my @cert_serials = ();
my $wf;

for my $certno (1..$certs_to_create) {
    # Create certificate
    my $cert_info = $oxitest->create_cert(
        hostname  => "127.0.0.".(1+$certno*3),
        hostname2 => [ "127.0.0.".(2+$certno*3) , "127.0.0.".(3+$certno*3) ],
        profile   => "I18N_OPENXPKI_PROFILE_TLS_SERVER",
    );

    # Fetch certificate info as hash
    my $cert_details = $oxitest->api_command('get_cert' => { IDENTIFIER => $cert_info->{identifier}, FORMAT => 'HASH' });

    push @cert_serials, $cert_details->{BODY}->{SERIAL_HEX};

    # Revoke certificate
    my $wfparam = {
        cert_identifier => $cert_info->{identifier},
    	reason_code => 'keyCompromise',
        comment => 'Automated Test',
        invalidity_time => time(),
        flag_auto_approval => 1,
        flag_batch_mode => 1,
    };

    lives_ok {
        $wf = $oxitest->create_workflow('certificate_revocation_request_v2' => $wfparam, 1)
    } 'Create workflow: auto-revoke certificate';

    # Go to pending
    $wf->state_is('CHECK_FOR_REVOCATION');
}

#*******************************************************************************
# Create new CRL
lives_ok {
    $wf = $oxitest->create_workflow('crl_issuance' => { force_issue => 1 }, 1)
} 'Create workflow: create CRL';

$wf->state_is('SUCCESS');

#*******************************************************************************
# Check CRL contents

# Fetch the most recent CRL
my $data = $oxitest->api_command('get_crl' => { FORMAT => 'FULLHASH' });

# See if our certificate is included in the CRL
# (maybe along with other certificates from previous tests)
my $crl_certs = $data->{LIST};
my $matching_certs = 0;
for my $serial (@cert_serials) {
    $matching_certs += scalar grep { Math::BigInt->from_hex($_->{SERIAL}) eq Math::BigInt->from_hex($serial) } @$crl_certs;
}
is $matching_certs, scalar @cert_serials, 'All revoked certificates included in CRL';
