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

#use OpenXPKI::Debug; BEGIN { $OpenXPKI::Debug::LEVEL{'OpenXPKI::Crypto::Secret.*'} = 100 }

# Project modules
use lib "$Bin/../lib";
use OpenXPKI::Test;

plan tests => 25;
my $temp_tokenmanager = tempdir( CLEANUP => 1 );

#
# Setup test context
#
my $oxitest = OpenXPKI::Test->new(
    with => "CryptoLayer",
    also_init => "volatile_vault",
    add_config => {
        "system.crypto.secret" => {
            default => {
                export => 1,
                method => "literal",
                value => "beetroot",
            },
        },
        "realm.alpha.crypto.secret" => {
            # Un-exportable secret
            gentleman => {
                export => 0,
                method => "literal",
                value => "root",
                cache => "daemon",
            },
            # Plain secret, 1 part
            monkey_island_lonesome => {
                export => 1,
                method => "plain",
                total_shares => 1,
                cache => "daemon",
                kcv => '$argon2id$v=19$m=32768,t=3,p=1$NnJ6dGVBY2FwdGxkVE50ZGZRQkE4QT09$Q3d2HAWq7UCMLdipbacwYQ',
            },
            # Plain secret, 3 parts
            monkey_island => {
                export => 1,
                method => "plain",
                total_shares => 3,
                cache => "daemon",
            },
            # Cache type "session"
            monkey_island_session => {
                export => 1,
                method => "literal",
                value => "onceuponatime",
                cache => "session",
            },
            # Secret with missing cache type
            lechuck => {
                export => 1,
                method => "plain",
                total_shares => 1,
            },
            # Import global secret
            default => {
                export => 1,
                import => 1,
            },
        },
    },
);
CTX('session')->data->pki_realm('alpha');

#
# Tests
#
use_ok "OpenXPKI::Crypto::TokenManager";

# instantiate
my $tm;
lives_ok {
    $tm = OpenXPKI::Crypto::TokenManager->new({ TMPDIR => $temp_tokenmanager });
} "instantiate TokenManager";

my $phrase = "elaine";
my $phrase2 = "marley";
my $phrase3 = "governor";

# non-existing secret
throws_ok {
    $tm->set_secret_part({ GROUP => "idontexist", VALUE => "1234" });
} qr/I18N_OPENXPKI_SECRET_GROUP_DOES_NOT_EXIST/,
  "fail when trying to store non-existing secret";

# non-exportable secret
lives_ok {
    $tm->set_secret_part({ GROUP => "gentleman", VALUE => $phrase });
} "store non-exportable secret";

throws_ok {
    $tm->get_secret("gentleman");
} qr/ no .* export /msxi, "prevent retrieval of unexportable secret";

#
# cache type "daemon" - single part secret
#
throws_ok {
    $tm->set_secret_part({ GROUP => "monkey_island_lonesome", VALUE => "wrong" });
} qr/I18N_OPENXPKI_UI_SECRET_UNLOCK_KCV_MISMATCH/, "single part secret: fail on wrong value (kcv check)";

lives_and {
    is $tm->is_secret_complete("monkey_island_lonesome"), 0;
} "single part secret: completion status = false";

lives_and {
    $tm->set_secret_part({ GROUP => "monkey_island_lonesome", VALUE => $phrase });
    is $tm->get_secret_inserted_part_count("monkey_island_lonesome"), 1;
} "single part secret: set part 1, completion status 1/1";

lives_and {
    is $tm->get_secret("monkey_island_lonesome"), $phrase;
} "single part secret: retrieve";

#
# cache type "daemon" - multipart secret
#
lives_and {
    $tm->set_secret_part({ GROUP => "monkey_island", PART => 2, VALUE => $phrase2 });
    is $tm->get_secret_inserted_part_count("monkey_island"), 1;
} "multipart secret: set part 2, completion status 1/3";

lives_and {
    $tm->set_secret_part({ GROUP => "monkey_island", PART => 1, VALUE => $phrase });
    is $tm->get_secret_inserted_part_count("monkey_island"), 2;
} "multipart secret: set part 1, completion status 2/3";

lives_and {
    $tm->set_secret_part({ GROUP => "monkey_island", PART => 3, VALUE => $phrase3 });
    is $tm->get_secret_inserted_part_count("monkey_island"), 3;
} "multipart secret: set part 3, completion status 3/3";

lives_and {
    is $tm->get_secret("monkey_island"), $phrase.$phrase2.$phrase3;
} "multipart secret: retrieve";

lives_and {
    # clear_secret() calls OpenXPKI::Control::reload which wants to read
    # some (non-existing) config and kill the (non-running) server...
    no warnings 'redefine';
    local *OpenXPKI::Control::reload = sub { note "intercepted OpenXPKI::Control::reload()" };

    $tm->clear_secret("monkey_island");
    is $tm->get_secret_inserted_part_count("monkey_island"), 0;
} "clear secret, completion status 0/3";

#
# Cache type "session"
# (also see issue #591: cache type "session" causes a validation error in Session::Data)
#
lives_and {
    is $tm->get_secret("monkey_island_session"), "onceuponatime";
} "session cache: retrieve initial secret from config";

lives_ok {
    $tm->set_secret_part({ GROUP => "monkey_island_session", VALUE => "peace_pipe" });
} "session cache: store secret";

lives_and {
    is $tm->get_secret("monkey_island_session"), "peace_pipe";
} "session cache: retrieve secret";

#
# Missing cache type
#
throws_ok {
    $tm->set_secret_part({ GROUP => "lechuck", VALUE => $phrase });
} qr/ no .* type /msxi, "complain about missing cache type";

#
# Imported global secret
#
lives_and {
    is $tm->is_secret_complete("default"), 1;
} "imported global secret: secret is complete";

lives_and {
    is $tm->get_secret("default"), "beetroot";
} "imported global secret: secret is correct";

#
# Database caching
#
my $tm2;
lives_ok {
    $tm2 = OpenXPKI::Crypto::TokenManager->new({ TMPDIR => $temp_tokenmanager });
} "TokenManager instance 2";

lives_and {
    # clear_secret() calls OpenXPKI::Control::reload which wants to read
    # some (non-existing) config and kill the (non-running) server...
    no warnings 'redefine';
    local *OpenXPKI::Control::reload = sub { note "intercepted OpenXPKI::Control::reload()" };

    $tm->clear_secret("monkey_island");
    $tm->set_secret_part({ GROUP => "monkey_island", PART => 2, VALUE => $phrase });
    is $tm->get_secret_inserted_part_count("monkey_island"), 1;
} "cache test: instance 1 - completion status 1/3";

my $calls = 0;

no warnings 'redefine';
my $orig = \&OpenXPKI::Crypto::SecretManager::_load;
local *OpenXPKI::Crypto::SecretManager::_load = sub { $calls++; $orig->(@_) };

lives_and {
    is $tm2->get_secret_inserted_part_count("monkey_island"), 1;
} "cache test: instance 2 - completion status 1/3";

is $calls, 1, "cache test: instance 2 - cache is read once";

$calls = 0;

lives_and {
    $tm2->is_secret_complete("monkey_island");
    is $calls, 0;
} "cache test: instance 2 - cache is not read on follow up queries";

1;
