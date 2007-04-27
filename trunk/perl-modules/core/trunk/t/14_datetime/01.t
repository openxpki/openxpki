## Base module tests
##

use strict;
use warnings;
use Test::More;

use OpenXPKI::DateTime;
use DateTime;

plan tests => 5;

diag "DATETIME FUNCTIONS: DATE CONVERSION\n";

my $epoch = 1142434089;
my $dt = DateTime->from_epoch( epoch => $epoch ); 

is(OpenXPKI::DateTime::convert_date(
       { 
	   OUTFORMAT => 'epoch', 
	   DATE      => $dt,
       }),
   $epoch, 'convert date to epoch works');

is(OpenXPKI::DateTime::convert_date(
       { 
	   OUTFORMAT => 'iso8601', 
	   DATE      => $dt,
       }),
   '2006-03-15T14:48:09', 'convert date to iso8601 works');

is(OpenXPKI::DateTime::convert_date(
       { 
	   OUTFORMAT => 'openssltime', 
	   DATE      => $dt,
       }),
   '060315144809Z', 'convert date to openssltime works');

is(OpenXPKI::DateTime::convert_date(
       { 
	   OUTFORMAT => 'terse', 
	   DATE      => $dt,
       }),
   '20060315144809', 'convert date to terse works');

is(OpenXPKI::DateTime::convert_date(
       { 
	   OUTFORMAT => 'printable', 
	   DATE      => $dt,
       }),
   '2006-03-15 14:48:09', 'convert date to printable works');

1;
