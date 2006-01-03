## Base module tests
##

use strict;
use warnings;
use Test;

use File::Temp;

use OpenXPKI;

BEGIN { plan tests => 2 };

print STDERR "BASE FUNCTIONS: FILE OPERATIONS\n";

my $tmpfile = File::Temp::mktemp("tmpfileXXXXX");

# create 1 MByte of temporary data
my $kbytes = 1 * 1024;
my $data = pack "C*", (0 .. 255) x ($kbytes * 4);

ok(OpenXPKI->write_file( FILENAME => $tmpfile,
			 CONTENT  => $data ),
   1,
   "Could not write temporary file");

ok(OpenXPKI->read_file($tmpfile) eq $data,
   1,
   "Data read from file does not match original data");

unlink $tmpfile;


1;
