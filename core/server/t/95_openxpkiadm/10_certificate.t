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

plan tests => 21;

#
# Setup test context
#
my $oxitest = OpenXPKI::Test->new->setup_env;
my $dbdata = $oxitest->certhelper_database;

#
# Tests for IMPORT
#
cert_import_failsok($dbdata->cert("gamma_bob_1"), qr/I18N_OPENXPKI_SERVER_API_DEFAULT_IMPORT_CERTIFICATE_UNABLE_TO_FIND_ISSUER/);
cert_import_ok     ($dbdata->cert("gamma_bob_1"),    '--force-no-chain');

cert_import_ok     ($dbdata->cert("alpha_root_2"),      qw(--realm alpha));
cert_import_failsok($dbdata->cert("alpha_root_2"), qr/I18N_OPENXPKI_SERVER_API_DEFAULT_IMPORT_CERTIFICATE_CERTIFICATE_ALREADY_EXISTS/);
cert_import_ok     ($dbdata->cert("alpha_root_2"),      qw(--realm alpha), '--force-certificate-already-exists');

cert_import_ok     ($dbdata->cert("alpha_signer_2"),    qw(--realm alpha), '--group' => 'alpha-signer', '--gen' => 2);
cert_import_ok     ($dbdata->cert("alpha_datavault_2"), qw(--realm alpha), '--token' => 'datasafe',     '--gen' => 2);
cert_import_ok     ($dbdata->cert("alpha_scep_2"),      qw(--realm alpha), '--token' => 'scep',         '--gen' => 2);
cert_import_ok     ($dbdata->cert("alpha_alice_2"),     qw(--realm alpha --revoked --alias MelaleucaAlternifolia));

cert_import_ok     ($dbdata->cert("alpha_root_1"),      qw(--realm alpha));
# Alpha gen 1 is expired, so we expect ...UNABLE_TO_BUILD_CHAIN
cert_import_failsok($dbdata->cert("alpha_signer_1"), qr/I18N_OPENXPKI_SERVER_API_DEFAULT_IMPORT_CERTIFICATE_UNABLE_TO_BUILD_CHAIN/);
my $issuer = $dbdata->cert("alpha_signer_1")->db->{issuer_identifier};
cert_import_ok     ($dbdata->cert("alpha_signer_1"),    qw(--realm alpha), '--force-issuer', '--issuer', $issuer );
cert_import_ok     ($dbdata->cert("alpha_alice_1"),     qw(--realm alpha), '--force-no-verify');

my @ids = map { $dbdata->cert($_)->db->{identifier} }
    qw(
        alpha_root_1 alpha_signer_1 alpha_alice_1
        alpha_root_2 alpha_signer_2 alpha_datavault_2 alpha_scep_2 alpha_alice_2
    );
my $a_alice_2_id    = $dbdata->cert("alpha_alice_2")->db->{identifier};
my $a_signer_2_id   = $dbdata->cert("alpha_signer_2")->db->{identifier};
my $a_root_2_id     = $dbdata->cert("alpha_root_2")->db->{identifier};

#
# Tests for LIST
#
cert_list_failsok  qr/realm/i;

# Show certificates with aliases
cert_list_ok
    qr/ \Q$a_alice_2_id\E ((?!identifier).)* MelaleucaAlternifolia /msxi,
    qw(--realm alpha);

# show all certificates of realm
cert_list_ok
    [
        @ids,
        qr/ \Q$a_alice_2_id\E \W+ revoked ((?!identifier).)* MelaleucaAlternifolia /msxi,
    ],
    qw(--realm alpha --all);

# verbose
my @verbose1 = (
    $dbdata->cert("alpha_alice_2")->db->{identifier},
    "MelaleucaAlternifolia", # alias
    $dbdata->cert("alpha_alice_2")->db->{subject},
    $dbdata->cert("alpha_alice_2")->db->{issuer_dn},
);
my @verbose2 = (
    @verbose1,
    qr/ $a_alice_2_id ((?!\n).)* $a_signer_2_id ((?!\n).)* .* $a_root_2_id /msxi # chain
);
my @verbose3 = (
    @verbose2,
    $dbdata->cert("alpha_alice_2")->db->{subject_key_identifier},
    $dbdata->cert("alpha_alice_2")->db->{authority_key_identifier},
    $dbdata->cert("alpha_alice_2")->db->{issuer_identifier},
    qr/ revoked /msxi,
    $dbdata->cert("alpha_alice_2")->db->{notbefore},
    $dbdata->cert("alpha_alice_2")->db->{notafter},
);
my @verbose4 = (
    @verbose3,
    '-----BEGIN CERTIFICATE-----',
);

cert_list_ok \@verbose1, qw(--realm alpha -v);
cert_list_ok \@verbose2, qw(--realm alpha -v -v);
cert_list_ok \@verbose3, qw(--realm alpha -v -v -v);
cert_list_ok \@verbose4, qw(--realm alpha -v -v -v -v);

#
# Test KEY LIST
#
openxpkiadm_test
    [ 'key', 'list' ],
    [ '--realm' => 'alpha' ],
    1,
    [qw( alpha-signer-2 alpha-datavault-2 alpha-scep-2 )],
    'list keys';

#
# Test CHAIN
#

# There is a bug that does not allow parameter --realm
#openxpkiadm_test
#    [ 'certificate', 'chain' ],
#    [ '--realm' => 'alpha', '--name' => $a_alice_2_id, '--issuer' => $a_root_2_id ],
#    1,
#    qr/jens/,
#    'change certificate chain';

# Cleanup database
$oxitest->delete_testcerts;
