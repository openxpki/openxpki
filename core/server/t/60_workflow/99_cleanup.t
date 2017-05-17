use strict;
use warnings;

# Core modules
use English;
use Cwd;
use File::Spec;
use FindBin qw( $Bin );

# CPAN modules
use Template;
use Test::More;

# Project modules
use lib "$Bin/../lib";
use OpenXPKI::Control;
use OpenXPKI::Test;



my $socketfile = 't/var/openxpki/openxpki.socket';
my $pidfile = 't/var/openxpki/openxpkid.pid';

if (-e $pidfile) {
    plan tests => 4;
    ok(!OpenXPKI::Control::stop({ PIDFILE => $pidfile}));
    ok (!-e $pidfile, 'PID-file removed' ) || unlink $pidfile;
    ok (!-e $socketfile, 'Socketfile removed' ) || unlink $socketfile;

    use OpenXPKI::Test;
    my $oxitest = OpenXPKI::Test->new;
    # Remove the certificate
    $$oxitest->dbi->delete_and_commit(
        from  => "certificate",
        where => {
            pki_realm => "I18N_OPENXPKI_DEPLOYMENT_TEST_DUMMY_CA",
            issuer_dn => "DC=test,DC=openxpki,CN=test-ca",
        },
    );
} else {
    plan tests => 1;
    ok(1, 'No pid file - skip server stop');
}

