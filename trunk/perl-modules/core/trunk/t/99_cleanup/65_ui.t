use strict;
use warnings;
use Test::More;

my @files = (
             't/65_ui/client.in',
             't/65_ui/server.in',
            );

## 2 * number of file
plan tests => (scalar @files) * 2;

diag "OpenXPKI:UI (Transport) Cleanup\n";

foreach my $filename (@files)
{
    ok(! -e $filename || unlink ($filename), 'file does not exist or can be removed');
    ok(! -e $filename, 'file does not exist');
}
1;
