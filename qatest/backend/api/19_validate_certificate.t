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
    with => qw( CryptoLayer ),
);
my $dbdata = $oxitest->certhelper_database;
$oxitest->insert_testcerts(exclude => ['alpha_root_2']);

#
# single certificate (PEM)
#

# missing root certificate
lives_and {
    my $result = $oxitest->api_command("validate_certificate" => {
        PEM => $dbdata->cert("alpha_alice_2")->data,
    });
    is $result->{STATUS}, 'NOROOT';
} "certificate with missing root certificate (NOROOT)";


$oxitest->insert_testcerts(only => ['alpha_root_2']);


# expired certificate
lives_and {
    my $result = $oxitest->api_command("validate_certificate" => {
        PEM => $dbdata->cert("alpha_alice_1")->data,
    });
    is $result->{STATUS}, 'BROKEN';
} "invalid certificate (BROKEN)";

# valid certificate
lives_and {
    my $result = $oxitest->api_command("validate_certificate" => {
        PEM => $dbdata->cert("alpha_alice_2")->data,
    });
    is $result->{STATUS}, 'VALID';
} "valid certificate (VALID)";

# valid certificate - specify trust anchors
lives_and {
    my $result = $oxitest->api_command("validate_certificate" => {
        PEM => $dbdata->cert("alpha_alice_2")->data,
        ANCHOR => [ $dbdata->cert("alpha_root_2")->db->{issuer_identifier} ],
    });
    is $result->{STATUS}, 'TRUSTED';
} "valid certificate with correct trust anchor (TRUSTED)";

# valid certificate - specify wrong trust anchors
lives_and {
    my $result = $oxitest->api_command("validate_certificate" => {
        PEM => $dbdata->cert("alpha_alice_2")->data,
        ANCHOR => [ $dbdata->cert("alpha_root_1")->db->{issuer_identifier} ],
    });
    is $result->{STATUS}, 'UNTRUSTED';
} "valid certificate with unknown trust anchor (UNTRUSTED)";

#
# certificate chain (ArrayRef of PEM)
#

lives_and {
    my $result = $oxitest->api_command("validate_certificate" => {
        PEM => [
            $dbdata->cert("alpha_alice_2")->data,
            $dbdata->cert("alpha_signer_2")->data,
            $dbdata->cert("alpha_root_2")->data,
        ],
    });
    is $result->{STATUS}, 'VALID';
} "valid PEM ArrayRef certificate chain (VALID)";

#
# certificate chain (PKCS7)
#

lives_and {
    my $result = $oxitest->api_command("validate_certificate" => {
        PKCS7 => $dbdata->pkcs7->{"alpha-alice-2"},
    });
    is $result->{STATUS}, 'VALID';
} "valid PKCS7 certificate chain (VALID)";

$oxitest->delete_testcerts;

1;
