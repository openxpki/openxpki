use strict;
use warnings;
use Test;
use File::Spec;

BEGIN { plan tests => 2 };

print STDERR "Cleanup\n";

ok(system('rm -rf t/40_workflow/db/*_history/') == 0);
ok(system('rm -f t/40_workflow/db/*_workflow') == 0);

1;
