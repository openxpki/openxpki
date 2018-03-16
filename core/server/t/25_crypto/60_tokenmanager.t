#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );
use File::Temp qw( tempdir );

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;
use DateTime;

# Project modules
use lib "$Bin/../lib";
use OpenXPKI::Test;
use OpenXPKI::Crypto::Secret;

plan tests => 16;

#
# Setup test context
#
my $oxitest = OpenXPKI::Test->new(
    with => "CryptoLayer",
    also_init => "volatile_vault",
    add_config => {
        "realm.alpha.crypto.secret.monkey_island" => {
            label => "Monkey Island",
            export => 1,
            method => "plain",
            total_shares => "3",
            cache => "daemon",
        },
        "realm.alpha.crypto.secret.melee_island" => {
            label => "Monkey Island",
            export => 1,
            method => "split",
            total_shares => "5",
            required_shares => "3",
            cache => "daemon",
        },
        "realm.alpha.crypto.secret.monkey_island_session" => {
            label => "Monkey Island",
            export => 1,
            method => "literal",
            value => "onceuponatime",
            cache => "session",
        },
        "realm.alpha.crypto.secret.gentleman" => {
            label => "Gentleman",
            export => 0,
            method => "literal",
            value => "root",
            cache => "daemon",
        },
    },
);
CTX('session')->data->pki_realm('alpha');

#
# Tests
#
use_ok "OpenXPKI::Crypto::TokenManager";

my $tempdir = tempdir( CLEANUP => 1 );

# instantiate
my $tm;
lives_ok {
    $tm = OpenXPKI::Crypto::TokenManager->new({ TMPDIR => $tempdir });
} "instantiate TokenManager";

my $phrase = "elaine";

# non-exportable secret
lives_ok {
    $tm->set_secret_group_part({ GROUP => "gentleman", VALUE => $phrase });
} "store non-exportable secret";

throws_ok {
    $tm->get_secret("gentleman");
} qr/ no .* export /msxi, "prevent retrieval of unexportable secret";

#
# cache type "daemon" - multipart secret
#
lives_ok {
    $tm->set_secret_group_part({ GROUP => "monkey_island", PART => 2, VALUE => $phrase });
    $tm->set_secret_group_part({ GROUP => "monkey_island", PART => 1, VALUE => $phrase });
    $tm->set_secret_group_part({ GROUP => "monkey_island", PART => 3, VALUE => $phrase });
} "multipart secret: set parts";

lives_and {
    is $tm->get_secret("monkey_island"), $phrase x 3;
} "multipart secret: retrieve";

#
# cache type "daemon" - split secret (Shamir's secret splitting algorithm)
#
my $split_secret = OpenXPKI::Crypto::Secret->new ({
    TYPE => "Split",
    QUORUM => { N => 5, K => 3 },
    TOKEN  => $tm->get_system_token({ TYPE => 'default'}),
});
my @parts = $split_secret->compute;

lives_ok {
    $tm->set_secret_group_part({ GROUP => "melee_island", VALUE => $parts[0] });
    $tm->set_secret_group_part({ GROUP => "melee_island", VALUE => $parts[1] });
    $tm->set_secret_group_part({ GROUP => "melee_island", VALUE => $parts[2] });
} "split secret: set parts";

lives_and {
    is $tm->is_secret_group_complete("melee_island"), 1;
} "split secret: secret is complete";

lives_and {
     is $tm->get_secret("melee_island"), $split_secret->get_secret;
} "split secret: retrieve correct secret";

lives_and {
    $tm->clear_secret_group("melee_island");
    is $tm->is_secret_group_complete("melee_island"), 0;
} "split secret: clear secret";

lives_ok {
    $tm->set_secret_group_part({ GROUP => "melee_island", VALUE => $parts[2] });
    $tm->set_secret_group_part({ GROUP => "melee_island", VALUE => $parts[3] });
    $tm->set_secret_group_part({ GROUP => "melee_island", VALUE => $parts[4] });
} "split secret: set different parts";

lives_and {
    is $tm->is_secret_group_complete("melee_island"), 1;
} "split secret: secret is complete";

lives_and {
     is $tm->get_secret("melee_island"), $split_secret->get_secret;
} "split secret: retrieve correct secret";

#
# cache type "session" (Github issue #591)
#
lives_and {
    is $tm->get_secret("monkey_island_session"), "onceuponatime";
} "session cache: retrieve initial secret from config";

lives_ok {
    $tm->set_secret_group_part({ GROUP => "monkey_island_session", VALUE => $phrase });
} "session cache: store secret";

lives_and {
    is $tm->get_secret("monkey_island_session"), $phrase;
} "session cache: retrieve secret";

1;
