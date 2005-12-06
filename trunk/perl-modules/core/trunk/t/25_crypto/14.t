use strict;
use warnings;
use utf8;
binmode STDERR, ":utf8";
use Test;
BEGIN { plan tests => 16 };

print STDERR "OpenXPKI::Crypto::Command: Create user certs and issue CRLs with UTF-8 characters\n";

use OpenXPKI::Crypto::TokenManager;

our $cache;
our $basedir;
eval `cat t/25_crypto/common.pl`;

ok(1);

## parameter checks for TokenManager init

my $mgmt = OpenXPKI::Crypto::TokenManager->new (DEBUG => 0, CONFIG => $cache);
ok (1);

## parameter checks for get_token

my $token = $mgmt->get_token (TYPE => "CA", NAME => "INTERNAL_CA_1", PKI_REALM => "Test Root CA");
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
    my $csr = $token->command ("create_pkcs10",
                               CONFIG  => "$basedir/ca1/openssl.cnf",
                               KEY     => $key,
                               PASSWD  => $passwd,
                               SUBJECT => $dn);
    ok (1);
    print STDERR "CSR: $csr\n" if ($ENV{DEBUG});
    OpenXPKI->write_file (FILENAME => "$basedir/ca1/utf8.$i.pkcs10.pem", CONTENT => $csr);

    ## create cert
    my $cert = $token->command ("issue_cert",
                                CSR    => $csr,
                                CONFIG => "$basedir/ca1/openssl.cnf",
                                SERIAL => 1);
    ok (1);
    print STDERR "cert: $cert\n" if ($ENV{DEBUG});
    OpenXPKI->write_file (FILENAME => "$basedir/ca1/utf8.$i.cert.pem", CONTENT => $cert);

    ## build the PKCS#12 file
    my $pkcs12 = $token->command ("create_pkcs12",
                                  PASSWD  => $passwd,
                                  KEY     => $key,
                                  CERT    => $cert,
                                  CHAIN   => $token->get_certfile());
    ok (1);
    print STDERR "PKCS#12 length: ".length ($pkcs12)."\n" if ($ENV{DEBUG});

    ## create CRL
    my $crl = $token->command ("issue_crl", REVOKED => [$cert], SERIAL => 1);
    ok (1);
    print STDERR "CRL: $crl\n" if ($ENV{DEBUG});
    OpenXPKI->write_file (FILENAME => "$basedir/ca1/utf8.$i.crl.pem", CONTENT => $crl);
}

1;
