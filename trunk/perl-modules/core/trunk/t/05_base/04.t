## Base module tests
##

use strict;
use warnings;
use Test;

use OpenXPKI qw( convert_date );
use DateTime;

BEGIN { plan tests => 5 };

print STDERR "BASE FUNCTIONS: DATE CONVERSION\n";

my $epoch = 1142434089;
my $dt = DateTime->from_epoch( epoch => $epoch ); 

ok(convert_date(
       { 
	   OUTFORMAT => 'epoch', 
	   DATE      => $dt,
       }),
   $epoch);

ok(convert_date(
       { 
	   OUTFORMAT => 'iso8601', 
	   DATE      => $dt,
       }),
   '2006-03-15T14:48:09');

ok(convert_date(
       { 
	   OUTFORMAT => 'openssltime', 
	   DATE      => $dt,
       }),
   '060315144809Z');

ok(convert_date(
       { 
	   OUTFORMAT => 'terse', 
	   DATE      => $dt,
       }),
   '20060315144809');

ok(convert_date(
       { 
	   OUTFORMAT => 'printable', 
	   DATE      => $dt,
       }),
   '2006-03-15 14:48:09');

       



1;
