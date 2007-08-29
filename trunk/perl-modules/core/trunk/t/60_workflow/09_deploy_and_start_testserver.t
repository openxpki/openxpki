use strict;
use warnings;
use English;

use Test::More;
plan tests => 5;

use OpenXPKI::Tests;
use File::Copy;

diag("Deploying OpenXPKI test instance\n");

my $instancedir = 't/60_workflow/test_instance';
my $socketfile = $instancedir . '/var/openxpki/openxpki.socket';
my $pidfile    = $instancedir . '/var/openxpki/openxpki.pid';

ok(deploy_test_server({
        DIRECTORY  => $instancedir,
    }), 'Test server deployed successfully');
copy("t/60_workflow/openssl.cnf", "$instancedir/openssl.cnf");
ok(create_ca_cert({
        DIRECTORY => $instancedir,
    }), 'CA certificate created and installed successfully');
ok(start_test_server({
        DIRECTORY  => $instancedir,
    }), 'Test server started successfully');

# wait for server startup
CHECK_SOCKET:
foreach my $i (1..60) {
    if (-e $socketfile) {
        last CHECK_SOCKET;
    }
    else {
        sleep 1;
    }
}
ok(-e $pidfile, "PID file exists");
ok(-e $socketfile, "Socketfile exists");

