
use strict;
use warnings;
use English;
use Test::More;
use OpenXPKI::XML::Config;
use Time::HiRes;

plan tests => 4;

print STDERR "SCHEMA VALIDATION\n";

TODO: {
    local $TODO = 'Schema is outdated, see #1702814';
    ## create new object
    my $obj = eval {OpenXPKI::XML::Config->new(CONFIG => "t/config_test.xml",
                                               SCHEMA => "openxpki.xsd")};
    is($EVAL_ERROR, '', 'Config object created successfully');
    ok(defined $obj, 'Config object is defined');
    is(ref $obj, 'OpenXPKI::XML::Config', 'Config object has correct type');
}

## try an incorrect XML file
my $obj;
eval { $obj = OpenXPKI::XML::Config->new(CONFIG => "t/25_crypto/token.xml",
                                         SCHEMA => "openxpki.xsd"); };
ok($EVAL_ERROR, 'Incorrect XML file detected correctly');
1;
