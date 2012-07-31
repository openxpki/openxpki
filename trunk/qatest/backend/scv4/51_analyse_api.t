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

$test->plan( tests => 2 );

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
   push @certflat, $cert;     
}

$test->diag("Found ".scalar(@certflat)." exisiting certificates");

$test->connect_ok(
    user => $cfg{user}{name},
    password => $cfg{user}{role},
) or die "Error - connect failed: $@";
  
$test->runcmd('sc_analyze_smartcard', {
    'CERTS' => \@certflat,
    'SMARTCHIPID' => $cfg{carddata}{chip_id},
    'SMARTCARDID' => $cfg{carddata}{token_id},
    'CERTFORMAT' => 'PEM',
});

$test->is( $test->get_msg()->{PARAMS}->{OVERALL_STATUS}, 'green', 'Check if status is green' );
 
$test->disconnect();

  
