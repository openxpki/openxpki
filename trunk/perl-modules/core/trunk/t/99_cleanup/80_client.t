use strict;
use warnings;
use Test;

my @files = (
             't/80_client/cli.stderr',
             't/80_client/cli.stdout',
            );

## 2 * number of file
BEGIN { plan tests => 4 };

print STDERR "OpenXPKI::Client::CLI Cleanup\n";

foreach my $filename (@files)
{
    ok(not -e $filename or unlink ($filename));
    ok(not -e $filename);
}

1;
