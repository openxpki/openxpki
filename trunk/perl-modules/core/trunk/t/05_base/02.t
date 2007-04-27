## Base module tests
##

use strict;
use warnings;
use Test::More;

use File::Temp;

use OpenXPKI;

plan tests => 2;

diag "BASE FUNCTIONS: FILE OPERATIONS\n";

my $tmpfile = File::Temp::mktemp("tmpfileXXXXX");

# create 1 MByte of temporary data
my $kbytes = 1 * 1024;
my $data = pack "C*", (0 .. 255) x ($kbytes * 4);

ok(OpenXPKI->write_file( FILENAME => $tmpfile,
			 CONTENT  => $data ),
   "Could not write temporary file");

is(OpenXPKI->read_file($tmpfile),
   $data,
   "Data read from file does not match original data");

unlink $tmpfile;


1;
