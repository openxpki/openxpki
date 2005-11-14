use strict;
use warnings;
use Test;
BEGIN { plan tests => 2 };

print STDERR "Cleanup\n";

unlink ("t/dbi/sqlite.db");

ok(1);

if (-e "t/dbi/sqlite.db")
{
    ok(0);
} else {
    ok(1);
}

1;
