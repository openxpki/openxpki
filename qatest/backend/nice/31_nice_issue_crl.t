#!/usr/bin/perl
#
# 045_activity_tools.t
#
# Tests misc workflow tools like WFObject, etc.
#
# Note: these tests are non-destructive. They create their own instance
# of the tools workflow, which is exclusively for such test purposes.

use strict;
use warnings;

use FindBin qw( $Bin );
use lib "$Bin/../../lib";

use Carp;
use English;
use Data::Dumper;
use Config::Std;
use File::Basename;

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);

use OpenXPKI::Test::More;
use TestCfg;

my $dirname = dirname($0);

our @cfgpath = ( $dirname );
our %cfg = ();

my $testcfg = new TestCfg;
$testcfg->read_config_path( '9x_nice.cfg', \%cfg, @cfgpath );

my $test = OpenXPKI::Test::More->new(
    {
        socketfile => $cfg{instance}{socketfile},
        realm => $cfg{instance}{realm},
    }
) or die "Error creating new test instance: $@";

$test->set_verbose($cfg{instance}{verbose});

$test->plan( tests => 7 );

# Login to use socket
$test->connect_ok(
    user => $cfg{operator}{name},
    password => $cfg{operator}{password},
) or die "Error - connect failed: $@";


my %wfparam = (
    force_issue => 1,
);

$test->create_ok( 'crl_issuance' , \%wfparam, 'Create CRL Workflow')
 or die "Workflow Create failed: $@";

$test->state_is('SUCCESS');


# Fetch the most recent crl, pem
$test->runcmd('get_crl', { FORMAT => 'PEM' });
$test->like( $test->get_msg()->{PARAMS}, "/----BEGIN X509 CRL-----/", 'Fetch CRL (PEM)');

# test crl der format
$test->runcmd('get_crl', { FORMAT => 'DER' });
$test->ok ( $test->get_msg()->{PARAMS} ne '', 'Fetch CRL (DER)');

my $tmpfile = "/tmp/mycrl.der.$$";
$test->ok(open(CRL, ">$tmpfile"));
print CRL $test->get_msg()->{PARAMS};
close CRL;

$test->disconnect();

$test->nok( `openssl crl -in $tmpfile -inform DER -noout 2>/dev/null` );
unlink $tmpfile;
