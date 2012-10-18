#!/usr/bin/perl
use strict;
use warnings;
use English;
use Cwd;
use File::Spec;

my $test_openssl = File::Spec->catfile('t','cfg.binary.openssl');  
my $openxpki_openssl = `cat $test_openssl`;
chomp $openxpki_openssl;
my $test_directory = File::Spec->catfile('t','50_auth'); 
#my $test_directory = '.';

my $test_directory_certs   = File::Spec->catfile(
					$test_directory,
    					'ldap_certs',
			     ); 
my $test_directory_keys   = File::Spec->catfile(
					$test_directory,
    					'ldap_keys',
			     ); 

my $openssl_command;

#### create CA key and cert
$openssl_command = 
    $openxpki_openssl . 
    ' req -new  -subj /CN=CA -nodes ' .
    ' -keyout ' . File::Spec->catfile( $test_directory_keys, 'cakey.pem') .
    ' -out    ' . File::Spec->catfile( $test_directory_certs,'careq.pem');
system("$openssl_command");    

$openssl_command = 
    $openxpki_openssl . 
    ' x509 -req ' .
    ' -in '      . File::Spec->catfile( $test_directory_certs,  'careq.pem') .
    ' -signkey ' . File::Spec->catfile( $test_directory_keys,   'cakey.pem') .
    ' -out    '  . File::Spec->catfile( $test_directory_certs, 'cacert.pem');
system("$openssl_command");    
unlink File::Spec->catfile( $test_directory_certs,  'careq.pem');    

# #### create a server secret key and a certificate
$openssl_command = 
    $openxpki_openssl . 
    ' req -new  -subj /CN=localhost -nodes ' .
    ' -keyout ' . File::Spec->catfile(
		        $test_directory_keys, 'serverkey.pem') .
    ' -out    ' . File::Spec->catfile(
			$test_directory_certs,'serverreq.pem');
system("$openssl_command");    

$openssl_command = 
    $openxpki_openssl . 
    ' x509 -req ' .
    ' -in '      . File::Spec->catfile(
			$test_directory_certs,  'serverreq.pem') .
    ' -out    '  . File::Spec->catfile(
			$test_directory_certs, 'servercert.pem') .
    ' -set_serial 13 ' .
    ' -CA '      . File::Spec->catfile(
			$test_directory_certs,   'cacert.pem') .
    ' -CAkey '   . File::Spec->catfile(
			$test_directory_keys,     'cakey.pem');
system("$openssl_command");    
unlink File::Spec->catfile( $test_directory_certs,  'serverreq.pem');    

# hashing CA cert name
$openssl_command = 
    $openxpki_openssl . 
    ' x509 -hash -noout < ' .
    File::Spec->catfile(
	$test_directory_certs,   'cacert.pem');
my $cacert_hashed_name = `$openssl_command`;
chomp $cacert_hashed_name;
$cacert_hashed_name = $cacert_hashed_name  . '.0';

#print STDERR 'HASHED >>>' . $cacert_hashed_name . '<<<' . "\n";
my $system_command = 
    'cp ' . 
    File::Spec->catfile(
	$test_directory_certs,   'cacert.pem') . ' ' .
    File::Spec->catfile(
	$test_directory_certs,   $cacert_hashed_name);
system($system_command);

1;