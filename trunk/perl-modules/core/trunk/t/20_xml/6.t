use strict;
use warnings;
use English;
use Test::More;
plan tests => 8;

use OpenXPKI::Debug;
if ($ENV{DEBUG_LEVEL}) {
    $OpenXPKI::Debug::LEVEL{'.*'} = $ENV{DEBUG_LEVEL};
}
require OpenXPKI::XML::Config;

use Time::HiRes;


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


1;
