use strict;
use warnings;
use English;
use Test::More;
use OpenXPKI::XML::Config;
use Time::HiRes;
use Net::Ping;

BEGIN { plan tests => 6 };

diag "CONFIGURATION INHERITANCE\n";

## create new object
my $obj;
eval {
    $obj = OpenXPKI::XML::Config->new(CONFIG => "t/config_test.xml");
};
ok(defined $obj, 'Config object defined') or diag "Error: $EVAL_ERROR";

## try to discover the ca token of the first realm
my $name = eval {$obj->get_xpath (
                     XPATH   => ["pki_realm", "ca", "token", "backend"],
                     COUNTER => [0, 0, 0, 0])
                };
is($EVAL_ERROR, '', 'Getting the CA token backend of the first realm') or diag "Error: ".$EVAL_ERROR;
is($name, "OpenXPKI::Crypto::Backend::OpenSSL", 'Correct result from XML file');

## try a non-existing path
$name = eval {$obj->get_xpath (
                  XPATH   => ["pki_realm", "ca", "token", "nom"],
                  COUNTER => [0, 0, 0, 0])
             };
isnt($EVAL_ERROR, '', 'Testing non-existent path') or diag "Error: no exception thrown on wrong path";

$EVAL_ERROR = '';

TODO: {
    local $TODO = 'The XML schema is broken, see #1702814';
    SKIP: {
        my $p = Net::Ping->new('tcp', 5); 
        $p->{portnum} = 80;
        skip "Cannot validate configuration with the schema because you are offline", 2 if ($ENV{OFFLINE} || ! $p->ping('www.w3.org'));

        ## validate with xmllint
        my $result = `xmllint -format -schema openxpki.xsd -xinclude t/config_test.xml 2>&1 1>/dev/null`;
        is ($CHILD_ERROR, '', 'xmllint succeeded with the validation') or diag "Error: there is something wrong with xmllint (${CHILD_ERROR}: ${EVAL_ERROR})";

        $result =~ s/^(.*\n)?([^\n]+)\n?$/$2/s;
        is($result, "t/config_test.xml validates", 'xmllint says validation successfull') or diag "xmllint reports some trouble with t/config_test.xml and openxpki.xsd\n";
    }
}

1;
