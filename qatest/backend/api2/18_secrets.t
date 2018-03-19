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

plan tests => 5;

#
# Setup test context
#
my $oxitest = OpenXPKI::Test->new(
    with => [ qw( TestRealms CryptoLayer ) ],
    add_config => {
        "realm.alpha.crypto.secret.mi" => {
            label => "Monkey Island",
            export => 1,
            method => "plain",
            total_shares => "3",
            cache => "daemon",
        },
        "realm.alpha.crypto.secret.mi2" => {
            label => "Monkey Island",
            export => 1,
            method => "plain",
            total_shares => "3",
            cache => "daemon",
        },
    },
    #log_level => "debug",
);

#
# PLEASE NOTE:
#
# Various types of secret stores and options are already tested in
# core/server/t/25_crypto/60_secret_cache.t
#

my $part1 = "elaine";
my $part2 = "likes";
my $part3 = "swords";

# set_secret_part
lives_and {
    $oxitest->api2_command("set_secret_part" => {
        secret => "mi", part => 2, value => $part2
    });
    $oxitest->api2_command("set_secret_part" => {
        secret => "mi", part => 1, value => $part1
    });
    $oxitest->api2_command("set_secret_part" => {
        secret => "mi", part => 3, value => $part3
    });

    is CTX('crypto_layer')->get_secret("mi"), "$part1$part2$part3";
} "set_secret_part - store secret";

# is_secret_complete
lives_and {
    is $oxitest->api2_command("is_secret_complete" => { secret => "mi" }), 1;
} "is_secret_complete - verify completeness";

# clear_secret
lives_and {
    $oxitest->api2_command("clear_secret" => { secret => "mi" });

    is CTX('crypto_layer')->get_secret("mi"), undef;
} "clear_secret";

# is_secret_complete
lives_and {
    is $oxitest->api2_command("is_secret_complete" => { secret => "mi" }), 0;
} "is_secret_complete - verify incompleteness";

# get_secrets
lives_and {
    cmp_deeply $oxitest->api2_command("get_secrets"), {
        'default' => { label => ignore(),        type => ignore() },
        'mi'      => { label => 'Monkey Island', type => 'plain' },
        'mi2'     => { label => 'Monkey Island', type => 'plain' },
    };
} "get_secrets";

1;
