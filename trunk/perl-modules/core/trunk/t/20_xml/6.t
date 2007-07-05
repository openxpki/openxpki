use strict;
use warnings;
use English;
use Test::More;
plan tests => 21;

use OpenXPKI::Debug;
if ($ENV{DEBUG_LEVEL}) {
    $OpenXPKI::Debug::LEVEL{'.*'} = $ENV{DEBUG_LEVEL};
}
require OpenXPKI::XML::Config;

use Time::HiRes;
use Data::Dumper;
#use GraphViz::Data::Structure;

diag "RELATIVE CONFIGURATION INHERITANCE\n";

## create new object
my $obj = OpenXPKI::XML::Config->new(CONFIG => "t/20_xml/relative.xml");
ok($obj) or diag "Error: ${EVAL_ERROR}\n";

## try to discover the ca token of the first realm
my $item;
$item = $obj->get_xpath (
    XPATH   => ["subordinate", "item", "value"],
    COUNTER => [0, 0, 0]);

# test 3
is($item, 'foobar');

$item = $obj->get_xpath (
    XPATH   => ["subordinate", "item", "value"],
    COUNTER => [0, 1, 0]);

# test 4
is($item, 'foobar');

$item = $obj->get_xpath (
    XPATH   => ["subordinate", "item", "value"],
    COUNTER => [0, 2, 0]);

# test 5
is($item, 'foobar');

eval {
$item = undef;
$item = $obj->get_xpath (
    XPATH   => ["subordinate", "item", "value"],
    COUNTER => [0, 3, 0]);
};
# test 6
is($item, 'yohoo') or diag $EVAL_ERROR;

$item = $obj->get_xpath (
    XPATH   => ["subordinate", "item", "value"],
    COUNTER => [0, 4, 0]);

# test 7
is($item, 'somevalue');

$item = $obj->get_xpath (
    XPATH   => ["subordinate", "item", "value"],
    COUNTER => [0, 5, 0]);

# test 8
is($item, 'somevalue');

$item = $obj->get_xpath (
    XPATH   => ["subordinate", "item", "value"],
    COUNTER => [0, 6, 0]);

# test 9
is($item, 'somevalue');

$item = $obj->get_xpath(
    XPATH   => ['subordinate', 'item', 'value'],
    COUNTER => [0, 7, 0]);

is($item, 'test');

## create new object
$obj = OpenXPKI::XML::Config->new(CONFIG => "t/25_crypto/test_profile.xml");
ok($obj) or diag "Error: ${EVAL_ERROR}\n";

unlike($obj->dump(), qr/name --> super\n/, 'No mention of super in the dump');

my $result;
eval {
    $result = $obj->get_xpath(
        XPATH   => ['selfsignedca', 'profile', 'validity', 'notafter', 'format' ],
        COUNTER => [0             , 1        , 0         , 0         , 0        ],
    );
};
ok (! $EVAL_ERROR, 'get_xpath works') or diag $EVAL_ERROR;
is ($result, 'relativedate', 'get_xpath returns the correct result');


eval {
    $result = $obj->get_xpath(
        XPATH   => ['selfsignedca', 'profile', 'validity', 'notbefore', 'format' ],
        COUNTER => [0             , 0        , 0         , 0         , 0        ],
    );
};
# if this test fails, it usually means that the one who inherits inadvertently
# copied some of his data to the one he inherited from ...
ok ($EVAL_ERROR, 'Super entry did not inherit from caller');

## create new object
$obj = OpenXPKI::XML::Config->new(CONFIG => "t/20_xml/test_profile2.xml");
ok($obj) or diag "Error: ${EVAL_ERROR}\n";

unlike($obj->dump(), qr/name --> super\n/, 'No mention of super in the dump');

eval {
    $result = $obj->get_xpath(
        XPATH   => ['selfsignedca', 'profile', 'validity', 'notafter' ],
        COUNTER => [0             , 1        , 0         , 0          ],
    );
};
ok (! $EVAL_ERROR, 'get_xpath works') or diag $EVAL_ERROR;
is ($result, '+01', 'get_xpath returns the correct result (inheritance overwriting)');


## create new object
undef $obj;
$obj = OpenXPKI::XML::Config->new(CONFIG => 't/20_xml/test_acl.xml');
ok($obj, 'XML file parsed correctly') or diag "Error: $EVAL_ERROR\n";

eval {
    $result = $obj->get_xpath_count(
        XPATH   => [ 'workflow_permissions', 'server', 'create'],
        COUNTER => [ 0                     , 0        ],
    );
};
ok(! $EVAL_ERROR, 'get_xpath works') or diag $EVAL_ERROR;
TODO: {
    local $TODO = 'XML multi-level inheritance is broken, SF bug #1748593';
    is($result, '4', '4 entries present (3 inherited + 1 new)');
}

# tip of the day, nice for debugging:
# my $gvds = GraphViz::Data::Structure->new($obj->dumper);
# print $gvds->graph()->as_png('test.png');
1;
