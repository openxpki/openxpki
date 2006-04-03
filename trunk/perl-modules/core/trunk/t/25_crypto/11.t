use strict;
use warnings;
use Test;
use English;
BEGIN { plan tests => 19 };

print STDERR "OpenXPKI::Crypto::Command: Create a user cert and issue a CRL\n";

use OpenXPKI::Crypto::TokenManager;
use OpenXPKI::Crypto::Profile::Certificate;
use OpenXPKI::Crypto::Profile::CRL;

# use Smart::Comments;

our $cache;
our $basedir;
eval `cat t/25_crypto/common.pl`;

ok(1);

## parameter checks for TokenManager init

my $mgmt = OpenXPKI::Crypto::TokenManager->new (DEBUG => 0);
ok (1);

## parameter checks for get_token

my $ca_token      = $mgmt->get_token (TYPE      => "CA",
                                      ID        => "INTERNAL_CA_1",
                                      PKI_REALM => "Test Root CA");
my $default_token = $mgmt->get_token (TYPE      => "DEFAULT",
                                      PKI_REALM => "Test Root CA");
ok (1);

## create PIN (128 bit == 16 byte)
my $passwd = $default_token->command ({COMMAND       => "create_random",
                                       RANDOM_LENGTH => 16});
ok (1);
print STDERR "passwd: $passwd\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/ca1/passwd.txt", CONTENT => $passwd);

## create DSA key
my $key = $default_token->command ({COMMAND    => "create_key",
                                    TYPE       => "DSA",
                                    PASSWD     => $passwd,
                                    PARAMETERS => {
                                        KEY_LENGTH => "1024",
                                        ENC_ALG    => "aes256"}});
ok (1);
print STDERR "DSA: $key\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/ca1/dsa.pem", CONTENT => $key);

## create EC key
$key = $default_token->command ({COMMAND    => "create_key",
                                 TYPE       => "EC",
                                 PASSWD     => $passwd,
                                 PARAMETERS => {
                                     CURVE_NAME => "sect571r1",
                                     ENC_ALG    => "aes256"}});
ok (1);
print STDERR "EC: $key\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/ca1/ec.pem", CONTENT => $key);

## create RSA key
$key = $default_token->command ({COMMAND    => "create_key",
                                 TYPE       => "RSA",
                                 PASSWD     => $passwd,
                                 PARAMETERS => {
                                     KEY_LENGTH => "1024",
                                     ENC_ALG    => "aes256"}});
ok (1);
print STDERR "RSA: $key\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/ca1/rsa.pem", CONTENT => $key);

## try to create UNSUPPORTED_ALGORITHM key 
eval
{
    $key = $default_token->command ({COMMAND    => "create_key",
                                     TYPE       => "UNSUPPORTED_ALGORITHM",
                                     PASSWD     => $passwd,
                                     PARAMETERS => {
                                         KEY_LENGTH => "1024",
                                         ENC_ALG    => "aes256"}});
};

if ($EVAL_ERROR) {
    if (my $exc = OpenXPKI::Exception->caught())
    {
        print STDERR "OpenXPKI::Exception => ".$exc->as_string()."\n" if ($ENV{DEBUG});
        ok(1);
    }
    else
    {
        print STDERR "Unknown eval error: ${EVAL_ERROR}\n" if ($ENV{DEBUG});
        ok(0);
    }
}
else
{
    print STDERR "Eval error does not occur when algorithm is not supported\n" if ($ENV{DEBUG});
    ok(0);
}

## test DSA parameters
## create DSA key with wrong KEY_LENGTH value
eval
{
    $key = $default_token->command ({COMMAND    => "create_key",
                                     TYPE       => "DSA",
                                     PASSWD     => $passwd,
                                     PARAMETERS => {
                                         KEY_LENGTH => "11024",
                                         ENC_ALG    => "aes256"}});
};

if ($EVAL_ERROR) {
    if (my $exc = OpenXPKI::Exception->caught())
    {
        print STDERR "OpenXPKI::Exception => ".$exc->as_string()."\n" if ($ENV{DEBUG});
        ok(1);
    }
    else
    {
        print STDERR "Unknown eval error: ${EVAL_ERROR}\n" if ($ENV{DEBUG});
        ok(0);
    }
}
else
{
    print STDERR "Eval error does not occur when DSA KEY_LENGTH value is wrong\n" 
      if ($ENV{DEBUG});
    ok(0);
}

## create DSA key with wrong ENC_ALG value
eval
{
    $key = $default_token->command ({COMMAND    => "create_key",
                                     TYPE       => "DSA",
                                     PASSWD     => $passwd,
                                     PARAMETERS => {
                                         KEY_LENGTH => "1024",
                                         ENC_ALG    => "unknown_alg"}});
};

if ($EVAL_ERROR) {
    if (my $exc = OpenXPKI::Exception->caught())
    {
        print STDERR "OpenXPKI::Exception => ".$exc->as_string()."\n" if ($ENV{DEBUG});
        ok(1);
    }
    else
    {
        print STDERR "Unknown eval error: ${EVAL_ERROR}\n" if ($ENV{DEBUG});
        ok(0);
    }
}
else
{
    print STDERR "Eval error does not occur when DSA ENC_ALG value is wrong\n" 
      if ($ENV{DEBUG});
    ok(0);
}

## test RSA parameters
## create RSA key with wrong KEY_LENGTH value
eval
{
    $key = $default_token->command ({COMMAND    => "create_key",
                                     TYPE       => "RSA",
                                     PASSWD     => $passwd,
                                     PARAMETERS => {
                                         KEY_LENGTH => "11024",
                                         ENC_ALG    => "aes256"}});
};

if ($EVAL_ERROR) {
    if (my $exc = OpenXPKI::Exception->caught())
    {
        print STDERR "OpenXPKI::Exception => ".$exc->as_string()."\n" if ($ENV{DEBUG});
        ok(1);
    }
    else
    {
        print STDERR "Unknown eval error: ${EVAL_ERROR}\n" if ($ENV{DEBUG});
        ok(0);
    }
}
else
{
    print STDERR "Eval error does not occur when RSA KEY_LENGTH value is wrong\n" 
      if ($ENV{DEBUG});
    ok(0);
}

## create RSA key with wrong ENC_ALG value
eval
{
    $key = $default_token->command ({COMMAND    => "create_key",
                                     TYPE       => "RSA",
                                     PASSWD     => $passwd,
                                     PARAMETERS => {
                                         KEY_LENGTH => "1024",
                                         ENC_ALG    => "unknown_alg"}});
};

if ($EVAL_ERROR) {
    if (my $exc = OpenXPKI::Exception->caught())
    {
        print STDERR "OpenXPKI::Exception => ".$exc->as_string()."\n" if ($ENV{DEBUG});
        ok(1);
    }
    else
    {
        print STDERR "Unknown eval error: ${EVAL_ERROR}\n" if ($ENV{DEBUG});
        ok(0);
    }
}
else
{
    print STDERR "Eval error does not occur when RSA ENC_ALG value is wrong\n" 
      if ($ENV{DEBUG});
    ok(0);
}

## test EC parameters
## create EC key with wrong ENC_ALG value
eval
{

    $key = $default_token->command ({COMMAND    => "create_key",
                                     TYPE       => "EC",
                                     PASSWD     => $passwd,
                                     PARAMETERS => {
                                         CURVE_NAME => "sect571r1",
                                         ENC_ALG    => "unknown_alg"}});
};

if ($EVAL_ERROR) {
    if (my $exc = OpenXPKI::Exception->caught())
    {

## FIXME Unfortunately we don't understand why this exception 
## is printed to STDERR... May be it's an error in newly added code.

        print STDERR "OpenXPKI::Exception => ".$exc->as_string()."\n" if ($ENV{DEBUG});
        ok(1);
    }
    else
    {
        print STDERR "Unknown eval error: ${EVAL_ERROR}\n" if ($ENV{DEBUG});
        ok(0);
    }
}
else
{
    print STDERR "Eval error does not occur when EC CURVE_NAME value is wrong\n" 
      if ($ENV{DEBUG});
    ok(0);
}

## create EC key with wrong CURVE_NAME value
eval
{
    $key = $default_token->command ({COMMAND    => "create_key",
                                     TYPE       => "EC",
                                     PASSWD     => $passwd,
                                     PARAMETERS => {
                                         CURVE_NAME => "unknown_curve",
                                         ENC_ALG    => "aes256"}});
};

if ($EVAL_ERROR) {
    if (my $exc = OpenXPKI::Exception->caught())
    {
        print STDERR "OpenXPKI::Exception => ".$exc->as_string()."\n" if ($ENV{DEBUG});
        ok(1);
    }
    else
    {
        print STDERR "Unknown eval error: ${EVAL_ERROR}\n" if ($ENV{DEBUG});
        ok(0);
    }
}
else
{
    print STDERR "Eval error does not occur when EC CURVE_NAME value is wrong\n" 
      if ($ENV{DEBUG});
    ok(0);
}

## create CSR
my $subject = "cn=John Doe,dc=OpenCA,dc=info";
my $csr = $default_token->command ({COMMAND => "create_pkcs10",
                                    KEY     => $key,
                                    PASSWD  => $passwd,
                                    SUBJECT => $subject});
ok (1);
print STDERR "CSR: $csr\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/ca1/pkcs10.pem", CONTENT => $csr);

## create profile
my $profile = OpenXPKI::Crypto::Profile::Certificate->new (
                  DEBUG     => 0,
                  CONFIG    => $cache,
                  PKI_REALM => "Test Root CA",
                  TYPE      => "ENDENTITY",
                  CA        => "INTERNAL_CA_1",
                  ID        => "User",
		  );
$profile->set_serial  (1);
$profile->set_subject ($subject);
ok(1);

## create cert
my $cert = $ca_token->command ({COMMAND => "issue_cert",
                                CSR     => $csr,
                                PROFILE => $profile});
ok (1);
print STDERR "cert: $cert\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/ca1/cert.pem", CONTENT => $cert);

## build the PKCS#12 file
my $pkcs12 = $default_token->command ({COMMAND => "create_pkcs12",
                                       PASSWD  => $passwd,
                                       KEY     => $key,
                                       CERT    => $cert,
                                       CHAIN   => $ca_token->get_certfile()});
ok (1);
print STDERR "PKCS#12 length: ".length ($pkcs12)."\n" if ($ENV{DEBUG});

### create CRL profile...
$profile = OpenXPKI::Crypto::Profile::CRL->new (
                  DEBUG     => 0,
                  CONFIG    => $cache,
                  PKI_REALM => "Test Root CA",
                  CA        => "INTERNAL_CA_1");
## otherwise test 34 fails
## $profile->set_serial (1);
### issue crl...
my $crl = $ca_token->command ({COMMAND => "issue_crl",
                               REVOKED => [$cert],
                               PROFILE => $profile});
print STDERR "CRL: $crl\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/ca1/crl.pem", CONTENT => $crl);
ok (1);

1;
