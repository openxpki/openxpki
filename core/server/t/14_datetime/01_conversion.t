use strict;
use warnings;

# CPAN modules
use Test::More;
use DateTime;


plan tests => 6;



my $epoch = 1142434089;
my $dt = DateTime->from_epoch( epoch => $epoch );

sub is_conversion($$$) {
    my ($format, $expected, $test_name) = @_;
    is OpenXPKI::DateTime::convert_date({ OUTFORMAT => $format, DATE => $dt }), $expected, $test_name;
}

use_ok 'OpenXPKI::DateTime';

is_conversion 'epoch', $epoch, 'conversion to epoch';
is_conversion 'iso8601', '2006-03-15T14:48:09', 'conversion to iso8601';
is_conversion 'openssltime', '060315144809Z', 'conversion to openssltime';
is_conversion 'terse', '20060315144809', 'conversion to terse';
is_conversion 'printable', '2006-03-15 14:48:09', 'conversion to printable';

1;
