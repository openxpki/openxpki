use strict;
use warnings;
use Test;
BEGIN { plan tests => 11 };

print STDERR "OpenXPKI::Crypto::Header\n";

use OpenXPKI::Crypto::TokenManager;
use OpenXPKI::Crypto::Header;

our $cache;
our $cacert;
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
ok(1);

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
