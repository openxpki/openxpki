use strict;
use warnings;
use Test::More;
plan tests => 2;

diag "Cleanup\n";
# FIXME: this does NOT clean up, but do we actually want
# to clean up? We need the DB later for the server start ...
unlink ("t/dbi/sqlite.db");

ok(1);

if (-e "t/dbi/sqlite.db")
{
    ok(0);
} else {
    ok(1);
}

1;
