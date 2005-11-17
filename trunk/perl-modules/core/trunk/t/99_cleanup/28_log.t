use strict;
use warnings;
use Test;

my @files = (
             "t/28_log/sqlite.db",
             "t/28_log/sqlite_log.db",
             "t/28_log/stderr.log",
            );
BEGIN { plan tests => 6 };

print STDERR "OpenXPKI::Server::Log Cleanup\n";

foreach my $filename (@files)
{
    ok(not -e $filename or unlink ($filename));
    ok(not -e $filename);
}

1;
