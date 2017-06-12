#!/usr/bin/perl
#

# The Script is tailored to a special test case, it will proceed but
# show errors if the prerequs are not matched
#
# 1) If you test with a card with chip_id, you need to clear the 
#    recorded assignment in the datapool first
# 2) The user should have more than one assigned login, the test
#    selects the first one
# 3) The scripts needs a dummy csr to post - this is created on the first 
#    run at "sctest.csr" by calling openssl. You need the openssl binary
#    in the path and write access to the current directory

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
use Digest::SHA qw(sha1_hex);

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);

use OpenXPKI::Test::More;
use TestCfg;

my $dirname = dirname($0);

our @cfgpath = ( $dirname );
our %cfg = ();

sub makeCSR;
sub getModulus($);

my $testcfg = new TestCfg;
$testcfg->read_config_path( '5x_personalize.cfg', \%cfg, @cfgpath );

my $cert_dir = $cfg{instance}{certdir};
if ($cert_dir !~ '^/') {
	$cert_dir = $dirname.'/'.$cert_dir;
}

-d $cert_dir || die "Please create certificate directory $cert_dir " ;
-w $cert_dir || die "Please make certificate directory $cert_dir writable" ; 

my $test = OpenXPKI::Test::More->new(
    {
        socketfile => $cfg{instance}{socketfile},
        realm => $cfg{instance}{realm},
    }
) or die "Error creating new test instance: $@";

my $number_of_tests = 6;

$test->set_verbose($cfg{instance}{verbose});

$test->connect_ok( %{$cfg{auth}} ) or die "Error - connect failed: $@";

# Test server load
$test->create_ok( 'sc_server_load' , {}, 'Server Load')
 or die "Workflow Create failed: $@";

$test->state_is('SUCCESS');
$test->param_is('server_status','OK');

my $ser = OpenXPKI::Serialization::Simple->new();

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

my %wfparam = (        
        user_id => $cfg{carddata}{frontend_user},
        token_id => $cfg{carddata}{token_id},
        chip_id => $cfg{carddata}{chip_id},
		certs_on_card => join(";",  @certflat),
);      

	
$test->create_ok( 'sc_personalization' , \%wfparam, 'Create SCv4 Test Workflow')
 or die "Workflow Create failed: $@";

 
# First Time PUK ?
if ($test->state() eq 'PUK_TO_INSTALL') {
	$number_of_tests += 4;
	$test->diag("Need to install PUK");
    $test->execute_ok('scpers_fetch_puk') || die "Error creating puk";
    $test->state_is('PUK_TO_INSTALL');
    $test->param_like('_puk','/ARRAY.*/');
    $test->execute_ok('scpers_puk_write_ok') || die "Error writing puk";; 
}

# Loop here as long as we are not in the install procedure 

while ($test->state() eq 'NEED_NON_ESCROW_CSR' || $test->state() eq 'POLICY_INPUT_REQUIRED') {
		
	if ($test->state() eq 'NEED_NON_ESCROW_CSR') {
		$test->diag("Non escrow csr requested - ".$test->param('csr_cert_type'));
	
		$number_of_tests += 5;	
		$test->state_is('NEED_NON_ESCROW_CSR');
		$test->execute_ok('scpers_fetch_puk');
		$test->state_is('NEED_NON_ESCROW_CSR');
		$test->param_like('_puk','/ARRAY.*/');	 
		$test->execute_ok('scpers_post_non_escrow_csr', { pkcs10 => makeCSR(), keyid => 13 });
	}
	
	if ($test->state() eq 'POLICY_INPUT_REQUIRED') {
 		$test->diag("Policy input required");
		$number_of_tests += 3; 		
	  	$test->param_is('policy_input_required','login_ids', 'Check what to do');
	  	$test->param_is('policy_max_login_ids','1', 'Read Policy Setting (max_login_ids)');	
	  	my $login = shift @{ $ser->deserialize($test->param('policy_login_ids'))};	
	  	$test->execute_ok('scpers_apply_csr_policy', { 'login_ids' => $ser->serialize( [ $login ] ) });
	}
	
}

# CSR done - Installs
while ($test->state() =~ /TO_INSTALL/) {

	if ($test->state() eq 'CERT_TO_INSTALL') {
 		$test->diag("Certificate to install");
 		$number_of_tests += 4; 			
		$test->state_is('CERT_TO_INSTALL');
		$test->param_is('cert_install_type','x509', 'Check for x509 type parameter');
		
		$test->param_like('certificate','/-----BEGIN CERTIFICATE.*/','Check for PEM certificate');		 	
		my $cert_identifier = $test->param('cert_identifier');
		write_file("$cert_dir/$cert_identifier.crt", $test->param('certificate'));
		
		my $modulus = getModulus("$cert_dir/$cert_identifier.crt");
		rename "$cert_dir/$modulus.csr", "$cert_dir/$cert_identifier.csr"; 
		rename "$cert_dir/$modulus.key", "$cert_dir/$cert_identifier.key";		
		
	} elsif ($test->state() eq 'PKCS12_TO_INSTALL') {
 		$test->diag("PKCS12 to install");
 		$number_of_tests += 7;		
		$test->state_is('PKCS12_TO_INSTALL');
		$test->execute_ok('scpers_refetch_p12');
		#$test->param_isnt('_keypassword','', 'Check for keypassword');
		$test->param_isnt('_password','', 'Check for password');				
		$test->param_isnt('_pkcs12','', 'Check for P12');           
		my $cert_identifier = $test->param('cert_identifier');		
		
		my $p12 = $test->param('_pkcs12');
		$p12 =~ s/(\S{64})/$1\n/g;
		
		open P12, ">$cert_dir/$cert_identifier.p12";
		print P12 "-----BEGIN PKCS12-----\n$p12\n-----END PKCS12-----";
		close P12;   					
		
		my $pass = $test->param('_password');
        $test->diag("Passwort " . $pass );
	 	`cat $cert_dir/$cert_identifier.p12 | openssl base64 -d | openssl pkcs12 -passin pass:$pass -nodes -nocerts > $cert_dir/$cert_identifier.key`;
	 	$test->is( $?, 0, 'P12 unpack ok' );
		$test->param_like('certificate','/-----BEGIN CERTIFICATE.*/','Check for PEM certificate');		 				
		open PEM, ">$cert_dir/$cert_identifier.crt";
		print PEM $test->param('certificate');
		close PEM;
			
	}
	
	
	$test->execute_ok('scpers_cert_inst_ok');
}

$test->diag("Install done");
 
if ($test->state() eq "HAVE_CERT_TO_DELETE") {

	my %modulus_map;	
	# Loop thru all files in the certs dir and calculate the modulus
	foreach my $cert_file (@paths) { 
   		next unless ($cert_file =~ /\.crt$/);	    	    
	    $modulus_map{ getModulus("$cert_dir/$cert_file") } = "$cert_dir/$cert_file";	      
    }
 	
	while ($test->state() eq "HAVE_CERT_TO_DELETE") {	
		my $modulus = $test->param('keyid');	 
		if ($test->ok($modulus_map{$modulus}, "Look for key file with modulus $modulus")) {
			$test->execute_ok('scpers_cert_del_ok');			
			unlink ($modulus_map{$modulus});
			# test to unlink p12, csr and key file
			$modulus_map{$modulus} =~ s/\.crt$/.p12/;
			-f $modulus_map{$modulus} && unlink ($modulus_map{$modulus});
			$modulus_map{$modulus} =~ s/\.p12$/.key/;
			-f $modulus_map{$modulus} && unlink ($modulus_map{$modulus});
			$modulus_map{$modulus} =~ s/\.key$/.csr/;
			-f $modulus_map{$modulus} && unlink ($modulus_map{$modulus});
			undef $modulus_map{$modulus};
		} else {
			$test->execute_ok('scpers_cert_del_err', { 'sc_error_reason' => 'Failed' });
		}
		$number_of_tests += 2;		
	}
	
	$test->diag("certificates deleted");	
}
 
$test->state_is('SUCCESS'); 
$test->disconnect();

$test->plan( tests => $number_of_tests );
 
sub makeCSR {
	my $cert_type = $test->param('csr_cert_type');
	my $csr_file = "$cert_dir/$cert_type.csr"; 
	my $key_file = "$cert_dir/$cert_type.key";
	`openssl req -new -batch -nodes -keyout $key_file -out $csr_file 2>/dev/null`;
	
	my $modulus = getModulus($key_file);
	rename $csr_file, "$cert_dir/$modulus.csr"; 
	rename $key_file, "$cert_dir/$modulus.key";		
	return scalar read_file("$cert_dir/$modulus.csr");
}

sub getModulus($) {
	my $file = shift;
	
	my $cert_modulus;
	if ($file =~ /\.key$/) {
		$cert_modulus = `openssl rsa -in $file -modulus -noout  | cut -f2 -d=`;	
	} else {
		$cert_modulus = `openssl x509 -in $file -modulus -noout  | cut -f2 -d=`;
	}	 
	chomp $cert_modulus;
	$cert_modulus =~ s/^(?:00)+//g; 
	return sha1_hex(pack("H*", $cert_modulus));	
}
