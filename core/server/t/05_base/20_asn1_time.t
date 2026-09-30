use strict;
use warnings;
use Test::More;
use Test::Exception;

use_ok "OpenXPKI::Role::ASN1Parse";

sub to_epoch { OpenXPKI::Role::ASN1Parse::asn1_time_to_epoch(@_) }

# UTCTime, two digit year is 1950 - 2049
is(to_epoch('491231235959Z'), 2524607999, 'UTCTime 49 is 2049');
is(to_epoch('500101000000Z'), -631152000, 'UTCTime 50 is 1950');
is(to_epoch('700101000000Z'), 0, 'UTCTime 70 is 1970');

# GeneralizedTime
is(to_epoch('20500101000000Z'), 2524608000, 'GeneralizedTime 2050');
is(to_epoch('29000101000000Z'), 29348006400, 'GeneralizedTime 2900');
is(to_epoch('99991231235959Z'), 253402300799, 'GeneralizedTime 9999');
is(to_epoch('20260929120000.123Z'), 1790683200, 'fractional seconds are ignored');

# zone offsets
is(to_epoch('20260929140000+0200'), 1790683200, 'positive offset');
is(to_epoch('260929073000-0430'), 1790683200, 'negative offset');

# Time CHOICE
is(to_epoch({ utcTime => '260929120000Z' }), 1790683200, 'CHOICE utcTime');
is(to_epoch({ generalTime => '99991231235959Z' }), 253402300799, 'CHOICE generalTime');

is(to_epoch(undef), undef, 'undef');
is(to_epoch({}), undef, 'empty CHOICE');
throws_ok { to_epoch('2026-09-29') } qr/Invalid ASN.1 time format/, 'invalid format';

done_testing;
