use strict;
use warnings;

use Test::More;
use OpenXPKI::Debug;
if ($ENV{DEBUG_LEVEL}) {
    $OpenXPKI::Debug::LEVEL{'.*'} = $ENV{DEBUG_LEVEL};
}
require OpenXPKI::XML::Config;

plan tests => 3;

my $obj = OpenXPKI::XML::Config->new(CONFIG => "t/20_xml/inheritance_bug.xml");

ok(defined $obj, 'Config object is defined');
is(ref $obj, 'OpenXPKI::XML::Config', 'Config object has correct type');

my $result = $obj->get_xpath(
    XPATH   => [ 'pki_realm', 'profiles', 'profile', 'oid' ],
    COUNTER => [ 1          ,  0         , 1        , 0    ],
);

diag "Result: $result";

TODO: {
    local $TODO = 'Weird inheritance bug #1865861';
    is($result, 'test2', 'correct output');
}
