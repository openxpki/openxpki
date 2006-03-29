
use strict;
use warnings;
use English;
use Test;
use OpenXPKI::XML::Config;
use Time::HiRes;

BEGIN { plan tests => 9, todo => [ 6 ] };

print STDERR "RELATIVE CONFIGURATION INHERITANCE\n";
ok(1);

## create new object
my $obj = OpenXPKI::XML::Config->new(DEBUG  => 0,
                                     CONFIG => "t/20_xml/relative.xml");
if ($obj)
{
    ok (1);
} else {
    ok (0);
    print STDERR "Error: ${EVAL_ERROR}\n";
}

## try to discover the ca token of the first realm
my $item;
$item = $obj->get_xpath (
    XPATH   => ["subordinate", "item", "value"],
    COUNTER => [0, 0, 0]);

# test 3
ok($item, 'foobar');

$item = $obj->get_xpath (
    XPATH   => ["subordinate", "item", "value"],
    COUNTER => [0, 1, 0]);

# test 4
ok($item, 'foobar');

$item = $obj->get_xpath (
    XPATH   => ["subordinate", "item", "value"],
    COUNTER => [0, 2, 0]);

# test 5
ok($item, 'foobar');

# TODO: we are getting an exception here
eval {
$item = undef;
$item = $obj->get_xpath (
    XPATH   => ["subordinate", "item", "value"],
    COUNTER => [0, 3, 0]);
};
# test 6
ok($item, 'yohoo');

$item = $obj->get_xpath (
    XPATH   => ["subordinate", "item", "value"],
    COUNTER => [0, 4, 0]);

# test 7
ok($item, 'somevalue');

$item = $obj->get_xpath (
    XPATH   => ["subordinate", "item", "value"],
    COUNTER => [0, 5, 0]);

# test 8
ok($item, 'somevalue');

$item = $obj->get_xpath (
    XPATH   => ["subordinate", "item", "value"],
    COUNTER => [0, 6, 0]);

# test 9
ok($item, 'somevalue');


1;
