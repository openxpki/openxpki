use strict;
use warnings;
use Test::More;
use English;

use OpenXPKI::Debug;
if ($ENV{DEBUG_LEVEL}) {
    $OpenXPKI::Debug::LEVEL{'.*'} = $ENV{DEBUG_LEVEL};
}
require OpenXPKI::XML::Config;

plan tests => 8;

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

# test multiple includes
## create new object
$obj = undef;
eval {
    $obj = OpenXPKI::XML::Config->new(CONFIG => "t/20_xml/top2.xml");
};

ok(defined $obj, 'Config object with multiple includes is defined');

$obj = undef;
eval {
    $obj = OpenXPKI::XML::Config->new(CONFIG => 't/20_xml/loop1.xml');
};
is($EVAL_ERROR->message,
   'I18N_OPENXPKI_XML_CACHE_PERFORM_XINCLUDE_POSSIBLE_LOOP_DETECTED',
   'Loop detection works'
);

1;
