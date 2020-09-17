#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );
use File::Temp qw( tempfile );

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;

# Project modules
use lib "$Bin/../lib";

use OpenXPKI::Test;
#use OpenXPKI::Debug; $OpenXPKI::Debug::BITMASK{'OpenXPKI::Server::API2::Plugin::Crypto::password_quality.*'} = 255;

plan tests => 20;

#
# Setup test context
#
my $oxitest = OpenXPKI::Test->new;

my $api = CTX('api2');
my $result;

sub password_ok {
    my ($password, %config) = @_;
    my $errors;
    lives_and {
        $errors = $api->password_quality(password => $password, %config);
        cmp_deeply $errors, [];
    } "valid password $password" or diag explain $errors;
}

sub password_fails {
    my ($password, $expected, %config) = @_;

    lives_and {
        cmp_deeply $api->password_quality(password => $password, %config), supersetof($expected);
    } "invalid password $password ($expected)";
}

my %legacy = (
    min_len => 8,
    max_len => 64,
    min_different_char_groups => 2,
    min_dict_len => 4,
    sequence_len => 4,
);

password_ok "v.s.pwd4oxi", %legacy;

# too short
password_fails "a2b2g9", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_LENGTH_TOO_SHORT", %legacy;

# too long
password_fails "a2b2g9!.45" x 7, "I18N_OPENXPKI_UI_PASSWORD_QUALITY_LENGTH_TOO_LONG", %legacy;

# too less different characters
password_fails "1!111!aaa!!aa", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_DIFFERENT_CHARS", %legacy;

# too less different character groups
password_fails "123456789", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_GROUPS", %legacy;

# contains sequence
password_fails "ab!123456789", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_CONTAINS_SEQUENCE", %legacy;

# repetitive
password_fails "!123aaaabbbbcc", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_REPETITIONS", %legacy;

# repetitive
password_fails "!d.4_SuNset", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_CONTAINS_DICT_WORD", %legacy;

#
# Tests - new algorithms
#
password_ok "v.s.pwd4oxi";
password_ok "!d.4_SuNset";

# top 10k password
password_fails "pineapple1", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_COMMON_PASSWORD";

# dictionary word
password_fails "tRoublEShooting", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_DICT_WORD";
password_fails "tr0ubl3shoot1NG", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_DICT_WORD";
password_fails scalar(reverse("troubleshooting")), "I18N_OPENXPKI_UI_PASSWORD_QUALITY_REVERSED_DICT_WORD";

password_ok "tr0ubl3shoot1NG.";

# is sequence
password_fails "abcdefghijklmnopqr", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_SEQUENCE";

#
# entropy
#
password_fails "abcdefghijklmnopqr", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_INSUFFICIENT_ENTROPY";

my %high_entropy = (
    checks => [ 'entropy' ],
    min_entropy => 200,
);
password_fails "!d.4_SuNset", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_INSUFFICIENT_ENTROPY", %high_entropy;

#
# only one check, custom dictionary
#
# create custom dictionary
my $madeup_dict_word = "!d.4_SuNset";
my ($dict_fh, $dict) = tempfile(UNLINK => 1);
print $dict_fh "$madeup_dict_word\n";
close $dict_fh;

my %one_check = (
    checks => [ 'dict' ],
    dictionaries => [ '/no/file/here', $dict ],
);

password_ok "abcdefghijklmnopqr", %one_check; # should not throw an error as we only check for dictionary words
password_fails $madeup_dict_word, "I18N_OPENXPKI_UI_PASSWORD_QUALITY_DICT_WORD", %one_check;

1;
