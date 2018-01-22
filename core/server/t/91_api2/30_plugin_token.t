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
    with => "CryptoLayer",
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
my $as1 = $oxitest->certhelper_database->cert("alpha_signer_1");
my $as2 = $oxitest->certhelper_database->cert("alpha_signer_2");
my $as3 = $oxitest->certhelper_database->cert("alpha_signer_3");
my $av1 = $oxitest->certhelper_database->cert("alpha_datavault_1");
my $av2 = $oxitest->certhelper_database->cert("alpha_datavault_2");
my $bs1 = $oxitest->certhelper_database->cert("beta_signer_1");

my $api = CTX('api2');
my $result;

#
# get_ca_list
#
lives_and {
    my $data = $api->get_ca_list();

    cmp_deeply $data, bag(
        {
            alias       => $as1->db_alias->{alias},
            identifier  => $as1->db->{identifier},
            subject     => $as1->db->{subject},
            notafter    => $as1->db->{notafter},
            notbefore   => $as1->db->{notbefore},
            status      => "EXPIRED",
        },
        {
            alias       => $as2->db_alias->{alias},
            identifier  => $as2->db->{identifier},
            subject     => $as2->db->{subject},
            notafter    => $as2->db->{notafter},
            notbefore   => $as2->db->{notbefore},
            status      => "ONLINE",
        },
        {
            alias       => $as3->db_alias->{alias},
            identifier  => $as3->db->{identifier},
            subject     => $as3->db->{subject},
            notafter    => $as3->db->{notafter},
            notbefore   => $as3->db->{notbefore},
            status      => "UPCOMING",
        },
    );
} "get_ca_list - list signing CAs with correct status";

lives_and {
    my $data = $api->get_ca_list(
        pki_realm => 'beta',
    );

    cmp_deeply $data, bag(
        {
            alias       => $bs1->db_alias->{alias},
            identifier  => $bs1->db->{identifier},
            subject     => $bs1->db->{subject},
            notafter    => $bs1->db->{notafter},
            notbefore   => $bs1->db->{notbefore},
            status      => any(qw(ONLINE OFFLINE UNKNOWN)), # for currently valid certs a check will be made (ONLINE or OFFLINE), we test this later on
        },
    );
} "get_ca_list - list signing CAs with correct status (using 'pki_realm')";

#
# get_certificate_for_alias
#
lives_and {
    my $data = $api->get_certificate_for_alias(
        alias => $as1->db_alias->{alias}
    );

    cmp_deeply $data, {
        data        => $as1->db->{data},
        identifier  => $as1->db->{identifier},
        subject     => $as1->db->{subject},
        notafter    => $as1->db->{notafter},
        notbefore   => $as1->db->{notbefore},
    };
} "get_certificate_for_alias - correct cert data";

#
# get_default_token
#
lives_and {
    my $token = $api->get_default_token();
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
    my $data = $api->get_token_alias_by_group(
        group => $as2->db_alias->{group_id}
    );

    is $data, $as2->db_alias->{alias};
} "get_token_alias_by_group - currently valid token/cert alias";

lives_and {
    my $data = $api->get_token_alias_by_group(
        group => $as2->db_alias->{group_id},
        validity => {
            notbefore => undef,
            notafter  => undef,
        },
    );

    is $data, $as2->db_alias->{alias};
} "get_token_alias_by_group - currently valid token/cert alias ('validity' with undef values)";

lives_and {
    # 'validity' specifies a period shortly before alpha_signer_2 expires and
    # alpha_signer_2 is already valid, so _3 should be returned
    my $data = $api->get_token_alias_by_group(
        group    => $as2->db_alias->{group_id},
        validity => {
            notbefore => DateTime->from_epoch(epoch => $as2->db->{notafter} - 60*60*24),
            notafter  => DateTime->from_epoch(epoch => $as2->db->{notafter} - 60*60*24 * 2),
        },
    );

    is $data, $as3->db_alias->{alias};
} "get_token_alias_by_group - return newer certificate if 'validity' points to overlap period";

#
# get_token_alias_by_type
#
lives_and {
    my $data = $api->get_token_alias_by_type(type => "datasafe");
    is $data, $av2->db_alias->{alias};
} "get_token_alias_by_type - currently valid token/cert alias";

lives_and {
    my $data = $api->get_token_alias_by_type(
        type => "datasafe",
        validity => {
            notbefore => DateTime->from_epoch(epoch => $av1->db->{notbefore} + 60*60*24),
            notafter  => DateTime->from_epoch(epoch => $av1->db->{notafter}  - 60*60*24),
        },
    );
    is $data, $av1->db_alias->{alias};
} "get_token_alias_by_type - previously valid token/cert alias ('validity' with DateTime objects)";

#
# get_trust_anchors
#
lives_and {
    my $data = $api->get_trust_anchors(path => "realm.alpha.auth.handler.Signature");
    cmp_deeply $data, bag("MyCertId", $as2->db->{identifier});
} "get_trust_anchors";

#
# is_token_usable
#
lives_and {
    my $data = $api->is_token_usable(
        alias => $as2->db_alias->{alias},
    );
    is $data, 1;
} "is_token_usable - using 'alias'";

lives_and {
    my $data = $api->is_token_usable(
        alias => $as2->db_alias->{alias},
        engine => 1,
    );
    is $data, 1;
} "is_token_usable - using 'alias' and 'engine = 1'";

#
# list_active_aliases
#
lives_and {
    my $data = $api->list_active_aliases(
        group => $as2->db_alias->{group_id},
        check_online => 1,
    );

    cmp_deeply $data, bag(
        {
            alias       => $as2->db_alias->{alias},
            identifier  => $as2->db->{identifier},
            notafter    => $as2->db->{notafter},
            notbefore   => $as2->db->{notbefore},
            status      => "ONLINE",
        },
    );
} "list_active_aliases - using group and check_online";

lives_and {
    my $data = $api->list_active_aliases(
        group => $as1->db_alias->{group_id},
        validity => {
            notbefore => DateTime->from_epoch(epoch => $as1->db->{notbefore} + 60*60*24),
            notafter  => DateTime->from_epoch(epoch => $as1->db->{notafter}  - 60*60*24),
        },
        check_online => 1,
    );

    cmp_deeply $data, bag(
        {
            alias       => $as1->db_alias->{alias},
            identifier  => $as1->db->{identifier},
            notafter    => $as1->db->{notafter},
            notbefore   => $as1->db->{notbefore},
            status      => "ONLINE",
        },
    );
} "list_active_aliases - using group, validity and check_online";

lives_and {
    my $data = $api->list_active_aliases(
        type => "datasafe",
        check_online => 1,
    );

    cmp_deeply $data, bag(
        {
            alias       => $av2->db_alias->{alias},
            identifier  => $av2->db->{identifier},
            notafter    => $av2->db->{notafter},
            notbefore   => $av2->db->{notbefore},
            status      => "ONLINE",
        },
    );
} "list_active_aliases - using type and check_online";

lives_and {
    my $data = $api->list_active_aliases(
        pki_realm => $bs1->db->{pki_realm},
        group => $bs1->db_alias->{group_id},
        check_online => 1,
    );

    cmp_deeply $data, bag(
        {
            alias       => $bs1->db_alias->{alias},
            identifier  => $bs1->db->{identifier},
            notafter    => $bs1->db->{notafter},
            notbefore   => $bs1->db->{notbefore},
            status      => "UNKNOWN",
        },
    );
} "list_active_aliases - query another PKI realm (should not do online check)";

#
# Cleanup
#
$oxitest->delete_testcerts; # only deletes those from OpenXPKI::Test::CertHelper::Database

1;
