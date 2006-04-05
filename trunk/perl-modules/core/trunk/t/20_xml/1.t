
use strict;
use warnings;
use Test;
use OpenXPKI::XML::Config;
use Time::HiRes;

BEGIN { plan tests => 3 };

print STDERR "SYNTAX VALIDATION\n";
ok(1);

## create new object
my $obj = OpenXPKI::XML::Config->new(CONFIG => "t/20_xml/test.xml");

if ($obj)
{
    ok (1);
} else {
    ok (0);
    exit;
}

my $msg = $obj->dump("");

my $xpath = "config";
my $counter = 0;
my $answer = $obj->get_xpath (COUNTER => $counter, XPATH => $xpath);
ok ($answer, "Yeah, what a nice testfile!");

1;
