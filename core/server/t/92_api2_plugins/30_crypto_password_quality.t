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

# Project modules
use lib "$Bin/../lib";

use OpenXPKI::Test;
#use OpenXPKI::Debug; $OpenXPKI::Debug::BITMASK{'OpenXPKI::Server::API2::Plugin::Crypto::password_quality.*'} = 255;

plan tests => 15;

#
# Setup test context
#
my $oxitest = OpenXPKI::Test->new;

my $api = CTX('api2');
my $result;

sub password_ok {
    my ($password, %config) = @_;

    lives_and {
        cmp_deeply $api->password_quality(password => $password, %config), [];
    } "valid password $password";
}

sub password_fails {
    my ($password, $expected, %config) = @_;

    lives_and {
        cmp_deeply $api->password_quality(password => $password, %config), supersetof($expected);
    } "invalid password $password ($expected)";
}

my %legacy_conf = (
    min_len => 8,
    max_len => 64,
    min_different_char_groups => 2,
    min_dict_len => 4,
    sequence_len => 4,
);

password_ok "v.s.pwd4oxi", %legacy_conf;

# too short
password_fails "a2b2g9", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_LENGTH_TOO_SHORT", %legacy_conf;

# too long
password_fails "a2b2g9!.45" x 7, "I18N_OPENXPKI_UI_PASSWORD_QUALITY_LENGTH_TOO_LONG", %legacy_conf;

# too less different characters
password_fails "1!111!aaa!!aa", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_DIFFERENT_CHARS", %legacy_conf;

# too less different character groups
password_fails "123456789", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_GROUPS", %legacy_conf;

# contains sequence
password_fails "ab!123456789", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_CONTAINS_SEQUENCE", %legacy_conf;

# repetitive
password_fails "!123aaaabbbbcc", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_REPETITIONS", %legacy_conf;

# repetitive
password_fails "!d.4_SuNset", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_CONTAINS_DICT_WORD", %legacy_conf;

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

# is sequence
password_fails "abcdefghijklmnopqr", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_SEQUENCE";

1;
