use strict;
use warnings;
use Data::Dumper;
use Test;

BEGIN { plan tests => 19 };

print STDERR "DATETIME FUNCTIONS: VALIDITY COMPUTATION\n";

use DateTime;
use OpenXPKI::DateTime;

my $now;
my $then;
my $dt;
my $offset;

###########################################################################
$now = DateTime->now( time_zone => 'UTC' ); 
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => 365,
	VALIDITYFORMAT => 'days',
    });

$offset = $dt - $now;
ok($offset->in_units('months'), 12);

###########################################################################
$then = DateTime->now( time_zone => 'UTC' );
$then->add( months => 2);
$dt = OpenXPKI::DateTime::get_validity(
    {
	REFERENCEDATE => $then,
	VALIDITY => 365,
	VALIDITYFORMAT => 'days',
    });

$offset = $dt - $now;
ok($offset->in_units('months'), 14);


###########################################################################
$now = DateTime->now( time_zone => 'UTC' ); 
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => -365,
	VALIDITYFORMAT => 'days',
    });

$offset = $dt - $now;
ok($offset->in_units('months'), -12);


###########################################################################
$now = DateTime->now( time_zone => 'UTC' ); 
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "+01",
	VALIDITYFORMAT => 'relativedate',
    });

$offset = $dt - $now;
ok($offset->in_units('months'), 12);


###########################################################################
$now = DateTime->now( time_zone => 'UTC' ); 
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "-01",
	VALIDITYFORMAT => 'relativedate',
    });

$offset = $dt - $now;
ok($offset->in_units('months'), -12);


###########################################################################
$now = DateTime->now( time_zone => 'UTC' ); 
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "+0003",
	VALIDITYFORMAT => 'relativedate',
    });

$offset = $dt - $now;
ok($offset->in_units('months'), 3);


###########################################################################
$now = DateTime->now( time_zone => 'UTC' ); 
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "-0003",
	VALIDITYFORMAT => 'relativedate',
    });

$offset = $dt - $now;
ok($offset->in_units('months'), -3);


###########################################################################
$now = DateTime->now( time_zone => 'UTC' ); 
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "+000014",
	VALIDITYFORMAT => 'relativedate',
    });

$offset = $dt - $now;
ok($offset->in_units('days'), 14);


###########################################################################
$now = DateTime->now( time_zone => 'UTC' ); 
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "-000014",
	VALIDITYFORMAT => 'relativedate',
    });

$offset = $dt - $now;
ok($offset->in_units('days'), -14);


###########################################################################
$now = DateTime->now( time_zone => 'UTC' ); 
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "+00000012",
	VALIDITYFORMAT => 'relativedate',
    });

$offset = $dt - $now;
ok($offset->in_units('hours'), 12);


###########################################################################
$now = DateTime->now( time_zone => 'UTC' ); 
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "-00000012",
	VALIDITYFORMAT => 'relativedate',
    });

$offset = $dt - $now;
ok($offset->in_units('hours'), -12);

###########################################################################
$now = DateTime->now( time_zone => 'UTC' ); 
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "+0000000030",
	VALIDITYFORMAT => 'relativedate',
    });

$offset = $dt - $now;
ok($offset->in_units('minutes'), 30);


###########################################################################
$now = DateTime->now( time_zone => 'UTC' ); 
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "-0000000030",
	VALIDITYFORMAT => 'relativedate',
    });

$offset = $dt - $now;
ok($offset->in_units('minutes'), -30);




###########################################################################
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "2006",
	VALIDITYFORMAT => 'absolutedate',
    });

ok(OpenXPKI::DateTime::convert_date(
   {
       DATE => $dt,
   }),
   "2006-01-01T00:00:00");


###########################################################################
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "200603",
	VALIDITYFORMAT => 'absolutedate',
    });

ok(OpenXPKI::DateTime::convert_date(
   {
       DATE => $dt,
   }),
   "2006-03-01T00:00:00");


###########################################################################
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "20060316",
	VALIDITYFORMAT => 'absolutedate',
    });

ok(OpenXPKI::DateTime::convert_date(
   {
       DATE => $dt,
   }),
   "2006-03-16T00:00:00");

###########################################################################
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "2006031618",
	VALIDITYFORMAT => 'absolutedate',
    });

ok(OpenXPKI::DateTime::convert_date(
   {
       DATE => $dt,
   }),
   "2006-03-16T18:00:00");

###########################################################################
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "200603161821",
	VALIDITYFORMAT => 'absolutedate',
    });

ok(OpenXPKI::DateTime::convert_date(
   {
       DATE => $dt,
   }),
   "2006-03-16T18:21:00");


###########################################################################
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "20060316182157",
	VALIDITYFORMAT => 'absolutedate',
    });

ok(OpenXPKI::DateTime::convert_date(
   {
       DATE => $dt,
   }),
   "2006-03-16T18:21:57");



1;
