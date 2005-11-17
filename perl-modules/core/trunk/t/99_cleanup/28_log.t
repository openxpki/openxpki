use strict;
use warnings;
use Test;
BEGIN { plan tests => 2 };

print STDERR "OpenXPKI::Server::Log Cleanup\n";

unlink ("t/28_log/sqlite.db");
unlink ("t/28_log/sqlite_log.db");
unlink ("t/28_log/stderr.log");

ok(1);

if (-e "t/28_log/sqlite.db" or
    -e "t/28_log/sqlite_log.db" or
    -e "t/28_log/stderr.log")
{
    ok(0);
} else {
    ok(1);
}

1;
