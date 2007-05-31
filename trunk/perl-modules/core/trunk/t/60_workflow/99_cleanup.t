use strict;
use warnings;

use Test::More;
plan tests => 3;

ok(system("rm -r t/60_workflow/test_instance") == 0, 'Deleted test_instance');
ok(system("rm -r t/60_workflow/test_instance_crl") == 0, 'Deleted CRL test_instance');
ok(system("rm -r t/60_workflow/test_instance_cert_issuance") == 0, 'Deleted cert issuance test_instance');
