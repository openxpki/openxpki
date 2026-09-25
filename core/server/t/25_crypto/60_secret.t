#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );
use File::Temp qw( tempdir );

# CPAN modules
use Test::More;
use Test::Deep ':v1';
use Test::Exception;
use DateTime;

#use OpenXPKI::Debug; BEGIN { $OpenXPKI::Debug::LEVEL{'OpenXPKI::Crypto::Secret.*'} = 100 }

# Project modules
use lib "$Bin/../lib";
use OpenXPKI::Test;

plan tests => 14;

#
# Setup test context
#
my $temp_tokenmanager = tempdir( CLEANUP => 1 );
my $temp_tokenmanager2 = tempdir( CLEANUP => 1 );

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
                cache_check => 5,
            },
            # Plain secret, 1 part
            monkey_island_lonesome => {
                export => 1,
                method => "plain",
                total_shares => 1,
                cache => "daemon",
                cache_check => 5,
                kcv => '$argon2id$v=19$m=32768,t=3,p=1$NnJ6dGVBY2FwdGxkVE50ZGZRQkE4QT09$Q3d2HAWq7UCMLdipbacwYQ',
            },
            # Plain secret, 3 parts
            monkey_island => {
                export => 1,
                method => "plain",
                total_shares => 3,
                cache => "daemon",
                cache_check_if_complete => 2,
                cache_check => 2,
            },
            # Cache type "session"
            monkey_island_session => {
                export => 1,
                method => "literal",
                value => "onceuponatime",
                cache => "session",
                cache_check => 5,
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
my ($tm, $tm2);
lives_ok {
    $tm = OpenXPKI::Crypto::TokenManager->new({ TMPDIR => $temp_tokenmanager });
    $tm2 = OpenXPKI::Crypto::TokenManager->new({ TMPDIR => $temp_tokenmanager2 });
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
subtest 'single part secret' => sub {
    plan tests => 4;

    throws_ok {
        $tm->set_secret_part({ GROUP => "monkey_island_lonesome", VALUE => "wrong" });
    } qr/I18N_OPENXPKI_UI_SECRET_UNLOCK_KCV_MISMATCH/, "fail on wrong value (kcv check)";

    lives_and {
        is $tm->is_secret_complete("monkey_island_lonesome"), 0;
    } "completion status = false";

    lives_and {
        $tm->set_secret_part({ GROUP => "monkey_island_lonesome", VALUE => $phrase });
        is $tm->get_secret_inserted_part_count("monkey_island_lonesome"), 1;
    } "set part 1, completion status 1/1";

    lives_and {
        is $tm->get_secret("monkey_island_lonesome"), $phrase;
    } "retrieve";
};


#
# cache type "daemon" - multipart secret
#
subtest 'multi part secret' => sub {
    plan tests => 4;

    lives_and {
        $tm->set_secret_part({ GROUP => "monkey_island", PART => 2, VALUE => $phrase2 });
        is $tm->get_secret_inserted_part_count("monkey_island"), 1;
    } "set part 2, completion status 1/3";

    lives_and {
        $tm->set_secret_part({ GROUP => "monkey_island", PART => 1, VALUE => $phrase });
        is $tm->get_secret_inserted_part_count("monkey_island"), 2;
    } "set part 1, completion status 2/3";

    lives_and {
        $tm->set_secret_part({ GROUP => "monkey_island", PART => 3, VALUE => $phrase3 });
        is $tm->get_secret_inserted_part_count("monkey_island"), 3;
    } "set part 3, completion status 3/3";

    lives_and {
        is $tm->get_secret("monkey_island"), $phrase.$phrase2.$phrase3;
    } "retrieve";
};

subtest 'database cache / other instance' => sub {
    plan tests => 11;

    use_ok 'OpenXPKI::Crypto::SecretManager';
    use_ok 'OpenXPKI::Crypto::Secret::Plain';

    no warnings 'redefine';

    my $obj_inits = 0;
    my $orig = \&OpenXPKI::Crypto::SecretManager::_load;
    local *OpenXPKI::Crypto::SecretManager::_load = sub { $obj_inits++; $orig->(@_) };

    my $cache_reads = 0;
    my $orig2 = \&OpenXPKI::Crypto::SecretManager::_load_from_cache;
    local *OpenXPKI::Crypto::SecretManager::_load_from_cache = sub { $cache_reads++; $orig2->(@_) };

    my $secret_updates = 0;
    my $orig3 = \&OpenXPKI::Crypto::Secret::Plain::thaw;
    local *OpenXPKI::Crypto::Secret::Plain::thaw = sub { $secret_updates++; $orig3->(@_) };

    is $tm2->is_secret_complete("monkey_island"), 1, 'correctly fetch status "complete"';

    is $obj_inits, 1, '  instance initialized';
    is $cache_reads, 1, '  cache read';
    is $secret_updates, 1, '  secret updated';

    is $tm2->get_secret_inserted_part_count("monkey_island"), 3, 'completion status 3/3';
    is $obj_inits, 1, '  no init on follow up queries';

    sleep 3;

    lives_and {
        is $tm2->is_secret_complete("monkey_island"), 1;
    } 'correctly fetch status "complete" after "cache_check_if_complete"';

    is $cache_reads, 2, '  cache read';
    is $secret_updates, 1, '  secret NOT updated because of same cache checksum';
};

lives_and {
    # clear_secret() calls OpenXPKI::Control::Server->new->cmd_reload which wants to read
    # some (non-existing) config and kill the (non-running) server...
    no warnings 'redefine';
    local *OpenXPKI::Control::Server::cmd_reload = sub { note "intercepted OpenXPKI::Control::Server::cmd_reload()" };

    $tm->clear_secret("monkey_island");
    is $tm->get_secret_inserted_part_count("monkey_island"), 0;
} "clear secret, completion status 0/3";

lives_and {
    is $tm2->is_secret_complete("monkey_island"), 1;
} "other instance: incorrectly fetch status 'complete' during 'cache_check_if_complete'";

sleep 3;

lives_and {
    is $tm2->is_secret_complete("monkey_island"), 0;
} "other instance: correctly fetch status 'incomplete' after 'cache_check_if_complete'";

#
# Cache type "session"
# (also see issue #591: cache type "session" causes a validation error in Session::Data)
#
subtest 'session cache' => sub {
    plan tests => 3;

    lives_and {
        is $tm->get_secret("monkey_island_session"), "onceuponatime";
    } "retrieve initial secret from config";

    lives_ok {
        $tm->set_secret_part({ GROUP => "monkey_island_session", VALUE => "peace_pipe" });
    } "store secret";

    lives_and {
        is $tm->get_secret("monkey_island_session"), "peace_pipe";
    } "retrieve secret";
};

#
# Missing cache type
#
throws_ok {
    $tm->set_secret_part({ GROUP => "lechuck", VALUE => $phrase });
} qr/ no .* type /msxi, "complain about missing cache type";

#
# Imported global secret
#
subtest 'imported global secret' => sub {
    plan tests => 2;

    lives_and {
        is $tm->is_secret_complete("default"), 1;
    } "secret is complete";

    lives_and {
        is $tm->get_secret("default"), "beetroot";
    } "secret is correct";
};

1;
