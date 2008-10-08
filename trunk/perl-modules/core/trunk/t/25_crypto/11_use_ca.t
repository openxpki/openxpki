use strict;
use warnings;
use English;

use Test::More;
plan tests => 20;

diag "OpenXPKI::Crypto::Command: Create a user cert and issue a CRL\n";

use OpenXPKI::Debug;
if ($ENV{DEBUG_LEVEL}) {
    $OpenXPKI::Debug::LEVEL{'.*'} = $ENV{DEBUG_LEVEL};
    $OpenXPKI::Debug::LEVEL{'OpenXPKI::XML::Cache'} = 0;
    $OpenXPKI::Debug::LEVEL{'OpenXPKI::XML::Config'} = 0;
}

use OpenXPKI::Crypto::TokenManager;
use OpenXPKI::Crypto::Profile::Certificate;
use OpenXPKI::Crypto::Profile::CRL;

# use Smart::Comments;

our $cache;
our $basedir;
our $cacert;
eval `cat t/25_crypto/common.pl`;

is($EVAL_ERROR, '', 'common.pl evaluated correctly');

## parameter checks for TokenManager init

my $mgmt = OpenXPKI::Crypto::TokenManager->new('IGNORE_CHECK' => 1);
ok(defined $mgmt, 'new TokenManager defined');

## parameter checks for get_token

my $ca_token      = $mgmt->get_token (TYPE      => "CA",
                                      ID        => "INTERNAL_CA_1",
                                      PKI_REALM => "Test Root CA",
                                      CERTIFICATE => $cacert,
);
ok(defined $ca_token, 'CA Token defined');
my $default_token = $mgmt->get_token (TYPE      => "DEFAULT",
                                      PKI_REALM => "Test Root CA");
ok(defined $default_token, 'Default Token defined');

## create PIN (128 bit == 16 byte)
my $passwd = $default_token->command ({COMMAND       => "create_random",
                                       RANDOM_LENGTH => 16});
ok($passwd, 'Random password created');
diag "passwd: $passwd\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/ca1/passwd.txt",
                      CONTENT  => $passwd,
                      FORCE    => 1);

## create DSA key
my $key = $default_token->command ({COMMAND    => "create_key",
                                    TYPE       => "DSA",
                                    PASSWD     => $passwd,
                                    PARAMETERS => {
                                        KEY_LENGTH => "1024",
                                        ENC_ALG    => "aes256"}});
ok ($key, 'DSA key created');
diag "DSA: $key\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/ca1/dsa.pem",
                      CONTENT  => $key,
                      FORCE    => 1);

## create EC key
$key = $default_token->command ({COMMAND    => "create_key",
                                 TYPE       => "EC",
                                 PASSWD     => $passwd,
                                 PARAMETERS => {
                                     CURVE_NAME => "sect571r1",
                                     ENC_ALG    => "aes256"}});
ok ($key, 'EC key created');
diag "EC: $key\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/ca1/ec.pem",
                      CONTENT  => $key,
                      FORCE    => 1);

## create RSA key
$key = $default_token->command ({COMMAND    => "create_key",
                                 TYPE       => "RSA",
                                 PASSWD     => $passwd,
                                 PARAMETERS => {
                                     KEY_LENGTH => "1024",
                                     ENC_ALG    => "aes256"}});
ok ($key, 'RSA key created');
diag "RSA: $key\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/ca1/rsa.pem",
                      CONTENT  => $key,
                      FORCE    => 1);

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
        diag "OpenXPKI::Exception => ".$exc->as_string()."\n" if ($ENV{DEBUG});
        ok(1, 'Unsupported algorithm caught');
    }
    else
    {
        diag "Unknown eval error: ${EVAL_ERROR}\n";
        ok(0, 'Unsupported algorithm caught');
    }
}
else
{
    diag "Eval error does not occur when algorithm is not supported\n";
    ok(0, 'Unsupported algorithm caught');
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
        diag "OpenXPKI::Exception => ".$exc->as_string()."\n" if ($ENV{DEBUG});
        ok(1, 'Catching wrong keylength');
    }
    else
    {
        diag "Unknown eval error: ${EVAL_ERROR}\n";
        ok(0, 'Catching wrong keylength');
    }
}
else
{
    diag "Eval error does not occur when DSA KEY_LENGTH value is wrong\n";
    ok(0, 'Catching wrong keylength');
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
        diag "OpenXPKI::Exception => ".$exc->as_string()."\n" if ($ENV{DEBUG});
        ok(1, 'Catching unknown algorithm');
    }
    else
    {
        diag "Unknown eval error: ${EVAL_ERROR}\n";
        ok(0, 'Catching unknown algorithm');
    }
}
else
{
    diag "Eval error does not occur when DSA ENC_ALG value is wrong\n" ;
    ok(0, 'Catching unknown algorithm');
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
        diag "OpenXPKI::Exception => ".$exc->as_string()."\n" if ($ENV{DEBUG});
        ok(1, 'Catching RSA wrong keylength');
    }
    else
    {
        diag "Unknown eval error: ${EVAL_ERROR}\n";
        ok(0, 'Catching RSA wrong keylength');
    }
}
else
{
    diag "Eval error does not occur when RSA KEY_LENGTH value is wrong\n" ;
    ok(0, 'Catching RSA wrong keylength');
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
        diag "OpenXPKI::Exception => ".$exc->as_string()."\n" if ($ENV{DEBUG});
        ok(1, 'Catching RSA unknown encryption algorithm');
    }
    else
    {
        diag "Unknown eval error: ${EVAL_ERROR}\n";
        ok(0, 'Catching RSA unknown encryption algorithm');
    }
}
else
{
    diag "Eval error does not occur when RSA ENC_ALG value is wrong\n";
    ok(0, 'Catching RSA unknown encryption algorithm');
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
        diag "OpenXPKI::Exception => ".$exc->as_string()."\n" if ($ENV{DEBUG});
        ok(1, 'Catching EC unknown encryption algorithm');
    }
    else
    {
        diag "Unknown eval error: ${EVAL_ERROR}\n";
        ok(0, 'Catching EC unknown encryption algorithm');
    }
}
else
{
    diag "Eval error does not occur when EC CURVE_NAME value is wrong\n";
    ok(0, 'Catching EC unknown encryption algorithm');
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
        diag "OpenXPKI::Exception => ".$exc->as_string()."\n" if ($ENV{DEBUG});
        ok(1, 'Catching EC wrong curve name');
    }
    else
    {
        diag "Unknown eval error: ${EVAL_ERROR}\n";
        ok(0, 'Catching EC wrong curve name');
    }
}
else
{
    diag "Eval error does not occur when EC CURVE_NAME value is wrong\n";
    ok(0, 'Catching EC wrong curve name');
}

## create CSR
my $subject = "cn=John Dö,dc=OpenXPKI,dc=org";
my $csr = $default_token->command ({COMMAND => "create_pkcs10",
                                    KEY     => $key,
                                    PASSWD  => $passwd,
                                    SUBJECT => $subject});
ok($csr, 'PKCS#10 creation');
diag "CSR: $csr\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/ca1/pkcs10.pem",
                      CONTENT  => $csr,
                      FORCE    => 1);

## create profile
my $profile = OpenXPKI::Crypto::Profile::Certificate->new (
                  CONFIG    => $cache,
                  PKI_REALM => "Test Root CA",
                  TYPE      => "ENDENTITY",
                  CA        => "INTERNAL_CA_1",
                  ID        => "User",
		  );
$profile->set_serial  (1);
$profile->set_subject ($subject);
ok($profile, 'Certificate profile');

## create cert
my $cert = $ca_token->command ({COMMAND => "issue_cert",
                                CSR     => $csr,
                                PROFILE => $profile});
ok ($cert, 'Certificate issuance');
diag "cert: $cert\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/ca1/cert.pem",
                      CONTENT  => $cert,
                      FORCE    => 1);

my @chain = [ $cert ];
## build the PKCS#12 file
my $pkcs12 = $default_token->command ({COMMAND => "create_pkcs12",
                                       PASSWD  => $passwd,
                                       KEY     => $key,
                                       CERT    => $cert,
                                       CHAIN   => @chain});
ok ($pkcs12, 'PKCS#12 creation');
diag "PKCS#12 length: ".length ($pkcs12)."\n" if ($ENV{DEBUG});

### create CRL profile...
$profile = OpenXPKI::Crypto::Profile::CRL->new (
                  CONFIG    => $cache,
                  PKI_REALM => "Test Root CA",
                  CA        => "INTERNAL_CA_1");
## otherwise test 34 fails
$profile->set_serial (23);
### issue crl...
my $crl;
eval
{
    $crl = $ca_token->command ({COMMAND => "issue_crl",
                                   REVOKED => [$cert],
                                   PROFILE => $profile});
    diag "CRL: $crl\n" if ($ENV{DEBUG});
    OpenXPKI->write_file (FILENAME => "$basedir/ca1/crl.pem",
                          CONTENT  => $crl,
                          FORCE    => 1);
};
ok($crl, 'CRL creation') or diag "Exception: $EVAL_ERROR";

1;
