## Base module tests
##

use strict;
use warnings;
use Test::More;

use File::Temp;

use OpenXPKI::FileUtils;

plan tests => 2;

note "BASE FUNCTIONS: FILE OPERATIONS\n";

my (undef, $tmpfile) = File::Temp::tempfile(OPEN => 0);
unlink $tmpfile;

# create 1 MByte of temporary data
my $kbytes = 1 * 1024;
my $data = pack "C*", (0 .. 255) x ($kbytes * 4);

my $fu = OpenXPKI::FileUtils->new();
ok $fu->write_file({FILENAME => $tmpfile, CONTENT  => $data}), "write temporary file";
is $fu->read_file($tmpfile), $data, "file matches original data";

unlink $tmpfile;

1;
