
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
    plan tests => 42;
    print STDERR "OpenXPKI::Crypto::Command: Create CA and user certs and issue a CRL with GOST algorithm\n";
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

#-------------------------------CA------------------------------------

## parameter checks for TokenManager init

my $mgmt = OpenXPKI::Crypto::TokenManager->new ();
ok (1, 'TokenManager');

my $ca_id = "INTERNAL_CA_GOST"; 
my $cn = $ca_id;
$cn =~ s{ INTERNAL_ }{}xms;

my $dir = lc($cn);
$dir =~ s{ _ }{}xms;

my $ca_token = $mgmt->get_token (TYPE => "CA", 
  		                 ID => $ca_id, 
		                 PKI_REALM => "Test Root CA",
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
	PKI_REALM => "Test Root CA",
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

#--------------------------User-------------------------------------------

## parameter checks for get_token
my $token = $mgmt->get_token (TYPE => "DEFAULT",
                              PKI_REALM => "Test Root CA");
ok (1);

## create PIN - just want to check if filter_stdout works correctly
my $passwd = $token->command ({COMMAND       => "create_random",
                               RANDOM_LENGTH => 16});
ok (1);
print STDERR "passwd: $passwd\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/$dir/passwd.txt", CONTENT => $passwd);

## create GOST94 key
my $key = $token->command ({COMMAND    => "create_key",
                            TYPE       => "GOST94",
                            PASSWD     => $passwd,
                            PARAMETERS => {
                                    ENC_ALG    => "aes256"}});
ok (1);
print STDERR "GOST94: $key\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/$dir/key.pem", CONTENT => $key);

## create profile
my $profile = OpenXPKI::Crypto::Profile::Certificate->new (
                  CONFIG    => $cache,
                  PKI_REALM => "Test Root CA",
                  TYPE      => "ENDENTITY",
                  CA        => "INTERNAL_CA_GOST",
                  ID        => "User",
	      );

## create CSR
my $subject = "cn=John Doe,dc=OpenCA,dc=info";
my $csr = $token->command ({COMMAND => "create_pkcs10",
                            KEY     => $key,
                            PASSWD  => $passwd,
                            SUBJECT => $subject});
ok (1);
print STDERR "CSR: $csr\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/$dir/pkcs10.pem", CONTENT => $csr);

$profile->set_serial  (1);
$profile->set_subject ($subject);
ok(1);

## create cert
my $cert = $ca_token->command ({COMMAND => "issue_cert",
                                CSR     => $csr,
                                PROFILE => $profile});
ok (1);
print STDERR "cert: $cert\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/$dir/cert.pem", CONTENT => $cert);

## build the PKCS#12 file
 my $pkcs12 = $token->command ({COMMAND => "create_pkcs12",
                                PASSWD  => $passwd,
                                KEY     => $key,
                                CERT    => $cert,
                                CHAIN   => $token->get_certfile()});
ok (1);
print STDERR "PKCS#12 length: ".length ($pkcs12)."\n"
    if ($ENV{DEBUG});

### create CRL profile...
$profile = OpenXPKI::Crypto::Profile::CRL->new (
                  CONFIG    => $cache,
                  PKI_REALM => "Test Root CA",
                  CA        => "INTERNAL_CA_GOST");
## otherwise test 34 fails
## $profile->set_serial (1);
### issue crl...
my $crl = $ca_token->command ({COMMAND => "issue_crl",
                               REVOKED => [$cert],
                               PROFILE => $profile});
print STDERR "CRL: $crl\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/$dir/crl.pem", CONTENT => $crl);
ok (1);

#--------------------------XS tests---------------------------------------

## create PKCS#10 request
$csr = OpenXPKI->read_file ("$basedir/cagost/pkcs10.pem");
ok(1);

## get object
$csr = $ca_token->get_object ({DATA => $csr, TYPE => "CSR"});
ok(1);

## check that all required functions are available and work
foreach my $func ("version", "subject", "subject_hash", "fingerprint",
                  "emailaddress", "extensions", # "attributes",
                  "pubkey_algorithm", "pubkey", "keysize", "modulus", "exponent",
                  "pubkey_hash",
                  "signature_algorithm", "signature")
{
    ## FIXME: this is a bypass of the API !!!
    my $result = $csr->$func();
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
