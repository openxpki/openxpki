## Base module tests
##

use strict;
use warnings;
use Test::More;

use Log::Log4perl qw( :easy );
Log::Log4perl->easy_init($FATAL);

use OpenXPKI::i18n;

plan tests => 2;

diag "BASE FUNCTIONS: LANGUAGE HANDLING\n" if $ENV{VERBOSE};

my $language;

$language = "C";
ok(OpenXPKI::i18n::set_language($language), 'Setting language to C succeeds');

$language = "en_US";
ok(OpenXPKI::i18n::set_language($language), 'Setting language to en_US succeeds');

1;
