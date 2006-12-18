use strict;
use warnings;
use utf8;
binmode STDERR, ":utf8";
binmode STDOUT, ":utf8";
use Test;
BEGIN { plan tests => 20 };

print STDERR "OpenXPKI::Crypto::Command: Create user certs and issue CRLs with UTF-8 characters\n";

use OpenXPKI::Crypto::TokenManager;
use OpenXPKI::Crypto::Profile::Certificate;
use OpenXPKI::Crypto::Profile::CRL;

our $cache;
our $cacert;
our $basedir;
eval `cat t/25_crypto/common.pl`;

ok(1);

## parameter checks for TokenManager init

my $mgmt = OpenXPKI::Crypto::TokenManager->new('IGNORE_CHECK' => 1);
ok (1);

## parameter checks for get_token

my $token = $mgmt->get_token (
    TYPE => "CA", 
    ID => "INTERNAL_CA_1", 
    PKI_REALM => "Test Root CA",
    CERTIFICATE => $cacert,
);
ok (1);

my $default_token = $mgmt->get_token (TYPE      => "DEFAULT",
                                      PKI_REALM => "Test Root CA");
ok (1);

## the following operations are already performed by other tests
## create PIN (128 bit == 16 byte)
## create DSA key
## create RSA key

my $passwd = OpenXPKI->read_file ("$basedir/ca1/passwd.txt");
my $key    = OpenXPKI->read_file ("$basedir/ca1/rsa.pem");
ok (1);

######################################
## here starts the utf-8 mass tests ##
######################################

my @example = (
    "CN=Иван Петрович Козлодоев,O=Организация объединённых наций,DC=UN,DC=org",
    "CN=Кузьма Ильич Дурыкин,OU=кафедра квантовой статистики и теории поля,OU=отделение экспериментальной и теоретической физики,OU=физический факультет,O=Московский государственный университет им. М.В.Ломоносова,C=ru",
    "CN=Mäxchen Müller,O=Humboldt-Universität zu Berlin,C=DE"
              );

for (my $i=0; $i < scalar @example; $i++)
{
    my $dn = $example[$i];

    ## create CSR
    my $csr = $default_token->command ({COMMAND => "create_pkcs10",
                                KEY     => $key,
                                PASSWD  => $passwd,
                                SUBJECT => $dn});
    ok (1);
    print STDERR "CSR: $csr\n" if ($ENV{DEBUG});
    OpenXPKI->write_file (FILENAME => "$basedir/ca1/utf8.$i.pkcs10.pem", CONTENT => $csr, FORCE => 1);

    ## create profile
    my $profile = OpenXPKI::Crypto::Profile::Certificate->new (
                      CONFIG    => $cache,
                      PKI_REALM => "Test Root CA",
		      TYPE      => "ENDENTITY",
                      CA        => "INTERNAL_CA_1",
                      ID        => "User");
    $profile->set_serial  (1);
    $profile->set_subject ($dn);
    ok(1);

    ## create cert
    my $cert = $token->command ({COMMAND => "issue_cert",
                                 CSR     => $csr,
                                 PROFILE => $profile});
    ok (1);
    print STDERR "cert: $cert\n" if ($ENV{DEBUG});
    OpenXPKI->write_file (FILENAME => "$basedir/ca1/utf8.$i.cert.pem", CONTENT => $cert, FORCE => 1);

    ## build the PKCS#12 file
    my @chain = [ $cacert ];
    my $pkcs12 = $default_token->command ({COMMAND => "create_pkcs12",
                                   PASSWD  => $passwd,
                                   KEY     => $key,
                                   CERT    => $cert,
                                   CHAIN   => @chain});
    ok ($pkcs12);
    print STDERR "PKCS#12 length: ".length ($pkcs12)."\n" if ($ENV{DEBUG});
    # FIXME: this test fails since at least 495, so it has nothing to
    # do with the changes from 495 to 496. 
    # It just was not noticed because it had ok(1) and the CLI did
    # not catch the error
    # The openssl error is
    # No certificate matches private key

    ## create CRL
    $profile = OpenXPKI::Crypto::Profile::CRL->new (
                   CONFIG    => $cache,
                   PKI_REALM => "Test Root CA",
                   CA        => "INTERNAL_CA_1");
    $profile->set_serial (1);
    my $crl = $token->command ({COMMAND => "issue_crl",
                                REVOKED => [$cert],
                                PROFILE => $profile});
    ok (1);
    print STDERR "CRL: $crl\n" if ($ENV{DEBUG});
    OpenXPKI->write_file (FILENAME => "$basedir/ca1/utf8.$i.crl.pem", CONTENT => $crl, FORCE => 1);
}

1;
