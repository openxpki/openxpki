use strict;
use warnings;
use Test;

my @files = (
             't/65_ui/client.in',
             't/65_ui/server.in',
            );

## 2 * number of file
BEGIN { plan tests => 4 };

print STDERR "OpenXPKI::UI (Transport) Cleanup\n";

foreach my $filename (@files)
{
    ok(not -e $filename or unlink ($filename));
    ok(not -e $filename);
}

1;
