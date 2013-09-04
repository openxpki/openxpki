#!/usr/bin/perl
use strict;
use warnings;
use English;
use Cwd;
use File::Spec;


my $test_openssl = File::Spec->catfile('t','cfg.binary.openssl');  
my $openxpki_openssl = `cat $test_openssl`;
chomp $openxpki_openssl;
my $test_directory = File::Spec->catfile('t','18_ldap'); 
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

#### create a sasl-client secret key and a certificate
$openssl_command = 
    $openxpki_openssl . 
    ' req -new  -subj /UID=sasl1/DC=openxpki/DC=org -nodes ' .
    ' -keyout ' . File::Spec->catfile( $test_directory_keys, 'saslkey.pem') .
    ' -out    ' . File::Spec->catfile( $test_directory_certs,'saslreq.pem');
system("$openssl_command");    

$openssl_command = 
    $openxpki_openssl . 
    ' x509 -req ' .
    ' -in '      . File::Spec->catfile( $test_directory_certs,  'saslreq.pem') .
    ' -out    '  . File::Spec->catfile( $test_directory_certs, 'saslcert.pem') .
    ' -set_serial 10 ' .
    ' -CA '      . File::Spec->catfile( $test_directory_certs,   'cacert.pem') .
    ' -CAkey '   . File::Spec->catfile( $test_directory_keys,     'cakey.pem');
system("$openssl_command");    
unlink File::Spec->catfile( $test_directory_certs,  'saslreq.pem');    


#### create a restricted sasl-client secret key and a certificate
####   ( having no record in sasldb2 and ldap )
$openssl_command = 
    $openxpki_openssl . 
    ' req -new  -subj /UID=saslx/DC=oopenxpki/DC=org -nodes ' .
    ' -keyout ' . File::Spec->catfile( $test_directory_keys, 'badsaslkey.pem') .
    ' -out    ' . File::Spec->catfile( $test_directory_certs,'badsaslreq.pem');
system("$openssl_command");    

$openssl_command = 
    $openxpki_openssl . 
    ' x509 -req ' .
    ' -in '      . File::Spec->catfile( 
			$test_directory_certs,   'badsaslreq.pem') .
    ' -out    '  . File::Spec->catfile( 
			$test_directory_certs, 	'badsaslcert.pem') .
    ' -set_serial 11 ' .
    ' -CA '      . File::Spec->catfile( $test_directory_certs,   'cacert.pem') .
    ' -CAkey '   . File::Spec->catfile( $test_directory_keys,     'cakey.pem');
system("$openssl_command");    
unlink File::Spec->catfile( $test_directory_certs,  'badsaslreq.pem');    

# #### create a bad sasl-client secret key and a certificate
# ####   (certificate signed by some unknown key )
$openssl_command = 
    $openxpki_openssl . 
    ' req -new  -subj /CN=CA -nodes ' .
    ' -keyout ' . File::Spec->catfile(
			$test_directory_keys, 'badcakey.pem') .
    ' -out    ' . File::Spec->catfile(
			$test_directory_certs,'badcareq.pem');
system("$openssl_command");    

$openssl_command = 
    $openxpki_openssl . 
    ' x509 -req ' .
    ' -in '      . File::Spec->catfile(
			$test_directory_certs,  'badcareq.pem') .
    ' -signkey ' . File::Spec->catfile(
			$test_directory_keys,   'badcakey.pem') .
    ' -out    '  . File::Spec->catfile( 
			$test_directory_certs, 'badcacert.pem');
system("$openssl_command");    

$openssl_command = 
    $openxpki_openssl . 
    ' req -new  -subj /UID=saslx/DC=oopenxpki/DC=org -nodes ' .
    ' -keyout ' . File::Spec->catfile(
			$test_directory_keys, 'verybadsaslkey.pem') .
    ' -out    ' . File::Spec->catfile(
			$test_directory_certs,'verybadsaslreq.pem');
system("$openssl_command");    

$openssl_command = 
    $openxpki_openssl . 
    ' x509 -req ' .
    ' -in '      . File::Spec->catfile( 
			$test_directory_certs,   'verybadsaslreq.pem') .
    ' -out    '  . File::Spec->catfile( 
			$test_directory_certs, 	'verybadsaslcert.pem') .
    ' -set_serial 12 ' .
    ' -CA '      . File::Spec->catfile(
			$test_directory_certs,   'badcacert.pem') .
    ' -CAkey '   . File::Spec->catfile(
			$test_directory_keys,     'badcakey.pem');
system("$openssl_command");    
unlink File::Spec->catfile( $test_directory_certs,  'verybadsaslreq.pem');    
unlink File::Spec->catfile( $test_directory_certs,  'badcareq.pem');    
unlink File::Spec->catfile( $test_directory_certs,  'badcacert.pem');    
unlink File::Spec->catfile( $test_directory_keys,   'badcakey.pem');    

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

1;