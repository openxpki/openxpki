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

use lib qw(
  /usr/lib/perl5/ 
  ../../lib
);

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

$test->plan( tests => 3 );
  
# Login to use socket
$test->connect_ok(
    user => $cfg{operator}{name},
    password => $cfg{operator}{role},
) or die "Error - connect failed: $@";


my %wfparam = (
    force_issue => 1,
    #delta_crl => 0, # not supported yet
    #crl_validity=>'+000014',	
);
    
$test->create_ok( 'I18N_OPENXPKI_WF_TYPE_CRL_ISSUANCE' , \%wfparam, 'Create CRL Workflow')
 or die "Workflow Create failed: $@";

$test->state_is('SUCCESS');



$test->disconnect();
  