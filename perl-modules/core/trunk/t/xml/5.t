
use strict;
use warnings;
use English;
use Test;
use OpenXPKI::XML::Config;
use Time::HiRes;

BEGIN { plan tests => 5 };

print STDERR "CONFIGURATION INHERITANCE\n";
ok(1);

## create new object
my $obj = OpenXPKI::XML::Config->new(DEBUG  => 0,
                                     CONFIG => "t/config.xml");
if ($obj)
{
    ok (1);
} else {
    ok (0);
    print STDERR "Error: ${EVAL_ERROR}\n";
}

## try to discover the ca token of the first realm
my $name = eval {$obj->get_xpath (
                     XPATH   => ["pki_realm", "ca", "token", "backend"],
                     COUNTER => [0, 0, 0, 0])
                };
if ($EVAL_ERROR)
{
    ok(0);
    print STDERR "Error: ".$EVAL_ERROR->as_string()."\n";
} else {
    ok(1);
}
ok ($name eq "OpenXPKI::Crypto::Backend::OpenSSL");

## try a wring path
$name = eval {$obj->get_xpath (
                  XPATH   => ["pki_realm", "ca", "token", "nom"],
                  COUNTER => [0, 0, 0, 0])
             };
if ($EVAL_ERROR)
{
    ok(1);
} else {
    ok(0);
    print STDERR "Error: no exception thrown on wrong path\n";
}

1;
