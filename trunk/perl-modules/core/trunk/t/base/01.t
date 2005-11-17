## Base module tests
##

use strict;
use warnings;
use Test;

use OpenXPKI;

BEGIN { plan tests => 3 };

print STDERR "BASE FUNCTIONS: LANGUAGE HANDLING\n";

my $language;
ok(OpenXPKI::get_language(), "", "Incorrect default language settings");

$language = "C";
OpenXPKI::set_language($language);
ok(OpenXPKI::get_language(), $language, "Language settings lost");

$language = "de-de";
OpenXPKI::set_language($language);
ok(OpenXPKI::get_language(), $language, "Language settings lost");



1;
