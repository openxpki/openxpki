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

plan tests => 9;

#
# Init helpers
#
my $oxitest = OpenXPKI::Test->new(
    with => qw( CryptoLayer ),
);
my $dbdata = $oxitest->certhelper_database;
$oxitest->insert_testcerts(exclude => ['alpha_root_2']);

my $alpha_1_chain = [
    $dbdata->cert("alpha_alice_1")->data,
    $dbdata->cert("alpha_signer_1")->data,
    $dbdata->cert("alpha_root_1")->data,
];

my $strip_newline = sub { (my $pem = shift) =~ s/\R//gm; return $pem };

my $a2_alice =  $strip_newline->($dbdata->cert("alpha_alice_2")->data);
my $a2_signer = $strip_newline->($dbdata->cert("alpha_signer_2")->data);
my $a2_root =   $strip_newline->($dbdata->cert("alpha_root_2")->data);
my $alpha_2_chain = [
    $a2_alice,
    $a2_signer,
    $a2_root,
];

#
# missing root certificate
#

# single certificate (PEM)
lives_and {
    my $result = $oxitest->api_command("validate_certificate" => {
        PEM => $dbdata->cert("alpha_alice_2")->data,
    });
    cmp_deeply $result, {
        STATUS => 'NOROOT',
        CHAIN  => [
            $dbdata->cert("alpha_alice_2")->data,
            $dbdata->cert("alpha_signer_2")->data,
        ],
    };
} "certificate with missing root certificate (NOROOT)";

# certificate chain (ArrayRef of PEM)
lives_and {
    my $result = $oxitest->api_command("validate_certificate" => {
        PEM => [
            $dbdata->cert("alpha_alice_2")->data,
            $dbdata->cert("alpha_signer_2")->data,
            $dbdata->cert("alpha_root_2")->data,
        ],
    });
    $result->{CHAIN} = [ map { $strip_newline->($_) } @{ $result->{CHAIN} } ];
    cmp_deeply $result, {
        STATUS => 'UNTRUSTED',
        CHAIN  => $alpha_2_chain,
    };
} "PEM ArrayRef certificate chain with unknown root cert (UNTRUSTED)";


$oxitest->insert_testcerts(only => ['alpha_root_2']);


# expired certificate
lives_and {
    my $result = $oxitest->api_command("validate_certificate" => {
        PEM => $dbdata->cert("alpha_alice_1")->data,
    });
    cmp_deeply $result, {
        STATUS => 'BROKEN',
        CHAIN  => $alpha_1_chain,
    };
} "invalid certificate (BROKEN)";

# valid certificate
lives_and {
    my $result = $oxitest->api_command("validate_certificate" => {
        PEM => $dbdata->cert("alpha_alice_2")->data,
    });
    $result->{CHAIN} = [ map { $strip_newline->($_) } @{ $result->{CHAIN} } ];
    cmp_deeply $result, {
        STATUS => 'VALID',
        CHAIN  => $alpha_2_chain,
    };
} "valid certificate (VALID)";

# valid certificate - specify trust anchors
lives_and {
    my $result = $oxitest->api_command("validate_certificate" => {
        PEM => $dbdata->cert("alpha_alice_2")->data,
        ANCHOR => [ $dbdata->cert("alpha_root_2")->db->{issuer_identifier} ],
    });
    $result->{CHAIN} = [ map { $strip_newline->($_) } @{ $result->{CHAIN} } ];
    cmp_deeply $result, {
        STATUS => 'TRUSTED',
        CHAIN  => $alpha_2_chain,
    };
} "valid certificate with correct trust anchor (TRUSTED)";

# valid certificate - specify wrong trust anchors
lives_and {
    my $result = $oxitest->api_command("validate_certificate" => {
        PEM => $dbdata->cert("alpha_alice_2")->data,
        ANCHOR => [ $dbdata->cert("alpha_root_1")->db->{issuer_identifier} ],
    });
    $result->{CHAIN} = [ map { $strip_newline->($_) } @{ $result->{CHAIN} } ];
    cmp_deeply $result, {
        STATUS => 'UNTRUSTED',
        CHAIN  => $alpha_2_chain,
    };
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
    $result->{CHAIN} = [ map { $strip_newline->($_) } @{ $result->{CHAIN} } ];
    cmp_deeply $result, {
        STATUS => 'VALID',
        CHAIN  => $alpha_2_chain,
    };
} "valid PEM ArrayRef certificate chain (VALID)";

lives_and {
    my $result = $oxitest->api_command("validate_certificate" => {
        PEM => [
            $dbdata->cert("alpha_alice_2")->data,
            $dbdata->cert("alpha_signer_2")->data,
        ],
    });
    $result->{CHAIN} = [ map { $strip_newline->($_) } @{ $result->{CHAIN} } ];
    cmp_deeply $result, {
        STATUS => 'VALID',
        CHAIN  => $alpha_2_chain,
    };
} "valid PEM ArrayRef certificate chain without root cert (VALID)";

#
# certificate chain (PKCS7)
#

lives_and {
    my $result = $oxitest->api_command("validate_certificate" => {
        PKCS7 => $dbdata->pkcs7->{"alpha-alice-2"},
    });
    $result->{CHAIN} = [ map { $strip_newline->($_) } @{ $result->{CHAIN} } ];
    cmp_deeply $result, {
        STATUS => 'VALID',
        CHAIN  => $alpha_2_chain,
    };
} "valid PKCS7 certificate chain (VALID)";

$oxitest->delete_testcerts;

1;
