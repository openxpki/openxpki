## Base module tests
use strict;
use warnings;

use FindBin qw( $Bin );

use Test::More;
use Test::Exception;
use Test::Deep;

use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init($FATAL);

use OpenXPKI::i18n;

plan tests => 6;

my $orig = 'I18N_OPENXPKI_UI_TEST';
my $de = "special % \\ \" ' ! \x{00E4}\x{00F6}\x{00FC}";

lives_ok {
    OpenXPKI::i18n::set_locale_prefix($Bin);
} "set locale path to $Bin";

my $language;

lives_and {
    $language = "C";
    ok OpenXPKI::i18n::set_language($language);
} 'set language to C';

lives_and {
    $language = "de_DE";
    ok OpenXPKI::i18n::set_language($language);
} 'set language to de_DE';

lives_and {
    is OpenXPKI::i18n::i18nGettext($orig), $de;
} 'translate single string - i18nGettext()';

lives_and {
    is Encode::decode('UTF-8', OpenXPKI::i18n::i18nTokenizer("$orig blah $orig .")), "$de blah $de .";
} 'translate string with multiple i18n tokens - i18nTokenizer()';

# translation of deep/nested structures
my $struct = {
    top => $orig,
    array => [ $orig, 'blue', $orig ],
    hash => {
        one => [ 'pre', $orig ],
        two => $orig,
    }
};
my $struct_de = {
    top => $de,
    array => [ $de, 'blue', $de ],
    hash => {
        one => [ 'pre', $de ],
        two => $de,
    }
};
lives_and {
    cmp_deeply OpenXPKI::i18n::i18n_walk($struct), $struct_de;
} 'translate nested structure - i18n_walk()';

1;
