use strict;
use warnings;
use Test::More;

use OpenXPKI::XML::Config;

plan tests => 7;

print STDERR "XINCLUDE SUPPORT\n";

## create new object
my $obj = OpenXPKI::XML::Config->new(CONFIG => "t/20_xml/top.xml");

ok(defined $obj, 'Config object is defined');
is(ref $obj, 'OpenXPKI::XML::Config', 'Config object has correct type');

my $msg = qq/name --> config
  name --> content
  value --> before xi
  name --> content
  value --> after xi
  name --> content
  value --> testdata
/;
is ($obj->dump(''), $msg, 'dump() works correctly');

my $xpath = "config";
is ($obj->get_xpath (COUNTER => 0, XPATH => $xpath),
    "before xi", 'get_xpath works correctly _before_ xinclude');
is ($obj->get_xpath (COUNTER => 1, XPATH => $xpath),
    "after xi", 'get_xpath works correctly _after_ xinclude');
is ($obj->get_xpath (COUNTER => 2, XPATH => $xpath),
    "testdata", 'get_xpath works correctly _in_ xinclude');

TODO: {
    local $TODO = 'Multiple includes not implemented yet, see #1653466';
    # test multiple includes
    ## create new object
    $obj = undef;
    eval {
        $obj = OpenXPKI::XML::Config->new(CONFIG => "t/20_xml/top2.xml");
    };

    ok(defined $obj, 'Config object with multiple includes is defined');
}

1;
