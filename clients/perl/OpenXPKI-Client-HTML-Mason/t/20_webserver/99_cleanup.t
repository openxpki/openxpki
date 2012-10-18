use strict;
use warnings;

use Test::More;
plan tests => 2;

ok(system("openxpkictl --config t/20_webserver/test_instance/etc/openxpki/config.xml stop") == 0,
    'Successfully stopped OpenXPKI instance');
ok(system("rm -r t/20_webserver/test_instance") == 0,
    'Successfully deleted test_instance');
