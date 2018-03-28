#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );
use File::Temp qw( tempfile );

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;

# Project modules
use lib $Bin, "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;


plan tests => 9;


#
# Init helpers
#
my $oxitest = OpenXPKI::Test->new(
    with => [qw( TestRealms CryptoLayer )],
);
$oxitest->insert_testcerts;
my $dbdata = $oxitest->certhelper_database;

# Fetch chain - HASH Format
my $result;
lives_ok {
    $result = $oxitest->api2_command("get_chain" => { start_with => $dbdata->cert("alpha_alice_2")->id, format => 'DBINFO' });
} "Fetch certificate chain (as HashRef)";

is scalar @{$result->{certificates}}, 3, "Chain contains 3 certificates";

is $result->{certificates}->[0]->{identifier},
    $dbdata->cert("alpha_alice_2")->id,
    "First cert in chain equals requested start cert";

is $result->{certificates}->[0]->{authority_key_identifier},
    $result->{certificates}->[1]->{subject_key_identifier},
    "Server cert was signed by CA cert";

is $result->{certificates}->[1]->{authority_key_identifier},
    $result->{certificates}->[2]->{subject_key_identifier},
    "CA cert was signed by Root cert";

#
# PEM format (default)
#
lives_and {
    my $result = $oxitest->api2_command("get_chain" => {
        start_with => $dbdata->cert("alpha_alice_2")->id,
        format => 'PEM',
    });
    cmp_deeply $result, superhashof({
        certificates => [
            map { $dbdata->cert($_)->data } qw( alpha_alice_2 alpha_signer_2 alpha_root_2 )
        ],
    });
} "Fetch certificate chain (PEM)";

#
# DER format
#
my $alice  = $dbdata->cert("alpha_alice_2")->data;
my $signer = $dbdata->cert("alpha_signer_2")->data;
my $root   = $dbdata->cert("alpha_root_2")->data;

lives_and {
    my $result = $oxitest->api2_command("get_chain" => {
        start_with => $dbdata->cert("alpha_alice_2")->id,
        format => "DER",
    });
    my ($tmp, $tmp_name) = tempfile(UNLINK => 1);
    print $tmp $result->{certificates}->[0] and close $tmp;
    my $info = `OPENSSL_CONF=/dev/null openssl x509 -in $tmp_name -inform DER -outform PEM`;
    like $info, qr{ \Q$alice\E }msx;
} "Fetch certificate chain (DER)";

#
# PKCS7 bundle
#
lives_and {
    my $result = $oxitest->api2_command("get_chain" => {
        start_with => $dbdata->cert("alpha_alice_2")->id,
        bundle => 1,
    });
    my ($tmp, $tmp_name) = tempfile(UNLINK => 1);
    print $tmp $result and close $tmp;
    my $info = `OPENSSL_CONF=/dev/null openssl pkcs7 -in $tmp_name -print_certs`;
    like $info, qr{ \Q$alice\E .* \Q$signer\E }msx;
} "Fetch certificate chain (BUNDLE)";

lives_and {
    my $result = $oxitest->api2_command("get_chain" => {
        start_with => $dbdata->cert("alpha_alice_2")->id,
        bundle => 1,
        keeproot => 1,
    });
    my ($tmp, $tmp_name) = tempfile(UNLINK => 1);
    print $tmp $result and close $tmp;
    my $info = `OPENSSL_CONF=/dev/null openssl pkcs7 -in $tmp_name -print_certs`;
    like $info, qr{ \Q$alice\E .* \Q$signer\E .* \Q$root\E }msx;
} "Fetch certificate chain (BUNDLE and KEEPROOT)";

$oxitest->delete_testcerts;
