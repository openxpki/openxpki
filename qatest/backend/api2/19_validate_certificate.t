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

plan tests => 10;

#
# Init helpers
#
my $oxitest = OpenXPKI::Test->new(
    with => qw( CryptoLayer ),
);
my $dbdata = $oxitest->certhelper_database;
$oxitest->insert_testcerts(exclude => [ qw( alpha_root_2 ) ]);

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
    my $result = $oxitest->api2_command("validate_certificate" => {
        pem => $dbdata->cert("alpha_alice_2")->data,
    });
    cmp_deeply $result, {
        status => 'NOROOT',
        chain  => [
            $dbdata->cert("alpha_alice_2")->data,
            $dbdata->cert("alpha_signer_2")->data,
        ],
    };
} "certificate with missing root certificate (NOROOT)";

# certificate chain (ArrayRef of PEM)
# - finds alpha_signer_2 as the signing cert in the DB, but alpha_root_2 is unknown
lives_and {
    my $result = $oxitest->api2_command("validate_certificate" => {
        chain => [
            $dbdata->cert("alpha_alice_2")->data,
        ],
    });
    cmp_deeply $result, {
        status => 'NOROOT',
        chain  => [
            $dbdata->cert("alpha_alice_2")->data,
            $dbdata->cert("alpha_signer_2")->data,
        ],
    };
} "PEM ArrayRef certificate chain with unknown root cert (NOROOT)";

# certificate chain (ArrayRef of PEM)
# - does not find a parent for alpha_root_2 in the DB and marks chain as
#   UNTRUSTED (not NOROOT, because alpha_root_2 is a self-signed root cert)
lives_and {
    my $result = $oxitest->api2_command("validate_certificate" => {
        chain => [
            $dbdata->cert("alpha_alice_2")->data,
            $dbdata->cert("alpha_signer_2")->data,
            $dbdata->cert("alpha_root_2")->data,
        ],
    });
    $result->{chain} = [ map { $strip_newline->($_) } @{ $result->{chain} } ];
    cmp_deeply $result, {
        status => 'UNTRUSTED',
        chain  => $alpha_2_chain,
    };
} "PEM ArrayRef certificate chain with unknown root cert (UNTRUSTED)";


$oxitest->insert_testcerts(only => [ qw( alpha_root_2 ) ]);


# expired certificate
lives_and {
    my $result = $oxitest->api2_command("validate_certificate" => {
        pem => $dbdata->cert("alpha_alice_1")->data,
    });
    cmp_deeply $result, {
        status => 'BROKEN',
        chain  => $alpha_1_chain,
    };
} "invalid certificate (BROKEN)";

# valid certificate
lives_and {
    my $result = $oxitest->api2_command("validate_certificate" => {
        pem => $dbdata->cert("alpha_alice_2")->data,
    });
    $result->{chain} = [ map { $strip_newline->($_) } @{ $result->{chain} } ];
    cmp_deeply $result, {
        status => 'VALID',
        chain  => $alpha_2_chain,
    };
} "valid certificate (VALID)";

# valid certificate - specify trust anchors
lives_and {
    my $result = $oxitest->api2_command("validate_certificate" => {
        pem => $dbdata->cert("alpha_alice_2")->data,
        anchor => [ $dbdata->cert("alpha_root_2")->db->{issuer_identifier} ],
    });
    $result->{chain} = [ map { $strip_newline->($_) } @{ $result->{chain} } ];
    cmp_deeply $result, {
        status => 'TRUSTED',
        chain  => $alpha_2_chain,
    };
} "valid certificate with correct trust anchor (TRUSTED)";

# valid certificate - specify wrong trust anchors
lives_and {
    my $result = $oxitest->api2_command("validate_certificate" => {
        pem => $dbdata->cert("alpha_alice_2")->data,
        anchor => [ $dbdata->cert("alpha_root_1")->db->{issuer_identifier} ],
    });
    $result->{chain} = [ map { $strip_newline->($_) } @{ $result->{chain} } ];
    cmp_deeply $result, {
        status => 'UNTRUSTED',
        chain  => $alpha_2_chain,
    };
} "valid certificate with unknown trust anchor (UNTRUSTED)";

#
# certificate chain (ArrayRef of PEM)
#

lives_and {
    my $result = $oxitest->api2_command("validate_certificate" => {
        chain => [
            $dbdata->cert("alpha_alice_2")->data,
            $dbdata->cert("alpha_signer_2")->data,
            $dbdata->cert("alpha_root_2")->data,
        ],
    });
    $result->{chain} = [ map { $strip_newline->($_) } @{ $result->{chain} } ];
    cmp_deeply $result, {
        status => 'VALID',
        chain  => $alpha_2_chain,
    };
} "valid PEM ArrayRef certificate chain (VALID)";

lives_and {
    my $result = $oxitest->api2_command("validate_certificate" => {
        chain => [
            $dbdata->cert("alpha_alice_2")->data,
            $dbdata->cert("alpha_signer_2")->data,
        ],
    });
    $result->{chain} = [ map { $strip_newline->($_) } @{ $result->{chain} } ];
    cmp_deeply $result, {
        status => 'VALID',
        chain  => $alpha_2_chain,
    };
} "valid PEM ArrayRef certificate chain without root cert (VALID)";

#
# certificate chain (PKCS7)
#

lives_and {
    my $result = $oxitest->api2_command("validate_certificate" => {
        pkcs7 => $dbdata->pkcs7->{"alpha-alice-2"},
    });
    $result->{chain} = [ map { $strip_newline->($_) } @{ $result->{chain} } ];
    cmp_deeply $result, {
        status => 'VALID',
        chain  => $alpha_2_chain,
    };
} "valid PKCS7 certificate chain (VALID)";


$oxitest->delete_testcerts;

1;
