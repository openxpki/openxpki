
use strict;
use warnings;
use Test::More;
use English;

if( not exists $ENV{GOST_OPENSSL_ENGINE} or
    not -e $ENV{GOST_OPENSSL_ENGINE})
{
    plan skip_all => 'OpenSSL GOST engine is not available (no environment variable GOST_OPENSSL_ENGINE)';
}
else
{
    plan tests => 49;
    print STDERR "OpenXPKI::Crypto::Command: Create CA and user certs and issue a CRL with GOST algorithms\n";
}

use OpenXPKI qw( read_file write_file );
use OpenXPKI::Debug;
## $OpenXPKI::Debug::LEVEL{'OpenXPKI::Crypto::Backend::OpenSSL.*'} = 100;
require OpenXPKI::Crypto::TokenManager;
use OpenXPKI::Crypto::Profile::Certificate;
use OpenXPKI::Crypto::Profile::CRL;

our $cache;
our $basedir;
eval `cat t/25_crypto/common.pl`;
ok(1);

#------------------------------- CA ------------------------------------

## parameter checks for TokenManager init

my $mgmt = OpenXPKI::Crypto::TokenManager->new('IGNORE_CHECK' => 1);
ok (1, 'TokenManager');

my $ca_id = "INTERNAL_CA_GOST"; 
my $cn = $ca_id;
$cn =~ s{ INTERNAL_ }{}xms;

my $dir = lc($cn);
$dir =~ s{ _ }{}xms;

my $ca_token = $mgmt->get_token (TYPE => "CA", 
  		                 ID => $ca_id, 
		                 PKI_REALM => "Test GOST Root CA",
                                 CERTIFICATE => "dummy"
	);
ok (1, 'CA token');

## create CA GOST94 key (use passwd from token.xml)
my $ca_key = $ca_token->command ({COMMAND    => "create_key",
                                  TYPE       => "GOST94",
                                  PARAMETERS => {
				    ENC_ALG    => "aes256"}});
ok (1, 'CA key generation');
print STDERR "CA GOST: $ca_key\n" if ($ENV{DEBUG});

# key is present
ok($ca_key =~ /^-----BEGIN.*PRIVATE KEY-----/,
   'Check for presence of a new private key');

# key is encrypted
ok($ca_key =~ /^-----BEGIN ENCRYPTED PRIVATE KEY-----/,
   'Check the encryption of the new private key');
    
## create CA CSR
my $ca_csr = $ca_token->command ({COMMAND => "create_pkcs10",
	                          SUBJECT => "cn=$cn,dc=OpenXPKI,dc=info"});
ok (1);
print STDERR "CA CSR: $ca_csr\n" if ($ENV{DEBUG});
    
## create profile
my $ca_profile = OpenXPKI::Crypto::Profile::Certificate->new (
	CONFIG    => $cache,
	PKI_REALM => "Test GOST Root CA",
	CA        => $ca_id,
	TYPE      => "SELFSIGNEDCA");
$ca_profile->set_serial(1);
ok(1);
print STDERR "Profile is created\n" if ($ENV{DEBUG});

### profile: $profile
    
## create CA cert
my $ca_cert = $ca_token->command ({COMMAND => "create_cert",
	                           PROFILE => $ca_profile,
				   CSR     => $ca_csr});
ok (1);
print STDERR "CA cert: $ca_cert\n" if ($ENV{DEBUG});

# FIXME: create_cert should not write the text representation of the
# cert to the file specified in the configuration
OpenXPKI->write_file (
	FILENAME => "$basedir/$dir/cacert.pem", 
	CONTENT  => $ca_cert,
	FORCE    => 1,
);

## check that the CA is ready for further tests
if (not -e "$basedir/$dir/cakey.pem")
{
    ok(0);
    print STDERR "Missing CA key\n";
} else {
    ok(1);
}

my $content = OpenXPKI->read_file("$basedir/$dir/cakey.pem" );
ok($content =~ /^-----BEGIN.*PRIVATE KEY-----/);
ok($content =~ /^-----BEGIN ENCRYPTED PRIVATE KEY-----/);

if (not -e "$basedir/$dir/cacert.pem")
{
    ok(0);
    print STDERR "Missing CA cert\n";
} else {
    ok(1);
}

#-------------------------- User -------------------------------------------
#------------------------- GOST 94 -----------------------------------------

## parameter checks for get_token
my $token = $mgmt->get_token (TYPE => "DEFAULT",
                              PKI_REALM => "Test GOST Root CA");
ok (1);

## create PIN - just want to check if filter_stdout works correctly
my $passwd = $token->command ({COMMAND       => "create_random",
                               RANDOM_LENGTH => 16});
ok (1);
print STDERR "passwd: $passwd\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/$dir/passwd.txt",
                      CONTENT  => $passwd,
                      FORCE    => 1);

## create GOST94 key
my $key_94 = $token->command ({COMMAND    => "create_key",
                               TYPE       => "GOST94",
                               PASSWD     => $passwd,
                               PARAMETERS => {
                                       ENC_ALG    => "aes256"}});
ok (1);
print STDERR "GOST94 key: $key_94\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/$dir/key_94.pem",
                      CONTENT  => $key_94,
                      FORCE    => 1);

## create profile
my $profile = OpenXPKI::Crypto::Profile::Certificate->new (
                  CONFIG    => $cache,
                  PKI_REALM => "Test GOST Root CA",
                  TYPE      => "ENDENTITY",
                  CA        => "INTERNAL_CA_GOST",
                  ID        => "User",
	      );

## create CSR
my $subject_94 = "cn=John Doe,dc=gost94,dc=OpenXPKI,dc=org";
my $csr_94 = $token->command ({COMMAND => "create_pkcs10",
                               KEY     => $key_94,
                               PASSWD  => $passwd,
                               SUBJECT => $subject_94});
ok (1);
print STDERR "GOST94 CSR: $csr_94\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/$dir/pkcs10.pem", 
                      CONTENT => $csr_94,
                      FORCE    => 1);

$profile->set_serial  (1);
$profile->set_subject ($subject_94);
ok(1);

## create cert
my $cert_94 = $ca_token->command ({COMMAND => "issue_cert",
                                   CSR     => $csr_94,
                                   PROFILE => $profile});
ok (1);
print STDERR "GOST94 cert: $cert_94\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/$dir/cert.pem", 
                      CONTENT => $cert_94,
                      FORCE    => 1);

## build the PKCS#12 file
my @chain = [ $cert_94 ];
my $pkcs12 = $token->command ({COMMAND => "create_pkcs12",
                               PASSWD  => $passwd,
                               KEY     => $key_94,
                               CERT    => $cert_94,
                               CHAIN   => @chain});
ok (1);
print STDERR "GOST94 PKCS#12 length: ".length ($pkcs12)."\n"
    if ($ENV{DEBUG});

#------------------------- GOST 2001 ---------------------------------------

## create GOST2001 key
my $key_2001 = $token->command ({COMMAND    => "create_key",
                                 TYPE       => "GOST2001",
                                 PASSWD     => $passwd,
                                 PARAMETERS => {
                                         ENC_ALG    => "aes256"}});
ok (1);
print STDERR "GOST2001 key: $key_2001\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/$dir/key_2001.pem",
                      CONTENT  => $key_2001,
                      FORCE    => 1);

## create CSR
my $subject_2001 = "cn=John Doe,dc=gost2001,dc=OpenXPKI,dc=org";
my $csr_2001 = $token->command ({COMMAND => "create_pkcs10",
                                 KEY     => $key_2001,
                                 PASSWD  => $passwd,
                                 SUBJECT => $subject_2001});
ok (1);
print STDERR "GOST2001 CSR: $csr_2001\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/$dir/pkcs10_2001.pem", 
                      CONTENT => $csr_2001,
                      FORCE    => 1);

$profile->set_serial  (2);
$profile->set_subject ($subject_2001);
ok(1);

## create cert
my $cert_2001 = $ca_token->command ({COMMAND => "issue_cert",
                                     CSR     => $csr_2001,
                                     PROFILE => $profile});
ok (1);
print STDERR "GOST2001 cert: $cert_2001\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/$dir/cert_2001.pem", 
                      CONTENT => $cert_2001,
                      FORCE    => 1);

#------------------------- GOST 94cp ---------------------------------------

## create GOST94CP key
my $key_94cp = $token->command ({COMMAND    => "create_key",
                                 TYPE       => "GOST94CP",
                                 PASSWD     => $passwd,
                                 PARAMETERS => {
                                         ENC_ALG    => "aes256"}});
ok (1);
print STDERR "GOST94CP key: $key_94cp\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/$dir/key_94cp.pem",
                      CONTENT  => $key_94cp,
                      FORCE    => 1);

## create CSR
my $subject_94cp = "cn=John Doe,dc=gost94cp,dc=OpenXPKI,dc=org";
my $csr_94cp = $token->command ({COMMAND => "create_pkcs10",
                                 KEY     => $key_94cp,
                                 PASSWD  => $passwd,
                                 SUBJECT => $subject_94cp});
ok (1);
print STDERR "GOST94CP CSR: $csr_94cp\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/$dir/pkcs10_94cp.pem", 
                      CONTENT => $csr_94cp,
                      FORCE    => 1);

$profile->set_serial  (3);
$profile->set_subject ($subject_94cp);
ok(1);

## create cert
my $cert_94cp = $ca_token->command ({COMMAND => "issue_cert",
                                     CSR     => $csr_94cp,
                                     PROFILE => $profile});
ok (1);
print STDERR "GOST94CP cert: $cert_94cp\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/$dir/cert_94cp.pem", 
                      CONTENT => $cert_94cp,
                      FORCE    => 1);

#------------------------- GOST 2001cp -------------------------------------

## create GOST2001CP key
my $key_2001cp = $token->command ({COMMAND    => "create_key",
                                   TYPE       => "GOST2001CP",
                                   PASSWD     => $passwd,
                                   PARAMETERS => {
                                           ENC_ALG    => "aes256",
                                           PARAMSET   => "A"
                                   }});
ok (1);
print STDERR "GOST2001CP key: $key_2001cp\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/$dir/key_2001cp.pem",
                      CONTENT  => $key_2001cp,
                      FORCE    => 1);

## create CSR
my $subject_2001cp = "cn=John Doe,dc=gost2001cp,dc=OpenXPKI,dc=org";
my $csr_2001cp = $token->command ({COMMAND => "create_pkcs10",
                                   KEY     => $key_2001cp,
                                   PASSWD  => $passwd,
                                   SUBJECT => $subject_2001cp});
ok (1);
print STDERR "GOST2001CP CSR: $csr_2001cp\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/$dir/pkcs10_2001cp.pem",
                      CONTENT => $csr_2001cp,
                      FORCE    => 1);

$profile->set_serial  (4);
$profile->set_subject ($subject_2001cp);
ok(1);

## create cert
my $cert_2001cp = $ca_token->command ({COMMAND => "issue_cert",
                                       CSR     => $csr_2001cp,
                                       PROFILE => $profile});
ok (1);
print STDERR "GOST2001CP cert: $cert_2001cp\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/$dir/cert_2001cp.pem",
                      CONTENT => $cert_2001cp,
                      FORCE    => 1);

#------------------------- Issue a crl -------------------------------------

### create CRL profile...
$profile = OpenXPKI::Crypto::Profile::CRL->new (
                  CONFIG    => $cache,
                  PKI_REALM => "Test GOST Root CA",
                  CA        => "INTERNAL_CA_GOST");
## otherwise test 34 fails
## $profile->set_serial (1);
### issue crl...
my $crl = $ca_token->command ({COMMAND => "issue_crl",
                               REVOKED => [$cert_94, $cert_2001, $cert_94cp, $cert_2001cp],
                               PROFILE => $profile});
print STDERR "CRL: $crl\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/$dir/crl.pem", 
                      CONTENT => $crl,
                      FORCE    => 1);
ok (1);

#-------------------------- XS tests ---------------------------------------

## create PKCS#10 request
$csr_94 = OpenXPKI->read_file ("$basedir/cagost/pkcs10.pem");
ok(1);

## get object
$csr_94 = $ca_token->get_object ({DATA => $csr_94, TYPE => "CSR"});
ok(1);

## check that all required functions are available and work
foreach my $func ("version", "subject", "subject_hash", "fingerprint",
                  "emailaddress", "extensions", # "attributes",
                  "pubkey_algorithm", "pubkey", "keysize", "modulus", "exponent",
                  "pubkey_hash",
                  "signature_algorithm", "signature")
{
    ## FIXME: this is a bypass of the API !!!
    my $result = $csr_94->$func();
    if (defined $result or $func eq "extensions")
    {
        ok(1);
        print STDERR "$func: $result\n" if ($ENV{DEBUG});
    } else {
        ok(0);
        print STDERR "Error: function $func failed\n";
    }
}

1;
