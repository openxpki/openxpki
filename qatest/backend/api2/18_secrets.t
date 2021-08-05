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

use lib $Bin, "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
#use OpenXPKI::Debug; BEGIN { $OpenXPKI::Debug::LEVEL{'OpenXPKI::Crypto::SecretManager'} = 100 }

# Project modules
use OpenXPKI::Test;

plan tests => 6;

#
# Setup test context
#
my $oxitest = OpenXPKI::Test->new(
    with => [ qw( TestRealms CryptoLayer ) ],
    add_config => {
        "realm.alpha.crypto.secret.mi-1" => {
            label => "Monkey Island",
            export => 1,
            method => "plain",
            total_shares => "3",
            cache => "daemon",
        },
        "realm.alpha.crypto.secret.mi-2" => {
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
# core/server/t/25_crypto/60_tokenmanager.t
#

my $part1 = "elaine";
my $part2 = "likes";
my $part3 = "swords";

# set_secret_part
lives_and {
    $oxitest->api2_command("set_secret_part" => {
        secret => "mi-$_", part => 2, value => $part2
    });
    $oxitest->api2_command("set_secret_part" => {
        secret => "mi-$_", part => 1, value => $part1
    });
    $oxitest->api2_command("set_secret_part" => {
        secret => "mi-$_", part => 3, value => $part3
    });

    is CTX('crypto_layer')->get_secret("mi-$_"), "$part1$part2$part3";
} "set_secret_part - store secret no. $_" for (1..2);

# is_secret_complete
lives_and {
    is $oxitest->api2_command("is_secret_complete" => { secret => "mi-1" }), 1;
} "is_secret_complete - verify completeness";

# clear_secret
lives_and {
    # 'clear_secret' calls clear_secret_group() which calls
    # OpenXPKI::Control::reload() which wants to read
    # some (non-existing) config and kill the (non-running) server...
    no warnings 'redefine';
    local *OpenXPKI::Control::reload = sub {
        note "intercepted call to OpenXPKI::Control::reload()";
    };

    $oxitest->api2_command("clear_secret" => { secret => "mi-1" });

    is CTX('crypto_layer')->get_secret("mi-1"), undef;
} "clear_secret";

# is_secret_complete
lives_and {
    is $oxitest->api2_command("is_secret_complete" => { secret => "mi-1" }), 0;
} "is_secret_complete - verify incompleteness";

# get_secrets
lives_and {
    my $secrets = $oxitest->api2_command("get_secrets");
    cmp_deeply $secrets, {
        'default' => {
            label => ignore(),
            type => ignore(),
            complete => 1,
            inserted_parts => 1,
            required_parts => 1,
        },
        'mi-1' => {
            label => 'Monkey Island',
            type => 'plain',
            complete => 0,
            inserted_parts => 0,
            required_parts => 3,
         },
        'mi-2' => {
            label => 'Monkey Island',
            type => 'plain',
            complete => 1,
            inserted_parts => 3,
            required_parts => 3,
         },
    } or diag explain $secrets;
} "get_secrets";

1;
