use strict;
use warnings;
use Test;
BEGIN { plan tests => 11 };

print STDERR "OpenXPKI::Crypto::Header\n";

use OpenXPKI::XML::Cache;
use OpenXPKI::Crypto::TokenManager;
use OpenXPKI::Crypto::Header;
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

## define a test object
my $testdata = <<EOF
-----BEGIN HEADER-----
SINGLE=1234567890
MULTI=
-----BEGIN ATTRIBUTE-----
blabla
trara
-----END ATTRIBUTE-----
-----END HEADER-----
This is the body of the testdata.
EOF
;

## test object creation
my $header = OpenXPKI::Crypto::Header->new (DATA => $testdata);
if ($header)
{
    ok(1);
} else {
    ok(0);
    print STDERR "Error: ".OpenXPKI::Crypto::Header->errval()."\n";
}

## verify parsing
ok($header->get_attribute ("SINGLE") eq "1234567890");
ok($header->get_attribute ("MULTI") eq "blabla\ntrara");
ok($header->get_body() eq "This is the body of the testdata.");

## set new attibute
ok($header->set_attribute ("NEW_SINGLE" => "abc"));
ok($header->set_attribute ("NEW_MULTI" => "abc\ndef"));
ok($header->get_attribute ("NEW_SINGLE") eq "abc");
ok($header->get_attribute ("NEW_MULTI") eq "abc\ndef");

1;
