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


plan tests => 7;


#
# Init helpers
#
my $oxitest = OpenXPKI::Test->new(
    with => [qw( TestRealms CryptoLayer )],
#    log_level => 'debug',
);
my $dbdata = $oxitest->certhelper_database;

my @alpha_list = qw( alpha_alice_2  alpha_signer_2  alpha_root_2 );
my @beta_list =  qw( beta_alice_1   beta_signer_1   beta_root_1 );
my $alpha_pem = [ map { $dbdata->cert($_)->data }  @alpha_list ];
my $alpha_ids = [ map { $dbdata->cert($_)->subject_key_id }    @alpha_list ];
my $alpha_pem_string = join "\n", @$alpha_pem;
my $beta_pem = [ map { $dbdata->cert($_)->data } @beta_list ];
my $beta_ids = [ map { $dbdata->cert($_)->subject_key_id }   @beta_list ];
my $all_pem =  [ map { $dbdata->cert($_)->data }  @alpha_list, @beta_list ];
my $all_ids =  [ map { $dbdata->cert($_)->subject_key_id  }   @alpha_list, @beta_list ];

#
# Tests
#

# Array import: chain with unknown root cert (should fail)
lives_and {
    my $result = $oxitest->api2_command("import_chain" => { chain => $alpha_pem });
    like $result->{failed}->[0]->{error}, qr/issuer/;
} "Array import: chain with root cert should fail (unknown issuer)";

# Array import: chain with root cert (IMPORT_ROOT = 1)
lives_and {
    my $result = $oxitest->api2_command("import_chain" => { chain => $alpha_pem, import_root => 1 });
    cmp_deeply $result->{imported}, bag(
        map { superhashof({ subject_key_identifier => $_ }) } @$alpha_ids
    );
} "Array import: chain with root cert and IMPORT_ROOT = 1";

# Array import: Same chain again (should recognize existing certs)
lives_and {
    my $result = $oxitest->api2_command("import_chain" => { chain => $alpha_pem, import_root => 1 });
    cmp_deeply $result->{existed}, bag(
        map { superhashof({ subject_key_identifier => $_ }) } @$alpha_ids
    );
} "Array import: same chain again should fail";


$oxitest->delete_testcerts;

# Array import: partly existing chain
$oxitest->insert_testcerts(only => [ "beta_root_1" ]);
lives_and {
    my $result = $oxitest->api2_command("import_chain" => { chain => $beta_pem, import_root => 1 });
    cmp_deeply $result, superhashof({
        existed =>  bag( map { superhashof({ subject_key_identifier => $_ }) } $dbdata->cert("beta_root_1")->subject_key_id),
        imported => bag( map { superhashof({ subject_key_identifier => $_ }) } ($dbdata->cert("beta_signer_1")->subject_key_id, $dbdata->cert("beta_alice_1")->subject_key_id) ),
    });
} "Array import: chain whose root cert is already in PKI";

$oxitest->delete_testcerts;

# Array import: two chains
lives_and {
    my $result = $oxitest->api2_command("import_chain" => { chain => $all_pem, import_root => 1 });
    cmp_deeply $result->{imported}, bag(
        map { superhashof({ subject_key_identifier => $_ }) } @$all_ids
    );
} "Array import: two chains";

$oxitest->delete_testcerts;

# PEM block import: Chain with root cert (IMPORT_ROOT = 1)
lives_and {
    my $result = $oxitest->api2_command("import_chain" => { chain => $alpha_pem_string, import_root => 1 });
    cmp_deeply $result->{imported}, bag(
        map { superhashof({ subject_key_identifier => $_ }) } @$alpha_ids
    );
} "String import: chain with root cert and IMPORT_ROOT = 1";

$oxitest->delete_testcerts;

# PKCS7 import
lives_and {
    my $result = $oxitest->api2_command("import_chain" => { pkcs7 => $dbdata->pkcs7->{'beta-alice-1'}, import_root => 1 });
    cmp_deeply $result->{imported}, bag(
        map { superhashof({ subject_key_identifier => $_ }) } @$beta_ids
    );
} "PKCS7 import: chain with root cert (IMPORT_ROOT = 1)";

$oxitest->delete_testcerts;
