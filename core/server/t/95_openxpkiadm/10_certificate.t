#!/usr/bin/perl

#
# PLEASE KEEP this test in sync with qatest/backend/api/13_import_certificate.t
#

use strict;
use warnings;

# Core modules
use FindBin qw( $Bin );

# CPAN modules
use Test::More;

# Project modules
use lib "$Bin/../lib";
use lib "$Bin";
use OpenXPKI::Test;
use CommandlineTest;

plan tests => 11;

#
# Setup test context
#
my $oxitest = OpenXPKI::Test->new->setup_env;
my $dbdata = $oxitest->certhelper_database;

#
# Tests
#
cert_import_failsok($dbdata->cert("gamma_bob_1"), qr/I18N_OPENXPKI_SERVER_API_DEFAULT_IMPORT_CERTIFICATE_UNABLE_TO_FIND_ISSUER/);
cert_import_ok     ($dbdata->cert("gamma_bob_1"),    '--force-no-chain');

cert_import_ok     ($dbdata->cert("alpha_root_2"));
cert_import_failsok($dbdata->cert("alpha_root_2"), qr/I18N_OPENXPKI_SERVER_API_DEFAULT_IMPORT_CERTIFICATE_CERTIFICATE_ALREADY_EXISTS/);
cert_import_ok     ($dbdata->cert("alpha_root_2"),   '--force-certificate-already-exists');

cert_import_ok     ($dbdata->cert("alpha_signer_2"));
cert_import_ok     ($dbdata->cert("alpha_alice_2"),  '--revoked');

cert_import_ok     ($dbdata->cert("alpha_root_1"));
# Alpha gen 1 is expired, so we expect ...UNABLE_TO_BUILD_CHAIN
cert_import_failsok($dbdata->cert("alpha_signer_1"), qr/I18N_OPENXPKI_SERVER_API_DEFAULT_IMPORT_CERTIFICATE_UNABLE_TO_BUILD_CHAIN/);
my $issuer = $dbdata->cert("alpha_signer_1")->db->{issuer_identifier};
cert_import_ok     ($dbdata->cert("alpha_signer_1"), '--force-issuer', '--issuer', $issuer );
cert_import_ok     ($dbdata->cert("alpha_alice_1"),  '--force-no-verify');

# Cleanup database
$oxitest->delete_testcerts;
