
use strict;
use warnings;
use English;
use Test;
use OpenXPKI::XML::Config;
use Time::HiRes;

BEGIN { plan tests => 6 };

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

## try a non-existing path
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

if ($ENV{OFFLINE})
{
    ok(1);
    print STDERR "WARNING: Cannot validate the configuration with the schema because you are offline.\n";
}
else
{ 
    ## validate with xmllint
    my $result = `xmllint -format -schema openxpki.xsd -xinclude t/config.xml 2>&1 1>/dev/null`;
    if ($CHILD_ERROR)
    {
        my $msg = "Error: there is something wrong with xmllint (${CHILD_ERROR}: ${EVAL_ERROR})\n";
        $result = `ping -c 1 -t 2 www.w3.org`;
        if ($CHILD_ERROR)
        {
            ok(1);
            print STDERR "WARNING: Cannot validate the configuration with the schema because you are offline.\n";
        } else {
            ok(0);
            print STDERR $msg;
        }
    } else {
        $result =~ s/^(.*\n)?([^\n]+)\n?$/$2/s;
        if ($result eq "t/config.xml validates")
        {
            ok(1);
        } else {
            ok(0);
            print STDERR "xmllint reports some trouble with t/config.xml and openxpki.xsd\n";
        }
    }
}

1;
