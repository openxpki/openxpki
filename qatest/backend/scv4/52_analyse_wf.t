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
use File::Slurp;


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

my $cert_dir = $cfg{instance}{certdir};
if ($cert_dir !~ '^/') {
	$cert_dir = $dirname.'/'.$cert_dir;
}

-d $cert_dir || die "Please create certificate directory $cert_dir " ;
-w $cert_dir || die "Please make certificate directory $cert_dir writable" ; 

# Slurp in the certificates
my @paths = read_dir( $cert_dir ) ;
 
my @certflat;
foreach my $cert_file (@paths) {   
   next unless ($cert_file =~ /\.crt$/);      
   my $cert = read_file( "$cert_dir/$cert_file" );
   $cert =~ s/-----.*?-----//g;
   $cert =~ s/\n//g;
   push @certflat, $cert;     
}

$test->diag("Found ".scalar(@certflat)." exisiting certificates");

$test->connect_ok( %{$cfg{auth}} ) or die "Error - connect failed: $@"; 

my %wfparam = (        
        user_id =>  $cfg{carddata}{frontend_user},
        token_id =>  $cfg{carddata}{token_id},
        chip_id => $cfg{carddata}{chip_id},
        certs_on_card =>  join(";",  @certflat),
);      
    
$test->create_ok( 'sc_personalization' , \%wfparam, 'Create SCv4 Test Workflow')
 or die "Workflow Create failed: $@";
 
$test->state_is('SUCCESS'); 
$test->disconnect();
 
$test->disconnect();