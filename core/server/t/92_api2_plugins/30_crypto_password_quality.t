#!/usr/bin/perl
use strict;
use warnings;
# prevent "Wide character in print at /usr/local/share/perl/5.20.2/Test2/Formatter/TAP.pm line 125."
use open ':std', ':encoding(UTF-8)';

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


plan tests => 31;


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
    my $errors;
    lives_and {
        $errors = $api->password_quality(password => $password, %config);
        cmp_deeply $errors, [ $expected ];
    } "invalid password $password ($expected)" or diag explain $errors;
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
password_fails "a2.2g9", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_LENGTH_TOO_SHORT", %legacy;

# too long
password_fails "a2b2g9!.45lkjsoiwmeaxotimoiwejas,odij,fxasdoifxjoweasdasdlkjlasjkdlkjlasudoiwquouq2e29", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_LENGTH_TOO_LONG", %legacy;

# too less different characters
password_fails "1!111!aaa!!aa", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_DIFFERENT_CHARS", %legacy;

# too less different character groups
password_fails "58232305623", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_GROUPS", %legacy;

# contains sequence
password_fails "ab!123456789", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_CONTAINS_SEQUENCE", %legacy;

# repetitive
password_fails "!123aaaabbbbcc", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_REPETITIONS", %legacy;

# repetitive
password_fails "!d.4_SuNset", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_CONTAINS_DICT_WORD", %legacy;

my %legacy_2 = (
    min_len => 10,
    max_len => 128,
    min_different_char_groups => 3,
);

password_fails "+vanzDXC", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_LENGTH_TOO_SHORT", %legacy_2;
password_fails "9Uv3dFpH", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_LENGTH_TOO_SHORT", %legacy_2;
password_fails "JEu8Zqlo", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_LENGTH_TOO_SHORT", %legacy_2;

#
# Tests - new algorithms
#
password_ok "v.s.pwd4oxi";
password_ok "!d.4_SuNset";

# top 10k password
password_fails "pineapple1", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_COMMON_PASSWORD", checks => [ 'common' ];

# dictionary word
password_fails "tRoublEShooting", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_DICT_WORD";
password_fails "tr0ubl3shoot1NG", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_DICT_WORD";
password_fails scalar(reverse("troubleshooting")), "I18N_OPENXPKI_UI_PASSWORD_QUALITY_REVERSED_DICT_WORD", checks => [ 'dict' ];

password_ok "tr0ubl3shoot1NG.";

# is sequence
password_fails "abcdefghijklmnopqr", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_SEQUENCE", checks => [ 'sequence' ];

#
# entropy
#
password_fails "abcfedghijklmnopqr", "I18N_OPENXPKI_UI_PASSWORD_QUALITY_INSUFFICIENT_ENTROPY";

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

# ############################################################################
# Low level checks
# ############################################################################

use OpenXPKI::Server::API2::Plugin::Crypto::password_quality::Validate;
use Moose::Meta::Class;

my $metaclass = Moose::Meta::Class->create(
    ScreenLogger => (
        methods => {
            map { $_ => sub { shift; note shift } } qw( trace debug info warn error fatal )
        }
    )
);
my $v = OpenXPKI::Server::API2::Plugin::Crypto::password_quality::Validate->new(
    log => $metaclass->new_object,
    checks => [ 'mixedcase', 'digits', 'dict', 'entropy' ],
);

# error messages sorted by check complexity score
is $v->is_valid("lame"), 0, "Invalid password 'lame'";
cmp_deeply
    [ $v->error_messages ],
    [ qw(
        I18N_OPENXPKI_UI_PASSWORD_QUALITY_DIGITS
        I18N_OPENXPKI_UI_PASSWORD_QUALITY_MIXED_CASE
        I18N_OPENXPKI_UI_PASSWORD_QUALITY_DICT_WORD
        I18N_OPENXPKI_UI_PASSWORD_QUALITY_INSUFFICIENT_ENTROPY
    ) ],
    "Reports only errors of lowest complex checks";

# error messages of lowest complex checks
cmp_deeply
    [ $v->first_error_messages ],
    [ qw(
        I18N_OPENXPKI_UI_PASSWORD_QUALITY_DIGITS
        I18N_OPENXPKI_UI_PASSWORD_QUALITY_MIXED_CASE
    ) ],
    "first_error_messages() only fetches errors of lowest complex checks" or diag explain $v->first_error_messages;

# entropy comparisons
sub is_first_entropy_higher {
    my ($p1, $p2) = @_;
    my $e1 = $v->_calc_entropy($p1);
    my $e2 = $v->_calc_entropy($p2);
    ok $e1 > $e2, sprintf("entropy of '%s' > entropy of '%s'\n", $p1, $p2);
}
is_first_entropy_higher('.Sec$p4ss:l', 'pass123');
is_first_entropy_higher('tr0ubl3shoot1NG', 'troubleshooting');
is_first_entropy_higher('2_h_p4sec.online!', '.12!5%%%asdoiu');
is_first_entropy_higher("\x{91C6}qwertz!", "\x{91C6}");
is_first_entropy_higher('dgq.123!!e', 'abc.123!!e');

1;
