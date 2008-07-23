## Base module tests
##

use strict;
use warnings;
use Test::More;

use OpenXPKI::i18n;

plan tests => 2;

diag "BASE FUNCTIONS: LANGUAGE HANDLING\n";

my $language;

$language = "C";
ok(OpenXPKI::i18n::set_language($language), 'Setting language to C succeeds');

$language = "de_DE";
ok(OpenXPKI::i18n::set_language($language), 'Setting language to de_DE succeeds');

1;
