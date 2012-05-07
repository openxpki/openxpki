#!/usr/bin/perl
#

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
$testcfg->read_config_path( '5x_personalize.cfg', \%cfg, @cfgpath );

my $ser = OpenXPKI::Serialization::Simple->new();

my $test = OpenXPKI::Test::More->new(
    {
        socketfile => $cfg{instance}{socketfile},
        realm => $cfg{instance}{realm},
    }
) or die "Error creating new test instance: $@";

$test->set_verbose($cfg{instance}{verbose});

$test->plan( tests => 3 );


$test->connect_ok(
    user => $cfg{user}{name},
    password => $cfg{user}{role},
) or die "Error - connect failed: $@";

open(CERT, "<$cfg{instance}{buffer}");
my @lines = <CERT>;
close CERT;

my $certs = $ser->deserialize( join("",  @lines));
my @certflat;
foreach my $cert (@{$certs}) {
   
   $cert =~ s/-----.*?-----//g;
   $cert =~ s/\n//g;
   push @certflat, $cert;     
}

my %wfparam = (        
        user_id =>  $cfg{carddata}{frontend_user},
        token_id =>  $cfg{carddata}{token_id},
        chip_id => '',
        certs_on_card =>  join(";",  @certflat),
);      
    
$test->create_ok( 'I18N_OPENXPKI_WF_TYPE_SMARTCARD_PERSONALIZATION_V4' , \%wfparam, 'Create SCv4 Test Workflow')
 or die "Workflow Create failed: $@";
 
$test->state_is('SUCCESS'); 
$test->disconnect();
 
$test->disconnect();