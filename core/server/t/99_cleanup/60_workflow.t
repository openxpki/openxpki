use strict;
use warnings;
use Test::More;

my @files = (
            "t/var/openxpki/connector.log",
            "t/var/openxpki/stderr.log",
            "t/var/openxpki/openxpkid.pid",
            "t/var/openxpki/openxpki.socket",
            );

## 2 * number of files
plan tests => (scalar @files) * 2;

note "OpenXPKI::Server Cleanup";

foreach my $filename (@files)
{
    ok(! -e $filename || unlink ($filename), 'file does not exist or can be removed');
    ok(! -e $filename, 'file does not exist');
}

1;


