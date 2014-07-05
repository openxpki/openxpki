use strict;
use warnings;
use English;
use OpenXPKI::Debug;
use OpenXPKI::Control;
use OpenXPKI::Server::Context qw( CTX );
use Data::Dumper;

use Test::More;
plan tests => 4;

#use OpenXPKI::Tests;
use File::Copy;

TODO: {
    todo_skip 'See Issue #188', 4;

diag("Deploying OpenXPKI test instance\n");

# The server tests relys on the ca and database which is setup 
# in the earlier tests

`mkdir -p t/var/openxpki/session/`;

my $socketfile = 't/var/openxpki/openxpki.socket'; 
my $pidfile = 't/var/openxpki/openxpkid.pid';

-e $socketfile && die "Socketfile exists - please stop server/remove socket";

-e $pidfile && unlink($pidfile);

use OpenXPKI::Server;

$ENV{OPENXPKI_CONF_DB} = 't/config.git';

# FIXME - prove becomes defunct - seems to be some issue with stdout/stderr
#ok!(OpenXPKI::Control::start({ SILENT => 0, DEBUG =>  0 }));
ok(!system('OPENXPKI_CONF_DB="t/config.git" perl t/60_workflow/start.pl 2>/dev/null 1>/dev/null'));

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

ok(OpenXPKI::Control::status({ SOCKETFILE => $socketfile, SILENT => 1}) == 0);
}
1;
