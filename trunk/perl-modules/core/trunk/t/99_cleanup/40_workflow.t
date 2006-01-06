use strict;
use warnings;
use Test;
BEGIN { plan tests => 2 };

print STDERR "OpenXPKI::Server::Workflow Cleanup\n";

unlink ("t/40_workflow/sqlite.db");
unlink ("t/40_workflow/sqlite_workflow.db");

ok(1);

if (-e "t/30_dbi/sqlite.db"
   || -e "t/30_dbi/sqlite_workflow.db")
{
    ok(0);
} else {
    ok(1);
}

1;
