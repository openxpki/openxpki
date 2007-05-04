use strict;
use warnings;
use Test::More;
## 2 * number of files

my @files = qw( t/30_dbi/sqlite.db 
                t/30_dbi/sqlite.db._workflow_
                t/30_dbi/sqlite.db._backend_
                t/30_dbi/sqlite.db._log_
);

plan tests => (scalar @files) * 2;

diag "OpenXPKI::Server::DBI Cleanup\n";

foreach my $filename (@files)
{
    ok(! -e $filename || unlink ($filename), 'file does not exist or can be removed');
    ok(! -e $filename, 'file does not exist');
}
1;
