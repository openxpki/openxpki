use strict;
use warnings;
use Test;
use File::Spec;

BEGIN { plan tests => 4 };

print STDERR "Cleanup\n";

ok(system('rm -rf t/40_workflow/db/*_history/') == 0);
ok(system('rm -f t/40_workflow/db/*_workflow') == 0);

ok(unlink ("t/40_workflow/sqlite.db"));
ok(unlink ("t/40_workflow/sqlite_workflow.db"));

1;
