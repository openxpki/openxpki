#
# This test involves the following basic steps:
#
# 1. Start the mock scep server in a child process to accept requests
#
# 2. Create a CSR
#
# 3. Call the sscep-wrapper using the above CSR
#
# 4. Confirm that the CSR was accepted
#
# 5. Clean up the mess we left

use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use FindBin;
use File::Path qw(make_path);

use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../../../qatest/lib";

use OpenXPKI::Test::CertHelper;

#my $config = plugin 'Config';
my $config = {};

$config->{basedir}    ||= $FindBin::Bin . '/sscep-wrapper.d';
$config->{reqdata}    ||= $config->{basedir} . '/reqdata.txt';
$config->{spooldir}         ||= $config->{basedir} . '/request.d';
$config->{clientname} ||= 'scepclient.test.openxpki.org';
$config->{createreqs} ||= $ENV{HOME} . '/git/bulkenrollment/createrequests';

# SCEP Client (wrapper) settings for "on behalf" forwarding of CSR
$config->{enroll_forward_cmd} = "$FindBin::Bin/../script/sscep-wrapper.sh";
$config->{enroll_forward_cfg} = "${FindBin::Bin}/sscep-wrapper.cfg";


# Mock Server Settings
$config->{mockserver} ||= $FindBin::Bin . '/mock-scep-server';
$config->{mockserverbasedir} ||= $config->{mockserver} . '.d';

my $pid;

sub cleanup {
    if ($pid) {
        warn "Stopping mock scep server PID '$pid'";
        kill( 15, $pid );
#        warn "Wait PID '$pid'";
        waitpid( $pid, 0 );
    }
    return 1;
}

END {
    cleanup();
}

############################################################
# 1. Start the mock scep server
############################################################

if ( not $pid = fork ) {

    # Child
    die "cannot fork: $!" unless defined $pid;

    my $fname = $config->{mockserver};
    if ( not -f $fname ) {
        die "Error: $fname not found";
    }
    $ENV{MOCK_SCEP_BASEDIR} = $config->{mockserverbasedir};

    #    $ENV{SCEP_SERVER_PASS} = $config->{scep_client_pass};
    exec( $fname, 'daemon' );
    exit;
}

# Give SCEP server a chance to catch up
sleep 2;

############################################################
# 2. Create the CSR
############################################################

{
    make_path($config->{basedir}, $config->{spooldir}, { error => \my $err} );
    if ( @{ $err } ) {
        for my $diag (@{ $err }) {
            my ($file, $message) = %{ $diag };
            if ( $file eq '' ) {
                die "Error running make_path: $message";
            } else {
                die "Error making dir $file: $message";
            }
        }
    }

    my $fh;

    # Create the request data file
    open( $fh, '>' . $config->{reqdata} )
      or die "Error opening " . $config->{reqdata};
    print( $fh $config->{clientname} . "\n" )
      or die "Error writing to " . $config->{reqdata} . ": $!";
    close($fh)
      or die "Error closing " . $config->{reqdata} . ": $!";

    my $rc = system( $config->{createreqs}, '--spool',
        $config->{spooldir}, $config->{reqdata}
    );
    $rc >>= 8;
    die "Running createreqs ("
      . $config->{createreqs}
      . ") failed."
      if $rc;
}

############################################################
# 3. Create cert used by scep client (i.e.: on behalf)
############################################################
{
    OpenXPKI::Test::CertHelper->via_openssl(
        basedir    => 't/sscep-wrapper.d/onbehalf',
        commonName => 'onbehalf.test.openxpki.org',
        password => 'my-onbehalf-passphrase',
    );
}

############################################################
# 4. Upload the CSR to our entrollment interface
############################################################

{
    my $rc = system( $config->{enroll_forward_cmd},
        $config->{enroll_forward_cfg},
        $config->{spooldir} . '/' . $config->{clientname} . '.req'
    );
    $rc >>= 8;
    is($rc, 0, 'enroll');
}

done_testing();
