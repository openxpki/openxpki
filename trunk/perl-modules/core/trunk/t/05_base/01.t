## Base module tests
##

use strict;
use warnings;
use Test;

use OpenXPKI::i18n;

BEGIN { plan tests => 2 };

print STDERR "BASE FUNCTIONS: LANGUAGE HANDLING\n";

## WARNING: get_language is only implemented in the session class

my $language;
#ok(OpenXPKI::get_language(), "", "Incorrect default language settings");

$language = "C";
ok(OpenXPKI::i18n::set_language($language));
#ok(OpenXPKI::get_language(), $language, "Language settings lost");

$language = "de-de";
ok(OpenXPKI::i18n::set_language($language));
#ok(OpenXPKI::get_language(), $language, "Language settings lost");

1;
