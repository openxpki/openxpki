use strict;
use warnings;
use Data::Dumper;
use Test::More;

plan tests => 19;

diag "DATETIME FUNCTIONS: VALIDITY COMPUTATION\n";

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
if (($now->is_leap_year() && $now->month < 3)
        || ($dt->is_leap_year() && $now->month >= 3)) {
    # if the date in the future is a leap year, and the current month
    # is at least march, the difference will only be 11 months
    # (for example: 01.03.2007 + 365d = 29.02.2008)
    is($offset->in_units('months'), 11, 'get_validity() calculating with months with leap years works');
}
else {
    is($offset->in_units('months'), 12, 'get_validity() calculating with months without leap years works');
}

###########################################################################
$then = DateTime->now( time_zone => 'UTC' );
$then->add( months => 2);
$dt = OpenXPKI::DateTime::get_validity(
    {
	REFERENCEDATE => $then,
	VALIDITY => 365,
	VALIDITYFORMAT => 'days',
    }
);

$offset = $dt - $now;
if (($then->is_leap_year() && $then->month < 3) || ($dt->is_leap_year() && $then->month >= 5)) {
    # cf above
    is($offset->in_units('months'), 13, 'get_validity() + 2m with leap years');
}
else {
    is($offset->in_units('months'), 14, 'get_validity() + 2m w/o leap years');
}

###########################################################################
$now = DateTime->now( time_zone => 'UTC' ); 
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => -365,
	VALIDITYFORMAT => 'days',
    });

$offset = $dt - $now;
if (($now->is_leap_year() && $now->month >= 3) || ($dt->is_leap_year() && $dt->month < 3)) {
    is($offset->in_units('months'), -11, 'get_validity() -365d with leap years');
}
else {
    is($offset->in_units('months'), -12, 'get_validity() -365d w/o leap years');
}


###########################################################################
$now = DateTime->now( time_zone => 'UTC' ); 
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "+01",
	VALIDITYFORMAT => 'relativedate',
    });

$offset = $dt - $now;
is($offset->in_units('months'), 12, 'get_validity() relativedate +01');


###########################################################################
$now = DateTime->now( time_zone => 'UTC' ); 
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "-01",
	VALIDITYFORMAT => 'relativedate',
    });

$offset = $dt - $now;
is($offset->in_units('months'), -12, 'get_validity() relativedate -01');


###########################################################################
$now = DateTime->now( time_zone => 'UTC' ); 
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "+0003",
	VALIDITYFORMAT => 'relativedate',
    });

$offset = $dt - $now;
is($offset->in_units('months'), 3, 'get_validity() relativedate +0003');


###########################################################################
$now = DateTime->now( time_zone => 'UTC' ); 
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "-0003",
	VALIDITYFORMAT => 'relativedate',
    });

$offset = $dt - $now;
is($offset->in_units('months'), -3, 'get_validity() relativedate -0003');


###########################################################################
$now = DateTime->now( time_zone => 'UTC' ); 
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "+000014",
	VALIDITYFORMAT => 'relativedate',
    });

$offset = $dt - $now;
is($offset->in_units('days'), 14, 'get_validity() relativedate +000014');


###########################################################################
$now = DateTime->now( time_zone => 'UTC' ); 
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "-000014",
	VALIDITYFORMAT => 'relativedate',
    });

$offset = $dt - $now;
is($offset->in_units('days'), -14, 'get_validity() relativedate -000014');


###########################################################################
$now = DateTime->now( time_zone => 'UTC' ); 
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "+00000012",
	VALIDITYFORMAT => 'relativedate',
    });

$offset = $dt - $now;
is($offset->in_units('hours'), 12, 'get_validity() relativedate +00000012');


###########################################################################
$now = DateTime->now( time_zone => 'UTC' ); 
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "-00000012",
	VALIDITYFORMAT => 'relativedate',
    });

$offset = $dt - $now;
is($offset->in_units('hours'), -12, 'get_validity() relativedate +00000012');

###########################################################################
$now = DateTime->now( time_zone => 'UTC' ); 
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "+0000000030",
	VALIDITYFORMAT => 'relativedate',
    });

$offset = $dt - $now;
is($offset->in_units('minutes'), 30, 'get_validity() relativedate +0000000030');


###########################################################################
$now = DateTime->now( time_zone => 'UTC' ); 
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "-0000000030",
	VALIDITYFORMAT => 'relativedate',
    });

$offset = $dt - $now;
is($offset->in_units('minutes'), -30, 'get_validity() relativedate +0000000030');




###########################################################################
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "2006",
	VALIDITYFORMAT => 'absolutedate',
    });

is(OpenXPKI::DateTime::convert_date(
   {
       DATE => $dt,
   }),
   "2006-01-01T00:00:00", 'get_validity() absolutedate 2006');


###########################################################################
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "200603",
	VALIDITYFORMAT => 'absolutedate',
    });

is(OpenXPKI::DateTime::convert_date(
   {
       DATE => $dt,
   }),
   "2006-03-01T00:00:00", 'get_validity() absolutedate 200603');


###########################################################################
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "20060316",
	VALIDITYFORMAT => 'absolutedate',
    });

is(OpenXPKI::DateTime::convert_date(
   {
       DATE => $dt,
   }),
   "2006-03-16T00:00:00", 'get_validity() absolutedate 20060316');

###########################################################################
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "2006031618",
	VALIDITYFORMAT => 'absolutedate',
    });

is(OpenXPKI::DateTime::convert_date(
   {
       DATE => $dt,
   }),
   "2006-03-16T18:00:00", 'get_validity() absolutedate 20060318');

###########################################################################
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "200603161821",
	VALIDITYFORMAT => 'absolutedate',
    });

is(OpenXPKI::DateTime::convert_date(
   {
       DATE => $dt,
   }),
   "2006-03-16T18:21:00", 'get_validity() absolutedate 2006031821');


###########################################################################
$dt = OpenXPKI::DateTime::get_validity(
    {
	VALIDITY => "20060316182157",
	VALIDITYFORMAT => 'absolutedate',
    });

is(OpenXPKI::DateTime::convert_date(
   {
       DATE => $dt,
   }),
   "2006-03-16T18:21:57", 'get_validity() absolutedate 200603182157');



1;
