use strict;
use warnings;
use Data::Dumper;
use Test::More;

plan tests => 21;

note "DATETIME FUNCTIONS: VALIDITY COMPUTATION\n";

use DateTime;
use OpenXPKI::DateTime;

# We choose a reference date that has no leap years around to avoid handling
# the special cases of DateTime's date math magic
my $refdate = DateTime->new( year=>2014, month=>06, day=>15, hour=>12, time_zone => 'UTC' );
my $then;
my $dt;
my $offset;

# Relative date
###########################################################################
my $now = DateTime->now( time_zone => 'UTC' );
$dt = OpenXPKI::DateTime::get_validity( {
	VALIDITY => 365,
	VALIDITYFORMAT => 'days',
} );
$offset = $dt - $now;
if (($now->is_leap_year() && $now->month < 3)
        || ($dt->is_leap_year() && $now->month >= 3)) {
    # if the date in the future is a leap year, and the current month
    # is at least march, the difference will only be 11 months
    # (for example: 01.03.2007 + 365d = 29.02.2008)
    is($offset->in_units('months'), 11, 'get_validity() +365d if leap year');
}
else {
    is($offset->in_units('months'), 12, 'get_validity() +365d if no leap year');
}


$then = $refdate->clone;
$then->add( months => 2);
$dt = OpenXPKI::DateTime::get_validity( {
	REFERENCEDATE => $then,
	VALIDITY => 365,
	VALIDITYFORMAT => 'days',
} );
$offset = $dt - $refdate;
is($offset->in_units('months'), 14, 'get_validity() +365d with reference date');


$dt = OpenXPKI::DateTime::get_validity( {
    REFERENCEDATE => $refdate,
	VALIDITY => -365,
	VALIDITYFORMAT => 'days',
} );
$offset = $dt - $refdate;
is($offset->in_units('months'), -12, 'get_validity() -365d');


$dt = OpenXPKI::DateTime::get_validity( {
    REFERENCEDATE => $refdate,
	VALIDITY => "+01",
	VALIDITYFORMAT => 'relativedate',
} );
$offset = $dt - $refdate;
is($offset->in_units('months'), 12, 'get_validity() relativedate +01');


$dt = OpenXPKI::DateTime::get_validity( {
    REFERENCEDATE => $refdate,
	VALIDITY => "-01",
	VALIDITYFORMAT => 'relativedate',
} );
$offset = $dt - $refdate;
is($offset->in_units('months'), -12, 'get_validity() relativedate -01');


$dt = OpenXPKI::DateTime::get_validity( {
    REFERENCEDATE => $refdate,
	VALIDITY => "+0003",
	VALIDITYFORMAT => 'relativedate',
} );
$offset = $dt - $refdate;
is($offset->in_units('months'), 3, 'get_validity() relativedate +0003');


$dt = OpenXPKI::DateTime::get_validity( {
    REFERENCEDATE => $refdate,
	VALIDITY => "-0003",
	VALIDITYFORMAT => 'relativedate',
} );
$offset = $dt - $refdate;
is($offset->in_units('months'), -3, 'get_validity() relativedate -0003');


$dt = OpenXPKI::DateTime::get_validity( {
    REFERENCEDATE => $refdate,
	VALIDITY => "+000014",
	VALIDITYFORMAT => 'relativedate',
} );
$offset = $dt - $refdate;
is($offset->in_units('days'), 14, 'get_validity() relativedate +000014');


$dt = OpenXPKI::DateTime::get_validity( {
    REFERENCEDATE => $refdate,
	VALIDITY => "-000014",
	VALIDITYFORMAT => 'relativedate',
} );
$offset = $dt - $refdate;
is($offset->in_units('days'), -14, 'get_validity() relativedate -000014');


$dt = OpenXPKI::DateTime::get_validity( {
    REFERENCEDATE => $refdate,
	VALIDITY => "+00000012",
	VALIDITYFORMAT => 'relativedate',
} );
$offset = $dt - $refdate;
is($offset->in_units('hours'), 12, 'get_validity() relativedate +00000012');


$dt = OpenXPKI::DateTime::get_validity( {
    REFERENCEDATE => $refdate,
	VALIDITY => "-00000012",
	VALIDITYFORMAT => 'relativedate',
} );
$offset = $dt - $refdate;
is($offset->in_units('hours'), -12, 'get_validity() relativedate +00000012');


$dt = OpenXPKI::DateTime::get_validity( {
    REFERENCEDATE => $refdate,
	VALIDITY => "+0000000030",
	VALIDITYFORMAT => 'relativedate',
}) ;
$offset = $dt - $refdate;
is($offset->in_units('minutes'), 30, 'get_validity() relativedate +0000000030');


$dt = OpenXPKI::DateTime::get_validity( {
    REFERENCEDATE => $refdate,
	VALIDITY => "-0000000030",
	VALIDITYFORMAT => 'relativedate',
} );
$offset = $dt - $refdate;
is($offset->in_units('minutes'), -30, 'get_validity() relativedate +0000000030');


# Absolute date
###########################################################################
$dt = OpenXPKI::DateTime::get_validity( {
	VALIDITY => "2006",
	VALIDITYFORMAT => 'absolutedate',
} );
is OpenXPKI::DateTime::convert_date( { DATE => $dt }), "2006-01-01T00:00:00",
    'get_validity() absolutedate 2006';


$dt = OpenXPKI::DateTime::get_validity( {
	VALIDITY => "200603",
	VALIDITYFORMAT => 'absolutedate',
} );
is OpenXPKI::DateTime::convert_date({ DATE => $dt }), "2006-03-01T00:00:00",
    'get_validity() absolutedate 200603';


$dt = OpenXPKI::DateTime::get_validity( {
	VALIDITY => "20060316",
	VALIDITYFORMAT => 'absolutedate',
} );
is OpenXPKI::DateTime::convert_date({ DATE => $dt }), "2006-03-16T00:00:00",
    'get_validity() absolutedate 20060316';

$dt = OpenXPKI::DateTime::get_validity( {
	VALIDITY => "2006031618",
	VALIDITYFORMAT => 'absolutedate',
} );
is OpenXPKI::DateTime::convert_date({ DATE => $dt }), "2006-03-16T18:00:00",
    'get_validity() absolutedate 20060318';

$dt = OpenXPKI::DateTime::get_validity( {
	VALIDITY => "200603161821",
	VALIDITYFORMAT => 'absolutedate',
} );
is OpenXPKI::DateTime::convert_date({ DATE => $dt }), "2006-03-16T18:21:00",
    'get_validity() absolutedate 2006031821';


$dt = OpenXPKI::DateTime::get_validity( {
	VALIDITY => "20060316182157",
	VALIDITYFORMAT => 'absolutedate',
} );
is OpenXPKI::DateTime::convert_date({ DATE => $dt }), "2006-03-16T18:21:57",
    'get_validity() absolutedate 200603182157';


# Autodetect
###########################################################################
$dt = OpenXPKI::DateTime::get_validity( {
    REFERENCEDATE => $refdate,
    VALIDITY => "-0000000030",
    VALIDITYFORMAT => 'detect',
} );
$offset = $dt - $refdate;
is $offset->in_units('minutes'), -30, 'autodetect relativedate';


$dt = OpenXPKI::DateTime::get_validity( {
    VALIDITY => "2006",
    VALIDITYFORMAT => 'detect',
} );
is OpenXPKI::DateTime::convert_date({ DATE => $dt }), "2006-01-01T00:00:00",
    'autodetect absolutedate';

1;
