#!/usr/bin/perl
use strict;
use warnings;
use utf8;

# Core modules
use English;
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;

#use OpenXPKI::Debug; $OpenXPKI::Debug::LEVEL{'OpenXPKI::Crypto.*'} = 100;

# Project modules
use OpenXPKI::FileUtils;
use lib "$Bin/../lib";
use OpenXPKI::Test;

plan tests => 17;

#
# Setup env
#
my $oxitest = OpenXPKI::Test->new->setup_env->init_server();
#$oxitest->insert_testcerts;

my $csr    = "-----BEGIN CERTIFICATE REQUEST-----\nMIIChzCCAW8CAQAwQjETMBEGCgmSJomT8ixkARkWA29yZzEYMBYGCgmSJomT8ixk\nARkWCE9wZW5YUEtJMREwDwYDVQQDDAhKb2huIETDtjCCASIwDQYJKoZIhvcNAQEB\nBQADggEPADCCAQoCggEBAO6ulq2Jj5DDOcSpqesTMsxlzdNixpYTHVMxslRl+Lob\nu18yQNRyTSp6JpoiAlW0QHLwUO5o9EJ7lT0WBkuVsfL8I1o5RYVzl5/stLEvC1BV\nLQqw21TNuj7jkWDKiz1ekkkeVqZVfBJdTooVYfhL2FFM6ctLFg5z9eWpkdmfaKbQ\nIqmwEfu6XdWozqzdseX3/Q6CH2Q6g4tZsklGZf/+3XAdGf32OtWDBFU+4KpiU5DL\nwwCWbs3CFLVGBZR9ZQNSJYGmqeP+HqoUgi/l+JqyK3j3X/3Aa8z8E+hmpxjBh10b\nZyR18oTOvyRD9c+CPHUPMvnd28i+asV8qa282jAPMZECAwEAAaAAMA0GCSqGSIb3\nDQEBCwUAA4IBAQCLNy08onPziRPLxvtqeI5staff0qSXVKmT1nKPGGnNp5PHg8NJ\n4q17cUVNY/mP9GfVl6J3lp8iv8FoqdaOP5O/cAx1ROSPHKAN9P347OZ5hAPxCazg\nrZdRhCVcQsDb1pRXLWvTOo8phKBOa9yIQQqO+oGMB7oSGe39+wN7QmyQGD1f4+dq\nkaQa2kzEMOsCRYKtcQrRm2rNtqzwe/vLUdqsuSYvTFY2WRNkOj548L3sG0AI9+Nl\nxZVvgZqgRlX3naIVKtZt3lBkIJjiNvVxGrgBRLeSoJ5hZRbAMSuX+En0dy/90DQk\n8ToYNrytQlgEsyg9kTZaYbMPTn/aJSrgNYdM\n-----END CERTIFICATE REQUEST-----\n";

#
# Tests
#
use_ok "OpenXPKI::Crypto::TokenManager";

my $default_token;
lives_and {
    my $mgmt = OpenXPKI::Crypto::TokenManager->new;
    $default_token = $mgmt->get_system_token({ TYPE => "DEFAULT" });
    ok $default_token;
} 'Get default token';


## get object
my $csr_obj = $default_token->get_object({
    DATA => $csr,
    TYPE => "CSR"
});
ok(1);

## check that all required functions are available and work
foreach my $func ("version", "subject", "subject_hash", "fingerprint",
                  "emailaddress", "extensions", # "attributes",
                  "pubkey_algorithm", "pubkey", "keysize", "modulus", "exponent",
                  "pubkey_hash",
                  "signature_algorithm", "signature") {
    ## FIXME: this is a bypass of the API !!!
    my $result = $csr_obj->$func();
    if (defined $result) {
        pass "$func";
    }
    elsif (grep /$func/, ("extensions", "emailaddress")) {
        pass "$func: should not be available";
    } else {
        fail "$func";
    }
}

1;
