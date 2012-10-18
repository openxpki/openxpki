use strict;
use warnings;
use English;
use Template;
use Test::More;
use File::Spec;
use OpenXPKI::Control;
use Cwd;

 
plan tests => 6;

my $socketfile = 't/var/openxpki/openxpki.socket'; 
my $pidfile = 't/var/openxpki/openxpkid.pid';
 
if (-e $pidfile) { 
    ok(!OpenXPKI::Control::stop({ PIDFILE => $pidfile}));
} else {
    ok(1, 'No pid file - skip server stop');
} 

SKIP: {
    local $TODO = 'Server cleanup needs fixing';
    ok (!-e $pidfile, 'PID-file removed' ) || unlink $pidfile;
    ok (!- $socketfile, 'Socketfile removed' ) || unlink $socketfile;
}

our $dbi;
require 't/common/dbi.pl';

# Remove the certificate
$dbi->delete (TABLE => "CERTIFICATE", DATA => {
    PKI_REALM => "I18N_OPENXPKI_DEPLOYMENT_TEST_DUMMY_CA",     
    ISSUER_DN => "DC=test,DC=openxpki,CN=test-ca",
});
ok($dbi->commit());


