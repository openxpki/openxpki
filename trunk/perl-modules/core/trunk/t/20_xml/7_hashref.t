use strict;
use warnings;
use English;
use Test::More;
use OpenXPKI::XML::Config;
use Data::Dumper;

plan tests => 5;

diag "get_xpath_hashref\n";

## create new object
my $obj;
eval {
    $obj = OpenXPKI::XML::Config->new(CONFIG => "t/config_test.xml");
};
ok(defined $obj, 'Config object defined') or diag "Error: $EVAL_ERROR";

my $expected =  {
  'realm' => [
             {
               'content' => 'Test Root CA'
             }
           ],
  'alias' => [
             {
               'content' => 'INTERNAL_CA_1'
             }
           ]
};

my $result = $obj->get_xpath_hashref(
    XPATH   => [ 'pki_realm', 'ca', 'cert'],
    COUNTER => [ 0          , 0   , 0     ],
);
is_deeply(
    $result,
    $expected,
    'get_xpath_hashref works'
);
$result->{realm}->[0]->{'content'} = 'TEST ROOT CA';
my $result2 = $obj->get_xpath_hashref(
    XPATH   => [ 'pki_realm', 'ca', 'cert'],
    COUNTER => [ 0          , 0   , 0     ],
);
is_deeply(
    $result2,
    $expected,
    'Changing the result does not change the original (deepcopy)',
);

## try a non-existing path
my $name = eval {$obj->get_xpath_hashref (
                  XPATH   => ["pki_realm", "ca", "token", "nom"],
                  COUNTER => [0, 0, 0, 0])
             };
isnt($EVAL_ERROR, '', 'Testing non-existent path') or diag "Error: no exception thrown on wrong path";

## try a path that is too short (not a hashref)
$name = eval {$obj->get_xpath_hashref (
                  XPATH   => ["pki_realm", "ca", "cert"],
                  COUNTER => [0])
             };
isnt($EVAL_ERROR, '', 'Testing path that is too short') or diag "Error: no exception thrown on path that is too short: " . Dumper $name;


1;
