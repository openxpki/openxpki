use strict;
use warnings;
use Test;
use English;
BEGIN { plan tests => 17 };

print STDERR "OpenXPKI::Crypto::CSR\n";

use OpenXPKI::XML::Cache;
use OpenXPKI::Crypto::TokenManager;
use OpenXPKI::Crypto::CSR;
use Time::HiRes;

ok(1);

## init the XML cache

my $cache = OpenXPKI::XML::Cache->new(DEBUG  => 0,
                                      CONFIG => [ "t/crypto/token.xml" ]);

## parameter checks for TokenManager init

my $mgmt = OpenXPKI::Crypto::TokenManager->new (DEBUG => 0, CACHE => $cache);
ok (1);

## parameter checks for get_token

my $token = $mgmt->get_token (NAME => "INTERNAL_CA_1", CA_GROUP => "CA_GROUP_1");
ok (1);

## load CSR
my $data = OpenXPKI->read_file ("t/crypto/pkcs10.pem");
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
ok ($result > 100);

1;
