#
# This test involves the following basic steps:
#
# 1. Start the mock scep server in a child process to accept requests
#
# 2. Create a CSR
#
# 3. Upload the CSR to our entrollment interface
#
# 4. Confirm that the CSR was accepted
#
# 5. Clean up the mess we left

use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Carp;

use FindBin;
use File::Path qw(make_path);

use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../../../qatest/lib";

use OpenXPKI::Test::CertHelper;

#my $config = plugin 'Config';
my $config = {};

$config->{basedir}    ||= 't/upload-mock-server.d';
$config->{reqdata}    ||= $config->{basedir} . '/reqdata.txt';
$config->{spooldir}   ||= $config->{basedir} . '/request.d';
$config->{clientname} ||= 'scepclient.test.openxpki.org';
$config->{createreqs} ||= $ENV{HOME}.'/git/bulkenrollment/createrequests';

# SCEP Client settings
$config->{enroll_forward_cmd} = "$FindBin::Bin/../script/sscep-wrapper.sh";
$config->{enroll_forward_cfg} = "${FindBin::Bin}/upload-mock-server-wrapper.cfg";

# Mock Server Settings
$config->{mockserver} ||= $FindBin::Bin . '/mock-scep-server';
$config->{mockserverbasedir} ||= $config->{basedir} . '/scep-server';

my $pid;

sub cleanup {
    if ($pid) {
        warn "Stopping mock SCEP server PID '$pid'" if $config->{verbose};
        kill( 15, $pid );
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
    $ENV{MOCK_SCEP_VERBOSE} = 0;

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
        basedir    => $config->{basedir} . '/onbehalf',
        commonName => 'onbehalf.test.openxpki.org',
    );
}


############################################################
# 4. Upload the CSR to our entrollment interface
############################################################

$ENV{ENROLL_FORWARD_CMD} ||= $config->{enroll_forward_cmd};
$ENV{ENROLL_FORWARD_CFG} ||= $config->{enroll_forward_cfg};

my $csr1filename = $config->{spooldir} . '/' . $config->{clientname} . '.req';

my $fh;
if ( not open($fh, "<$csr1filename") ) {
    die "Error opening $csr1filename: $!";
}
my $csr1 = join('', <$fh>);
close $fh;

my $t = Test::Mojo->new('OpenXPKI::Client::Enrollment');

# Allow 302 redirect responses
$t->ua->max_redirects(1);

$t->get_ok('/')->status_is(200)
    ->content_like(qr/Upload CSR/i)
    ->element_exists('form input[name="csr"]')
    ->element_exists('form input[type="submit"]')
    ;

$t->post_form_ok(
    '/upload',
    { csr => {file => $csr1filename}},
)->status_is(200)
    ->content_like(qr/Accepted CSR for further processing/)
    ;

# force the script to return an error not found
$ENV{SCEP_MOCK_TESTMODE} = 'ERR_NOTFOUND';

$t->post_form_ok(
    '/upload',
    { csr => {file => $csr1filename}},
)->status_is(200)
    ->content_like(qr/file not found/)
    ;

done_testing();
