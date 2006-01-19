## Base module tests
##

use strict;
use warnings;
use Test;

use File::Temp;

use OpenXPKI;

BEGIN { plan tests => 1 };

print STDERR "BASE CONFIG: REPAIR CONFIG\n";

## fix the configuration file if needed
require "t/05_base/fix_config.pl";
ok(1);


1;
