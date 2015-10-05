use strict;
use warnings;
use English;
use Template;
use Test::More;
use File::Spec;
use OpenXPKI::Control;
use Cwd;

 

my $socketfile = 't/var/openxpki/openxpki.socket'; 
my $pidfile = 't/var/openxpki/openxpkid.pid';
 
if (-e $pidfile) { 
    plan tests => 4;
    ok(!OpenXPKI::Control::stop({ PIDFILE => $pidfile}));
    ok (!-e $pidfile, 'PID-file removed' ) || unlink $pidfile;
    ok (!-e $socketfile, 'Socketfile removed' ) || unlink $socketfile;
    our $dbi;
    require 't/common/dbi.pl';

    # Remove the certificate
    $dbi->delete (TABLE => "CERTIFICATE", DATA => {
        PKI_REALM => "I18N_OPENXPKI_DEPLOYMENT_TEST_DUMMY_CA",     
        ISSUER_DN => "DC=test,DC=openxpki,CN=test-ca",
    });
    ok($dbi->commit());
} else {
    plan tests => 1;
    ok(1, 'No pid file - skip server stop');
} 

