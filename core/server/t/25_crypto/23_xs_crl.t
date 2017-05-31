#!/usr/bin/perl
use strict;
use warnings;
use utf8;

# Core modules
use English;
use FindBin qw( $Bin );
use File::Temp qw/ tempfile /;

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;

#use OpenXPKI::Debug; $OpenXPKI::Debug::LEVEL{'OpenXPKI::Crypto.*'} = 100;

# Project modules
use OpenXPKI::FileUtils;
use lib "$Bin/../lib";
use OpenXPKI::Test;

plan tests => 13;

#
# Setup env
#
my $oxitest = OpenXPKI::Test->new->setup_env->init_server();

my $crl    = "-----BEGIN X509 CRL-----\nMIICTTCCATUCAQEwDQYJKoZIhvcNAQELBQAwWTETMBEGCgmSJomT8ixkARkWA09S\nRzEYMBYGCgmSJomT8ixkARkWCE9wZW5YUEtJMQ0wCwYDVQQLDARBQ01FMRkwFwYD\nVQQDDBBBTFBIQSBTaWduaW5nIENBFw0xNzA0MjUxMTQ0MDhaGA8yMDY3MDQyNTEx\nNDQwOFowFDASAgEBFw03MDAxMDEwMDAwMDBaoIGPMIGMMH4GA1UdIwR3MHWAFEyR\nZsjqV6Yj2/JGkP1s620OXo2ioVqkWDBWMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgw\nFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxFjAUBgNVBAMM\nDUFMUEhBIFJvb3QgQ0GCAQkwCgYDVR0UBAMCARcwDQYJKoZIhvcNAQELBQADggEB\nADFfaBkH131sF2pksnlScDbDppNVp4gVBN/pVGBJWf2c9R3cKA7qL/sKkDUKGZTm\nK5GD1KJ+knWmtzhfMBH+Brf1zk+VT+8fWGILlMg6bKyAy4WNK02hZUJC6UoDl4CA\nF3VZpNt8CHlFvtWOCyTgIxK8MECJcRRY1l8G9TWsrvBXov3fR/yo2FfuKrm5cqj3\nKz0a4iJbMYzoixn3ySykQiBf4kmNDlB3/MgvAYPwyl2QNC4SnYnr4YUX0onT+Xn/\n7ZUU8jOGDFrShkJeMZFndi2HLUXNXFhJtJm8TFQjAUiYZw+Hy4uDuY9f7UKnapd+\nIOrEI9p27uDUzerqP/yh1QI=\n-----END X509 CRL-----\n";

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
my $crl_obj = $default_token->get_object({
    DATA => $crl,
    TYPE => "CRL",
});
ok $crl_obj, "Create CRL object";

## check that all required functions are available and work
foreach my $func ("version", "issuer", "issuer_hash", "serial",
                  "last_update", "next_update", "fingerprint",
                  "revoked", "signature_algorithm", "signature") {
    ## FIXME: this is a bypass of the API !!!
    my $result = $crl_obj->$func();
    ok (defined $result, $func);
}

1;
