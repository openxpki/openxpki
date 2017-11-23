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

plan tests => 8;

#
# Setup test context
#
my $oxitest = OpenXPKI::Test->new;
$oxitest->realm_config(
    "alpha",
    "crypto.secret.monkey_island_daemon" => {
        label => "Monkey Island",
        export => 1,
        method => "literal",
        value => "root",
        cache => "daemon",
    }
);
$oxitest->realm_config(
    "alpha",
    "crypto.secret.monkey_island_session" => {
        label => "Monkey Island",
        export => 1,
        method => "literal",
        value => "root",
        cache => "session",
    }
);
$oxitest->realm_config(
    "alpha",
    "crypto.secret.gentleman" => {
        label => "Gentleman",
        export => 0,
        method => "literal",
        value => "root",
        cache => "daemon",
    }
);
$oxitest->setup_env->init_server('crypto_layer', 'volatile_vault');
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

# cache type "daemon"
lives_ok {
    $tm->set_secret_group_part({ GROUP => "monkey_island_daemon", VALUE => $phrase });
} "store secret (daemon)";

lives_and {
    is $tm->get_secret("monkey_island_daemon"), $phrase;
} "retrieve secret (daemon)";

# cache type "session" (Github issue #591)
lives_ok {
    $tm->set_secret_group_part({ GROUP => "monkey_island_session", VALUE => $phrase });
} "store secret (daemon)";

lives_and {
    is $tm->get_secret("monkey_island_session"), $phrase;
} "retrieve secret (daemon)";

1;
