
use strict;
use warnings;
use English;
use Test;
use OpenXPKI::XML::Config;
use Time::HiRes;

BEGIN { plan tests => 3 };

print STDERR "SCHEMA VALIDATION\n";
ok(1);

## create new object
my $obj = OpenXPKI::XML::Config->new(DEBUG  => 0,
                                     CONFIG => "t/config.xml",
                                     SCHEMA => "openxpki.xsd");
if ($obj)
{
    ok (1);
} else {
    ok (0);
    print STDERR "Error: ${EVAL_ERROR}\n";
}

## try a wrong XML file
eval { $obj = OpenXPKI::XML::Config->new(DEBUG  => 0,
                                         CONFIG => "t/crypto/token.xml",
                                         SCHEMA => "openxpki.xsd"); };
if ($EVAL_ERROR)
{
    ok (1);
} else {
    ok (0);
    print STDERR "Error: wrong XML file was not detected\n";
}

1;
