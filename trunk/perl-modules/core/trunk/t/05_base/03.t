## Base module tests
##

use strict;
use warnings;
use Test::More;

use File::Temp;

use OpenXPKI;

plan tests => 1;

diag "BASE CONFIG: REPAIR CONFIG\n";

## fix the configuration file if needed
require "t/05_base/fix_config.pl";
ok(1);


1;
