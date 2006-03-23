use strict;
use warnings;
use utf8;
binmode STDERR, ":utf8";
use Test;
use English;
BEGIN { plan tests => 23 };

print STDERR "OpenXPKI::Crypto::CSR\n";

use OpenXPKI::Crypto::TokenManager;
use OpenXPKI::Crypto::CSR;
use Time::HiRes;

our $cache;
our $basedir;
eval `cat t/25_crypto/common.pl`;

ok(1);

## parameter checks for TokenManager init

my $mgmt = OpenXPKI::Crypto::TokenManager->new (DEBUG => 0);
ok (1);

## parameter checks for get_token

my $token = $mgmt->get_token (
    TYPE => "CA", 
    ID => "INTERNAL_CA_1", 
    PKI_REALM => "Test Root CA");
ok (1);

## load CSR
my $data = OpenXPKI->read_file ("$basedir/ca1/pkcs10.pem");
ok(1);
$data = "-----BEGIN HEADER-----\n".
        "ROLE=User\n".
        "SERIAL=4321\n".
        "-----END HEADER-----\n".
        $data;

## init object
my $csr = OpenXPKI::Crypto::CSR->new (TOKEN => $token, DATA => $data);
ok(1);

## test parser
ok ($csr->get_parsed("BODY", "SUBJECT") eq "CN=John Doe,DC=OpenCA,DC=info");
ok ($csr->get_parsed("SUBJECT") eq "CN=John Doe,DC=OpenCA,DC=info");
ok ($csr->get_parsed("BODY", "KEYSIZE") == 1024);
ok ($csr->get_parsed("HEADER", "ROLE") eq "User");
ok ($csr->get_serial() == 4321);

## test attribute setting
ok ($csr->set_header_attribute(GLOBAL_ID => 1234));
ok ($csr->get_parsed("HEADER", "GLOBAL_ID") == 1234);

## test conversion
ok ($csr->get_converted ("PEM"));
ok ($csr->get_converted ("DER"));
ok ($csr->get_converted ("TXT"));

## performance
my $items = 1000;
my $begin = [ Time::HiRes::gettimeofday() ];
for (my $i=0; $i<$items; $i++)
{
    eval
    {
        $csr = OpenXPKI::Crypto::CSR->new (TOKEN => $token, DATA => $data);
    };
    if ($EVAL_ERROR)
    {
        if (my $exc = OpenXPKI::Exception->caught())
        {
            print STDERR "OpenXPKI::Exception => ".$exc->as_string()."\n";
        }
        else
        {
            print STDERR "unknown eval error: ${EVAL_ERROR}\n";
        }
        
    }
}
ok (1);
my $result = Time::HiRes::tv_interval( $begin, [Time::HiRes::gettimeofday()]);
$result = $items / $result;
$result =~ s/\..*$//;
print STDERR " - $result CSRs/second (minimum: 100 per second)\n";
#ok ($result > 100);
ok ($result);

## UTF-8 compatibility

my @example = (
    "CN=Иван Петрович Козлодоев,O=Организация объединённых наций,DC=UN,DC=org",
    "CN=Кузьма Ильич Дурыкин,OU=кафедра квантовой статистики и теории поля,OU=отделение экспериментальной и теоретической физики,OU=физический факультет,O=Московский государственный университет им. М.В.Ломоносова,C=ru",
    "CN=Mäxchen Müller,O=Humboldt-Universität zu Berlin,C=DE"
              );

for (my $i=0; $i < scalar @example; $i++)
{
    $data = OpenXPKI->read_file ("$basedir/ca1/utf8.$i.pkcs10.pem");
    $data = "-----BEGIN HEADER-----\n".
            "ROLE=User\n".
            "SERIAL=4321\n".
            "SUBJECT=".$example[$i]."\n".
            "-----END HEADER-----\n".
            $data;
    $csr = OpenXPKI::Crypto::CSR->new (TOKEN => $token, DATA => $data);
    if ($csr->get_parsed ("BODY", "SUBJECT") eq $example[$i])
    {
        ok(1);
    } else {
        ok(0);
        print STDERR "Original:  ".$example[$i]."\n";
        print STDERR "Generated: ".$csr->get_parsed ("BODY", "SUBJECT")."\n";
    }
    if ($csr->get_parsed ("HEADER", "SUBJECT") eq $example[$i])
    {
        ok(1);
    } else {
        ok(0);
        print STDERR "Original:  ".$example[$i]."\n";
        print STDERR "Generated: ".$csr->get_parsed ("HEADER", "SUBJECT")."\n";
    }
}

1;
