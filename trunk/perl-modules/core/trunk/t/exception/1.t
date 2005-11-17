use strict;
use warnings;
use Test;

BEGIN { plan tests => 4 };

use OpenXPKI::Exception;

ok (1);

OpenXPKI::Exception->caught();
ok (1);

eval
{
    OpenXPKI::Exception->throw(message => "test");
};
if (my $exc = OpenXPKI::Exception->caught())
{
    ok(1);
    ok($exc->as_string() eq "test");
} else {
    ok(0);
    ok(0);
}

1;
