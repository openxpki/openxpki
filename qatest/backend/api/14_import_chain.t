#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use Carp;
use English;
use Data::Dumper;
use File::Basename qw( dirname );
use FindBin qw( $Bin );

# CPAN modules
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
use Test::More;
use Test::Deep;

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
$test->plan( tests => 18 );

$test->connect_ok(
    user => $cfg->{operator}{name},
    password => $cfg->{operator}{password},
) or die "Error - connect failed: $@";

#
# Init helpers
#
my $oxitest = OpenXPKI::Test->new;
my $dbdata = $oxitest->certhelper_database;
$dbdata->cert_names_by_realm_gen(alpha => 1);
my @alpha_list = qw( alpha_alice_2  alpha_signer_2  alpha_root_2 );
my @beta_list =  qw( beta_alice_1   beta_signer_1   beta_root_1 );
my $alpha_pem = [ map { $dbdata->cert($_)->data }  @alpha_list ];
my $alpha_ids = [ map { $dbdata->cert($_)->id }    @alpha_list ];
my $alpha_pem_string = join "\n", @$alpha_pem;
my $beta_pem = [ map { $dbdata->cert($_)->data } @beta_list ];
my $beta_ids = [ map { $dbdata->cert($_)->id }   @beta_list ];
my $all_pem =  [ map { $dbdata->cert($_)->data }  @alpha_list, @beta_list ];
my $all_ids =  [ map { $dbdata->cert($_)->id  }   @alpha_list, @beta_list ];


# Array import: Try chain with root cert (should fail)
$test->runcmd_ok('import_chain', { DATA => $alpha_pem }, "Array import: chain with root cert");
like $test->get_msg->{PARAMS}->{failed}->[0]->{error},
    qr/I18N_OPENXPKI_SERVER_API_DEFAULT_IMPORT_CERTIFICATE_UNABLE_TO_FIND_ISSUER/,
    "Return error message";
is scalar @{ $test->get_msg->{PARAMS}->{imported} }, 0, "No certs should have been imported";

# Array import: Chain with root cert (IMPORT_ROOT = 1)
$test->runcmd_ok('import_chain', { DATA => $alpha_pem, IMPORT_ROOT => 1 }, "Array import: chain with root cert (IMPORT_ROOT = 1)");
cmp_bag $test->get_msg->{PARAMS}->{imported}, [
    map { superhashof({ SUBJECT_KEY_IDENTIFIER => $_ }) } @$alpha_ids
], "List imported certs";

# Array import: Same chain again (should recognize existing certs)
$test->runcmd_ok('import_chain', { DATA => $alpha_pem, IMPORT_ROOT => 1 }, "Array import: same chain again");
cmp_bag $test->get_msg->{PARAMS}->{existed}, [
    map { superhashof({ SUBJECT_KEY_IDENTIFIER => $_ }) } @$alpha_ids
], "List certs as already existing";
is scalar @{ $test->get_msg->{PARAMS}->{imported} }, 0, "No certs should have been imported";

$oxitest->delete_testcerts;

# Array import: partly existing chain
$test->runcmd_ok('import_chain', { DATA => $dbdata->cert("beta_root_1")->data, IMPORT_ROOT => 1 }, "Prepare next test by importing root certificate");
$test->runcmd_ok('import_chain', { DATA => $beta_pem, IMPORT_ROOT => 1 }, "Array import: chain whose root cert is already in PKI");
cmp_deeply $test->get_msg->{PARAMS},
    superhashof({
        existed =>  bag( map { superhashof({ SUBJECT_KEY_IDENTIFIER => $_ }) } $dbdata->cert("beta_root_1")->id),
        imported => bag( map { superhashof({ SUBJECT_KEY_IDENTIFIER => $_ }) } ($dbdata->cert("beta_signer_1")->id, $dbdata->cert("beta_alice_1")->id) ),
    }),
    "List certs as imported and existing";

$oxitest->delete_testcerts;

# Array import: two chains
$test->runcmd_ok('import_chain', { DATA => $all_pem, IMPORT_ROOT => 1 }, "Array import: two chains");
cmp_bag $test->get_msg->{PARAMS}->{imported}, [
    map { superhashof({ SUBJECT_KEY_IDENTIFIER => $_ }) } @$all_ids
], "List imported certs";

$oxitest->delete_testcerts;

# PEM block import: Chain with root cert (IMPORT_ROOT = 1)
$test->runcmd_ok('import_chain', { DATA => $alpha_pem_string, IMPORT_ROOT => 1 }, "String import: chain with root cert (IMPORT_ROOT = 1)");
cmp_bag $test->get_msg->{PARAMS}->{imported}, [
    map { superhashof({ SUBJECT_KEY_IDENTIFIER => $_ }) } @$alpha_ids
], "List imported certs";

$oxitest->delete_testcerts;

# PKCS7 import
$test->runcmd_ok('import_chain', { DATA => $dbdata->pkcs7->{'beta-alice-1'}, IMPORT_ROOT => 1 }, "PKCS7 import: chain with root cert (IMPORT_ROOT = 1)");
cmp_bag $test->get_msg->{PARAMS}->{imported}, [
    map { superhashof({ SUBJECT_KEY_IDENTIFIER => $_ }) } @$beta_ids
], "List imported certs";

$oxitest->delete_testcerts;

$test->disconnect;
