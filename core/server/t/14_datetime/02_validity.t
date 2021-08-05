use strict;
use warnings;

# CPAN modules
use Test::More;
use Test::Exception;
use DateTime;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ENV{TEST_VERBOSE} ? $ERROR : $OFF);


plan tests => 23;


use_ok 'OpenXPKI::DateTime';

# We choose a reference date that has no leap years around to avoid handling
# the special cases of DateTime's date math magic
my $refdate = DateTime->new( year=>2014, month=>06, day=>15, hour=>12, time_zone => 'UTC' );
my $then;
my $dt;
my $offset;

# Relative date
###########################################################################

sub is_date($$$$$) {
    my ($format, $validity, $offset_units, $expected, $test_name) = @_;

    lives_and {
        my $dt = OpenXPKI::DateTime::get_validity( {
            REFERENCEDATE => $refdate,
            VALIDITY => $validity,
            VALIDITYFORMAT => $format,
        } );
        my $offset = $dt - $refdate;
        is $offset->in_units($offset_units), $expected, $test_name;
    };
}

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


is_date days => -365, months => -12, 'get_validity() -365d';
is_date relativedate => '+01',         months =>  12, 'get_validity() relativedate +01';
is_date relativedate => '-01',         months => -12, 'get_validity() relativedate -01';
is_date relativedate => '+0003',       months =>  3, 'get_validity() relativedate +0003';
is_date relativedate => '-0003',       months => -3, 'get_validity() relativedate -0003';
is_date relativedate => '+000014',     days =>  14, 'get_validity() relativedate +000014';
is_date relativedate => '-000014',     days => -14, 'get_validity() relativedate -000014';
is_date relativedate => '+00000012',   hours =>  12, 'get_validity() relativedate +00000012';
is_date relativedate => '-00000012',   hours => -12, 'get_validity() relativedate -00000012';
is_date relativedate => '+0000000030', minutes =>  30, 'get_validity() relativedate +0000000030';
is_date relativedate => '-0000000030', minutes => -30, 'get_validity() relativedate -0000000030';

throws_ok {
    OpenXPKI::DateTime::get_validity( {
        REFERENCEDATE => $refdate,
        VALIDITY => "+0",
        VALIDITYFORMAT => 'relativedate',
    } );
} qr/I18N_OPENXPKI_DATETIME_GET_VALIDITY_INVALID_VALIDITY/;

# Absolute date
###########################################################################

sub is_absdate($$$) {
    my ($validity, $expected, $test_name) = @_;

    lives_and {
        my $dt = OpenXPKI::DateTime::get_validity( {
            VALIDITY => $validity,
            VALIDITYFORMAT => 'absolutedate',
        } );
        is OpenXPKI::DateTime::convert_date( { DATE => $dt }), $expected, $test_name;
    };
}

is_absdate '2006',           "2006-01-01T00:00:00", 'get_validity() absolutedate 2006';
is_absdate "200603",         "2006-03-01T00:00:00", 'get_validity() absolutedate 200603';
is_absdate "20060316",       "2006-03-16T00:00:00", 'get_validity() absolutedate 20060316';
is_absdate "2006031618",     "2006-03-16T18:00:00", 'get_validity() absolutedate 20060318';
is_absdate "200603161821",   "2006-03-16T18:21:00", 'get_validity() absolutedate 2006031821';
is_absdate "20060316182157", "2006-03-16T18:21:57", 'get_validity() absolutedate 200603182157';


# Autodetect
###########################################################################
is_date detect => '-0000000030', minutes => -30, 'get_validity() autodetect relativedate';

$dt = OpenXPKI::DateTime::get_validity( {
    VALIDITY => "2006-01-01",
    VALIDITYFORMAT => 'detect',
} );
is OpenXPKI::DateTime::convert_date({ DATE => $dt }), "2006-01-01T00:00:00",
    'autodetect absolutedate';

1;
