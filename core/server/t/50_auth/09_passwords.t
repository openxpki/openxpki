## Tests for OpenXPKI::Password - hash creation and verification for all supported schemes
##

use strict;
use warnings;

use FindBin qw( $Bin );
use lib "$Bin/../..";

use Test::More;
use Test::Exception;
use MIME::Base64;

use OpenXPKI::Password;

my $password = 'correct horse battery staple';

# Each entry: [ scheme, label, optional hash_params ]
my @schemes = (
    [ 'plain',   'plain'   ],
    [ 'md5',     'MD5'     ],
    [ 'smd5',    'salted MD5' ],
    [ 'sha',     'SHA1'    ],
    [ 'ssha',    'salted SHA1' ],
    [ 'sha224',  'SHA-224' ],
    [ 'ssha224', 'salted SHA-224' ],
    [ 'sha256',  'SHA-256' ],
    [ 'ssha256', 'salted SHA-256' ],
    [ 'sha384',  'SHA-384' ],
    [ 'ssha384', 'salted SHA-384' ],
    [ 'sha512',  'SHA-512' ],
    [ 'ssha512', 'salted SHA-512' ],
    [ 'crypt',   'crypt'   ],
    [ 'argon2',  'Argon2', { time => 1, memory => '32M', p => 1, tag => 16 } ],
);

use_ok 'OpenXPKI::Password';

for my $entry (@schemes) {
    my ($scheme, $label, $params) = @$entry;

    my $hash;
    lives_ok {
        $hash = OpenXPKI::Password::hash($scheme, $password, $params);
    } "$label: hash created";

    ok defined $hash, "$label: hash is defined";

    my $result;
    lives_ok {
        $result = OpenXPKI::Password::check($password, $hash);
    } "$label: check runs without exception";

    ok $result, "$label: correct password verifies";
}

# -------------------------------------------------------------------------
# Probe series 2: hashes produced by `openssl passwd` (native crypt format)
# Tests the '$[156]$' detection branch in OpenXPKI::Password::check
# where no {SCHEME} prefix is present.
# -------------------------------------------------------------------------
{
    my $openssl_bin = qx{which openssl 2>/dev/null};
    chomp $openssl_bin;

    my @openssl_probes = (
        [ '-1', '$1$',  'MD5-crypt ($1$)'     ],
        [ '-5', '$5$',  'SHA-256-crypt ($5$)' ],
        [ '-6', '$6$',  'SHA-512-crypt ($6$)' ],
    );

    for my $entry (@openssl_probes) {
        my ($flag, $prefix, $label) = @$entry;

        SKIP: {
            skip "openssl not found in PATH", 3 unless $openssl_bin;

            my $hash = qx{openssl passwd $flag "$password" 2>/dev/null};
            chomp $hash;

            skip "openssl passwd $flag not supported by this openssl build", 3
                unless $hash =~ m{\Q$prefix\E};

            my $result;
            lives_ok {
                $result = OpenXPKI::Password::check($password, $hash);
            } "openssl $label: check runs without exception";

            ok $result, "openssl $label: correct password verifies";

            ok !OpenXPKI::Password::check('wrong password', $hash),
                "openssl $label: wrong password rejected";
        }
    }
}

done_testing();
