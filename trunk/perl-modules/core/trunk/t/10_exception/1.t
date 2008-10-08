use strict;
use warnings;
use Test::More;
plan tests => 7;

use_ok('OpenXPKI::Exception');

eval
{
    OpenXPKI::Exception->throw(message => "test");
};
my $exc = OpenXPKI::Exception->caught();
ok(defined $exc, 'simple exception defined');
is($exc->as_string(), 'test', 'as_string() correct');

eval {
    OpenXPKI::Exception->throw(
        message => 'test',
        params  => {
            'param1' => 'value1',
            'param2' => 'value2',
        },
    );
};
$exc = OpenXPKI::Exception->caught();
ok(defined $exc, 'exception with params defined');
is($exc->as_string(), 'test; __param2__ => value2; __param1__ => value1', 'as_string() with params correct');

eval {
    OpenXPKI::Exception->throw(
        message => 'parent',
        params  => {
            'parent_param1' => 'parent_value1',
            'parent_param2' => 'parent_value2',
        },
        children => [
            $exc,
        ],
    );
    
};
my $parent_exc = OpenXPKI::Exception->caught();
ok(defined $parent_exc, 'exception with child defined');
is($parent_exc->as_string(), 'parent; __parent_param1__ => parent_value1; __ERRVAL__ => test; __param1__ => value1; __param2__ => value2; __parent_param2__ => parent_value2', 'as_string() with child correct');

1;
