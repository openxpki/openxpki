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
);
my $dbdata = $oxitest->certhelper_database;

my @alpha_list = qw( alpha-alice-2  alpha-signer-2  alpha-root-2 );
my @beta_list =  qw( beta-alice-1   beta-signer-1   beta-root-1 );
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
    my $result = $oxitest->api_command("import_chain" => { DATA => $alpha_pem });
    is $result->{failed}->[0]->{error}, "I18N_OPENXPKI_SERVER_API_DEFAULT_IMPORT_CERTIFICATE_UNABLE_TO_FIND_ISSUER";
} "Array import: chain with root cert should fail (unknown issuer)";

# Array import: chain with root cert (IMPORT_ROOT = 1)
lives_and {
    my $result = $oxitest->api_command("import_chain" => { DATA => $alpha_pem, IMPORT_ROOT => 1 });
    cmp_bag $result->{imported}, [
        map { superhashof({ SUBJECT_KEY_IDENTIFIER => $_ }) } @$alpha_ids
    ];
} "Array import: chain with root cert and IMPORT_ROOT = 1";

# Array import: Same chain again (should recognize existing certs)
lives_and {
    my $result = $oxitest->api_command("import_chain" => { DATA => $alpha_pem, IMPORT_ROOT => 1 });
    cmp_bag $result->{existed}, [
        map { superhashof({ SUBJECT_KEY_IDENTIFIER => $_ }) } @$alpha_ids
    ];
} "Array import: same chain again should fail";


$oxitest->delete_testcerts;

# Array import: partly existing chain
$oxitest->insert_testcerts(only => [ "beta-root-1" ]);
lives_and {
    my $result = $oxitest->api_command("import_chain" => { DATA => $beta_pem, IMPORT_ROOT => 1 });
    cmp_deeply $result, superhashof({
        existed =>  bag( map { superhashof({ SUBJECT_KEY_IDENTIFIER => $_ }) } $dbdata->cert("beta-root-1")->subject_key_id),
        imported => bag( map { superhashof({ SUBJECT_KEY_IDENTIFIER => $_ }) } ($dbdata->cert("beta-signer-1")->subject_key_id, $dbdata->cert("beta-alice-1")->subject_key_id) ),
    });
} "Array import: chain whose root cert is already in PKI";

$oxitest->delete_testcerts;

# Array import: two chains
lives_and {
    my $result = $oxitest->api_command("import_chain" => { DATA => $all_pem, IMPORT_ROOT => 1 });
    cmp_deeply $result->{imported}, bag(
        map { superhashof({ SUBJECT_KEY_IDENTIFIER => $_ }) } @$all_ids
    );
} "Array import: two chains";

$oxitest->delete_testcerts;

# PEM block import: Chain with root cert (IMPORT_ROOT = 1)
lives_and {
    my $result = $oxitest->api_command("import_chain" => { DATA => $alpha_pem_string, IMPORT_ROOT => 1 });
    cmp_bag $result->{imported}, [
        map { superhashof({ SUBJECT_KEY_IDENTIFIER => $_ }) } @$alpha_ids
    ];
} "String import: chain with root cert and IMPORT_ROOT = 1";

$oxitest->delete_testcerts;

# PKCS7 import
lives_and {
    my $result = $oxitest->api_command("import_chain" => { DATA => $dbdata->pkcs7->{'beta-alice-1'}, IMPORT_ROOT => 1 });
    cmp_bag $result->{imported}, [
        map { superhashof({ SUBJECT_KEY_IDENTIFIER => $_ }) } @$beta_ids
    ];
} "PKCS7 import: chain with root cert (IMPORT_ROOT = 1)";

$oxitest->delete_testcerts;
