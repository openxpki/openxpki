use strict;
use warnings;
use Test;
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
ok (defined $mgmt);
if (not defined $mgmt)
{
    print STDERR "errno: ".OpenXPKI::Crypto::TokenManager::errno."\n";
    print STDERR "errval: ".OpenXPKI::Crypto::TokenManager::errval."\n";
}

## parameter checks for get_token

my $token = $mgmt->get_token (NAME => "INTERNAL_CA_1", CA_GROUP => "CA_GROUP_1");
ok (defined $token);
if (not defined $token)
{
    print STDERR "errno: ".$mgmt->errno()."\n";
    print STDERR "errval: ".$mgmt->errval()."\n";
}

## load CSR
my $data = OpenXPKI->read_file ("t/crypto/pkcs10.pem");
if ($data)
{
    ok(1);
} else {
    ok(0);
    print STDERR "Error: ".OpenXPKI->errval()."\n";
}
$data = "-----BEGIN HEADER-----\n".
        "ROLE=User\n".
        "SERIAL=4321\n".
        "-----END HEADER-----\n".
        $data;

## init object
my $csr = OpenXPKI::Crypto::CSR->new (TOKEN => $token, DATA => $data);
if ($csr)
{
    ok(1);
} else {
    ok(0);
    print STDERR "Error: ".OpenXPKI::Crypto::CSR->errval()."\n";
}

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
    $csr = OpenXPKI::Crypto::CSR->new (TOKEN => $token, DATA => $data);
}
ok (1);
my $result = Time::HiRes::tv_interval( $begin, [Time::HiRes::gettimeofday()]);
$result = $items / $result;
$result =~ s/\..*$//;
print STDERR " - $result CSRs/second (minimum: 100 per second)\n";
ok ($result > 100);

1;
