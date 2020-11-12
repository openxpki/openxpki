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

plan tests => 10;

SKIP: {
    eval { use Module::Load; load("OpenXPKI::Crypto::Secret::Split"); load("OpenXPKI::Crypto::Secret::SplitEncrypted") };
    skip 'EE only test', 10 if $@;

    my $temp_tokenmanager = tempdir( CLEANUP => 1 );
    my $temp_sharedir = tempdir( CLEANUP => 1 );

    #
    # Setup test context
    #
    my $oxitest = OpenXPKI::Test->new(
        with => "CryptoLayer",
        also_init => "volatile_vault",
        add_config => {
            "realm.alpha.crypto.secret" => {
                # Split secret (Shamir's secret splitting algorithm)
                melee_island => {
                    export => 1,
                    method => "split",
                    share_type => "plain",
                    total_shares => 5,
                    required_shares => 3,
                    cache => "daemon",
                },
                # Split secret with encrypted shares stored in file system
                hidden_monkey_island => {
                    export => 1,
                    method => "split",
                    share_type => "encrypted",
                    share_store => "filesystem",
                    share_name => "$temp_sharedir/[% ALIAS %]-[% INDEX %]",
                    total_shares => 5,
                    required_shares => 3,
                    cache => "daemon",
                },
                # Split secret with encrypted shares stored in datapool
                hidden_melee_island => {
                    export => 1,
                    method => "SPLit",          # make sure method,
                    share_type => "enCRYPTed",  # share_type and
                    share_store => "DaTaPooL",  # share_store and cache are handled case insensitive
                    share_name => "melee-[% INDEX %]",
                    total_shares => 5,
                    required_shares => 3,
                    cache => "dAEmOn",
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

    #
    # Split secret (Shamir's secret splitting algorithm)
    #
    sub test_shared_secret_3_of_5 {
        my ($tm, $secret_name, $secret, @parts) = @_;

        plan tests => 15;

        lives_and {
            is $tm->get_secret_required_part_count($secret_name), 3;
        } "part group A: required number of parts";

        lives_and {
            is $tm->get_secret_inserted_part_count($secret_name), 0;
        } "part group A: completion status 0/3";

        throws_ok {
            $tm->set_secret_part({ GROUP => $secret_name, VALUE => "" });
        } qr/I18N_OPENXPKI_UI_CRYPTO_SECRET_SPLIT_EMPTY_SHARE/,
          "fail when setting empty part";

        lives_ok {
            $tm->set_secret_part({ GROUP => $secret_name, VALUE => $parts[0] });
            $tm->set_secret_part({ GROUP => $secret_name, VALUE => $parts[1] });
            $tm->set_secret_part({ GROUP => $secret_name, VALUE => $parts[2] });
        } "part group A: set parts";

        lives_and {
            is $tm->is_secret_complete($secret_name), 1;
        } "part group A: secret is complete";

        lives_and {
            is $tm->get_secret_inserted_part_count($secret_name), 3;
        } "part group A: completion status 3/3";

        lives_and {
             is $tm->get_secret($secret_name), $secret;
        } "part group A: retrieve correct secret";

        lives_and {
            # clear_secret() calls OpenXPKI::Control::reload which wants to read
            # some (non-existing) config and kill the (non-running) server...
            no warnings 'redefine';
            local *OpenXPKI::Control::reload = sub {
                note "intercepted call to OpenXPKI::Control::reload()";
            };
            $tm->clear_secret($secret_name);
            is $tm->is_secret_complete($secret_name), 0;
        } "part group A: clear secret";

        lives_ok {
            $tm->set_secret_part({ GROUP => $secret_name, VALUE => $parts[2] });
            $tm->set_secret_part({ GROUP => $secret_name, VALUE => $parts[3] });
            $tm->set_secret_part({ GROUP => $secret_name, VALUE => $parts[4] });
        } "part group B: set different parts";

        lives_and {
            is $tm->is_secret_complete($secret_name), 1;
        } "part group B: secret is complete";

        lives_and {
             is $tm->get_secret($secret_name), $secret;
        } "part group B: retrieve correct secret";

        lives_and {
            # clear_secret() calls OpenXPKI::Control::reload which wants to read
            # some (non-existing) config and kill the (non-running) server...
            no warnings 'redefine';
            local *OpenXPKI::Control::reload = sub {
                note "intercepted call to OpenXPKI::Control::reload()";
            };
            $tm->clear_secret($secret_name);
            is $tm->is_secret_complete($secret_name), 0;
        } "part group B: clear secret";

        lives_ok {
            $tm->set_secret_part({ GROUP => $secret_name, VALUE => $parts[2] });
            $tm->set_secret_part({ GROUP => $secret_name, VALUE => $parts[3] });
        } "part group C: set 2/3 parts";

        throws_ok {
            $tm->set_secret_part({ GROUP => $secret_name, VALUE => $parts[3] });
        } qr/I18N_OPENXPKI_UI_CRYPTO_SECRET_SHARE_ALREADY_ENTERED/,
          "part group C: error when setting same part multiple times";

        lives_and {
            is $tm->is_secret_complete($secret_name), 0;
        } "part group C: secret is not complete";
    }

    #
    # Plain share/part, cache type "daemon"
    #
    use_ok 'OpenXPKI::Crypto::Secret::Split';
    my $split_secret = OpenXPKI::Crypto::Secret::Split->new(
        quorum_n => 5, quorum_k => 3,
        token => $tm->get_system_token({ TYPE => 'default'}),
    );
    my @parts = $split_secret->compute;

    subtest "shared secret" => sub {
        test_shared_secret_3_of_5($tm, "melee_island", $split_secret->get_secret, @parts);
    };

    #
    # Encrypted share/part, cache type "daemon"
    #
    # encrypted shares
    use_ok 'OpenXPKI::Crypto::Secret::SplitEncrypted';
    my $split_secret_enc = OpenXPKI::Crypto::Secret::SplitEncrypted->new(
        quorum_n => 5, quorum_k => 3,
        token => $tm->get_system_token({ TYPE => 'default'}),
        encrypted_share_loader => sub {}, share_names => [],
    );

    # passphrases to decrypt encrypted shares
    my @share_passphrases = (
        "12345678",
        "87654321",
        "abcdefgh",
        "11111111",
        "22222222",
    );

    my @enc_shares = $split_secret_enc->compute(keys => \@share_passphrases);

    #
    # ...share store "FILESYSTEM"
    #
    sub write_share_file {
        my ($index, $share) = @_;
        my $fh; open $fh, '>', "$temp_sharedir/hidden_monkey_island-$index";
        print $fh $share, "\n";
        close $fh;
    }

    throws_ok {
        $tm->set_secret_part({ GROUP => "hidden_monkey_island", VALUE => "dummy" });
    } qr/I18N_OPENXPKI_UI_CRYPTO_SECRET_SPLITENCRYPTED_UNABLE_TO_LOAD_ENCRYPTED_SHARE/,
      "fail if share does not exist";

    my $i = 0;
    write_share_file($i++ => $_) for @enc_shares;

    # tests
    throws_ok {
        $tm->set_secret_part({ GROUP => "hidden_monkey_island", VALUE => "dummy" });
    } qr/I18N_OPENXPKI_UI_CRYPTO_SECRET_SPLITENCRYPTED_WRONG_SHARE_PASSPHRASE/,
      "encrypted shared secret no.1: set wrong passphrase";

    subtest "encrypted shared secret, shares in filesystem" => sub {
        test_shared_secret_3_of_5($tm, "hidden_monkey_island", $split_secret_enc->get_secret, @share_passphrases);
    };

    #
    # ...share store "DATAPOOL"
    #
    sub write_share_datapool {
        my ($index, $share) = @_;
        CTX('api2')->set_data_pool_entry(
            pki_realm => 'alpha',
            namespace => 'secretshare',
            key => "melee-$index",
            value => $share,
            force => 1, # overwrite values from previous test runs
            expiration_date => time() + 120, # in case we use the host's database
        );
    }

    throws_ok {
        $tm->set_secret_part({ GROUP => "hidden_melee_island", VALUE => "dummy" });
    } qr/I18N_OPENXPKI_UI_CRYPTO_SECRET_SPLITENCRYPTED_UNABLE_TO_LOAD_ENCRYPTED_SHARE/,
      "fail if share does not exist";

    $i = 0;
    write_share_datapool($i++ => $_) for @enc_shares;

    subtest "encrypted shared secret, shares in datapool" => sub {
        test_shared_secret_3_of_5($tm, "hidden_melee_island", $split_secret_enc->get_secret, @share_passphrases);
    };

};

1;
