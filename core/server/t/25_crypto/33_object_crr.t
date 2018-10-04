use strict;
use warnings;
use Test::More;
use English;

plan tests => 6;

use_ok "OpenXPKI::Crypto::CRR";

## load CRR
my $data = "-----BEGIN HEADER-----\n".
           "SERIAL=1234\n".
           "REVOKED_CERTIFICATE_SERIAL=12\n".
           "-----END HEADER-----\n";

## init object
my $crr = OpenXPKI::Crypto::CRR->new (DATA => $data);
ok($crr);

## test parser
ok ($crr->get_parsed("HEADER", "SERIAL") == 1234);
ok ($crr->get_parsed("HEADER", "REVOKED_CERTIFICATE_SERIAL") == 12);

## test attribute setting
ok ($crr->set_header_attribute(REASON => "Key compromised."));
ok ($crr->get_parsed("HEADER", "REASON") eq "Key compromised.");

1;
