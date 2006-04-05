
use strict;
use warnings;
use Test;
use OpenXPKI::XML::Config;
use Time::HiRes;

BEGIN { plan tests => 6 };

print STDERR "XINCLUDE SUPPORT\n";
ok(1);

## create new object
my $obj = OpenXPKI::XML::Config->new(CONFIG => "t/20_xml/top.xml");

if ($obj)
{
    ok (1);
} else {
    ok (0);
    exit;
}

my $msg = qq/name --> config
  name --> content
  value --> before xi
  name --> content
  value --> after xi
  name --> content
  value --> testdata
/;
ok ($obj->dump("") eq $msg);

my $xpath = "config";
ok ($obj->get_xpath (COUNTER => 0, XPATH => $xpath),
    "before xi");
ok ($obj->get_xpath (COUNTER => 1, XPATH => $xpath),
    "after xi");
ok ($obj->get_xpath (COUNTER => 2, XPATH => $xpath),
    "testdata");

1;
