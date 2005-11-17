use strict;
use warnings;
use Test;
BEGIN { plan tests => 2 };

print STDERR "OpenXPKI::Server::DBI Cleanup\n";

unlink ("t/30_dbi/sqlite.db");

ok(1);

if (-e "t/30_dbi/sqlite.db")
{
    ok(0);
} else {
    ok(1);
}

1;
