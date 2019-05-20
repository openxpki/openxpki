#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );
use MIME::Base64;

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;
use DateTime;

# Project modules
use lib "$Bin/../lib";
use OpenXPKI::Test;
use OpenXPKI::Test::CertHelper::Database;

plan tests => 16;

#
# Setup test context
#
my $oxitest = OpenXPKI::Test->new(
    with => [ qw( TestRealms CryptoLayer ) ],
    add_config => {
        "realm.alpha.auth.handler.Signature" => {
            type             => "ChallengeX509",
            challenge_length => 256,
            role             => "User",
            realm            => [ "alpha" ],
            cacert           => [ "MyCertId" ],
        },
    },
);

$oxitest->insert_testcerts;
CTX('session')->data->pki_realm('alpha');

#
# Tests
#
my $as1 = $oxitest->certhelper_database->cert("alpha-signer-1");
my $as2 = $oxitest->certhelper_database->cert("alpha-signer-2");
my $as3 = $oxitest->certhelper_database->cert("alpha-signer-3");
my $av1 = $oxitest->certhelper_database->cert("alpha-datavault-1");
my $av2 = $oxitest->certhelper_database->cert("alpha-datavault-2");
my $bs1 = $oxitest->certhelper_database->cert("beta-signer-1");

#
# get_ca_list
#
lives_and {
    my $data = CTX('api')->get_ca_list();

    cmp_deeply $data, bag(
        {
            ALIAS       => $as1->db_alias->{alias},
            IDENTIFIER  => $as1->db->{identifier},
            SUBJECT     => $as1->db->{subject},
            NOTAFTER    => $as1->db->{notafter},
            NOTBEFORE   => $as1->db->{notbefore},
            STATUS      => "EXPIRED",
        },
        {
            ALIAS       => $as2->db_alias->{alias},
            IDENTIFIER  => $as2->db->{identifier},
            SUBJECT     => $as2->db->{subject},
            NOTAFTER    => $as2->db->{notafter},
            NOTBEFORE   => $as2->db->{notbefore},
            STATUS      => ignore(), # for currently valid certs a check will be made (ONLINE or OFFLINE), we test this later on
        },
        {
            ALIAS       => $as3->db_alias->{alias},
            IDENTIFIER  => $as3->db->{identifier},
            SUBJECT     => $as3->db->{subject},
            NOTAFTER    => $as3->db->{notafter},
            NOTBEFORE   => $as3->db->{notbefore},
            STATUS      => "UPCOMING",
        },
    );
} "get_ca_list - list signing CAs with correct status";

lives_and {
    my $data = CTX('api')->get_ca_list({
        PKI_REALM => 'beta',
    });

    cmp_deeply $data, bag(
        {
            ALIAS       => $bs1->db_alias->{alias},
            IDENTIFIER  => $bs1->db->{identifier},
            SUBJECT     => $bs1->db->{subject},
            NOTAFTER    => $bs1->db->{notafter},
            NOTBEFORE   => $bs1->db->{notbefore},
            STATUS      => any(qw(ONLINE OFFLINE UNKNOWN)), # for currently valid certs a check will be made (ONLINE or OFFLINE), we test this later on
        },
    );
} "get_ca_list - list signing CAs with correct status (using PKI_REALM)";

#
# get_certificate_for_alias
#
lives_and {
    my $data = CTX('api')->get_certificate_for_alias({
        ALIAS => $as1->db_alias->{alias}
    });

    cmp_deeply $data, {
        DATA           => $as1->db->{data},
        IDENTIFIER     => $as1->db->{identifier},
        SUBJECT        => $as1->db->{subject},
        NOTAFTER       => $as1->db->{notafter},
        NOTBEFORE      => $as1->db->{notbefore},
        KEY_IDENTIFIER => $as1->db->{subject_key_identifier},
    };
} "get_certificate_for_alias - correct cert data";

#
# get_default_token
#
lives_and {
    my $token = CTX('api')->get_default_token();
    my $rand_base64 = $token->command({
        COMMAND       => 'create_random',
        RANDOM_LENGTH => 10,
    });
    is length(decode_base64($rand_base64)), 10;
} "get_default_token - return usable token";

#
#
# get_token_alias_by_group
#
lives_and {
    my $data = CTX('api')->get_token_alias_by_group({
        GROUP => $as2->db_alias->{group_id}
    });

    is $data, $as2->db_alias->{alias};
} "get_token_alias_by_group - currently valid token/cert alias";

lives_and {
    my $data = CTX('api')->get_token_alias_by_group({
        GROUP => $as2->db_alias->{group_id},
        VALIDITY => {
            NOTBEFORE => undef,
            NOTAFTER  => undef,
        },
    });

    is $data, $as2->db_alias->{alias};
} "get_token_alias_by_group - currently valid token/cert alias (VALIDITY with undef values)";

lives_and {
    # VALIDITY specifies a period shortly before alpha-signer-2 expires and
    # alpha-signer-2 is already valid, so _3 should be returned
    my $data = CTX('api')->get_token_alias_by_group({
        GROUP    => $as2->db_alias->{group_id},
        VALIDITY => {
            NOTBEFORE => DateTime->from_epoch(epoch => $as2->db->{notafter} - 60*60*24),
            NOTAFTER  => DateTime->from_epoch(epoch => $as2->db->{notafter} - 60*60*24 * 2),
        },
    });

    is $data, $as3->db_alias->{alias};
} "get_token_alias_by_group - return newer certificate if VALIDITY points to overlap period";

#
# get_token_alias_by_type
#
lives_and {
    my $data = CTX('api')->get_token_alias_by_type({ TYPE => "datasafe" });
    is $data, $av2->db_alias->{alias};
} "get_token_alias_by_type - currently valid token/cert alias";

lives_and {
    my $data = CTX('api')->get_token_alias_by_type({
        TYPE => "datasafe",
        VALIDITY => {
            NOTBEFORE => DateTime->from_epoch(epoch => $av1->db->{notbefore} + 60*60*24),
            NOTAFTER  => DateTime->from_epoch(epoch => $av1->db->{notafter}  - 60*60*24),
        },
    });
    is $data, $av1->db_alias->{alias};
} "get_token_alias_by_type - previously valid token/cert alias (VALIDITY with DateTime objects)";

#
# get_trust_anchors
#
lives_and {
    my $a2 = $oxitest->certhelper_database->cert("alpha-signer-2");

    my $data = CTX('api')->get_trust_anchors({ PATH => "realm.alpha.auth.handler.Signature" });
    cmp_deeply $data, bag("MyCertId", $a2->db->{identifier});
} "get_trust_anchors";

#
# is_token_usable
#
lives_and {
    my $data = CTX('api')->is_token_usable({
        ALIAS => $as2->db_alias->{alias},
    });
    is $data, 1;
} "is_token_usable - using ALIAS";

lives_and {
    my $data = CTX('api')->is_token_usable({
        ALIAS => $as2->db_alias->{alias},
        ENGINE => 1,
    });
    is $data, 1;
} "is_token_usable - using ALIAS and ENGINE = 1";

#
# list_active_aliases
#
lives_and {
    my $data = CTX('api')->list_active_aliases({
        GROUP => $as2->db_alias->{group_id},
        CHECK_ONLINE => 1,
    });

    cmp_deeply $data, bag(
        {
            ALIAS       => $as2->db_alias->{alias},
            IDENTIFIER  => $as2->db->{identifier},
            NOTAFTER    => $as2->db->{notafter},
            NOTBEFORE   => $as2->db->{notbefore},
            STATUS      => "ONLINE",
        },
    );
} "list_active_aliases - using GROUP and CHECK_ONLINE";

lives_and {
    my $data = CTX('api')->list_active_aliases({
        GROUP => $as1->db_alias->{group_id},
        VALIDITY => {
            NOTBEFORE => DateTime->from_epoch(epoch => $as1->db->{notbefore} + 60*60*24),
            NOTAFTER  => DateTime->from_epoch(epoch => $as1->db->{notafter}  - 60*60*24),
        },
        CHECK_ONLINE => 1,
    });

    cmp_deeply $data, bag(
        {
            ALIAS       => $as1->db_alias->{alias},
            IDENTIFIER  => $as1->db->{identifier},
            NOTAFTER    => $as1->db->{notafter},
            NOTBEFORE   => $as1->db->{notbefore},
            STATUS      => "ONLINE",
        },
    );
} "list_active_aliases - using GROUP, VALIDITY and CHECK_ONLINE";

TODO: {
    local $TODO = "Unable to query tokens of other PKI realm (Github issue #508)";

    lives_and {
        my $data = CTX('api')->list_active_aliases({
            PKI_REALM => $bs1->db->{pki_realm},
            GROUP => $bs1->db_alias->{group_id},
            CHECK_ONLINE => 1,
        });

        cmp_deeply $data, bag(
            {
                ALIAS       => $bs1->db_alias->{alias},
                IDENTIFIER  => $bs1->db->{identifier},
                NOTAFTER    => $bs1->db->{notafter},
                NOTBEFORE   => $bs1->db->{notbefore},
                STATUS      => "ONLINE",
            },
        );
    } "list_active_aliases - using GROUP and CHECK_ONLINE";
}

lives_and {
    my $data = CTX('api')->list_active_aliases({
        TYPE => "datasafe",
        CHECK_ONLINE => 1,
    });

    cmp_deeply $data, bag(
        {
            ALIAS       => $av2->db_alias->{alias},
            IDENTIFIER  => $av2->db->{identifier},
            NOTAFTER    => $av2->db->{notafter},
            NOTBEFORE   => $av2->db->{notbefore},
            STATUS      => "ONLINE",
        },
    );
} "list_active_aliases - using TYPE and CHECK_ONLINE";

#
# Cleanup
#
$oxitest->delete_testcerts; # only deletes those from OpenXPKI::Test::CertHelper::Database

1;
