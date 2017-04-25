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

plan tests => 22;

#
# Setup env
#
my $oxitest = OpenXPKI::Test->new->setup_env->init_server();

my $cert   = "-----BEGIN CERTIFICATE-----\nMIIDVjCCAj6gAwIBAgIBATANBgkqhkiG9w0BAQUFADBZMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGTAXBgNVBAMMEEFMUEhBIFNpZ25pbmcgQ0EwHhcNMTcwNDI1MTE0NDA4WhcNNjcw\nNDI1MTE0NDA4WjBCMRMwEQYKCZImiZPyLGQBGRYDb3JnMRgwFgYKCZImiZPyLGQB\nGRYIT3BlblhQS0kxETAPBgNVBAMMCEpvaG4gRMO2MIIBIjANBgkqhkiG9w0BAQEF\nAAOCAQ8AMIIBCgKCAQEA7q6WrYmPkMM5xKmp6xMyzGXN02LGlhMdUzGyVGX4uhu7\nXzJA1HJNKnommiICVbRAcvBQ7mj0QnuVPRYGS5Wx8vwjWjlFhXOXn+y0sS8LUFUt\nCrDbVM26PuORYMqLPV6SSR5WplV8El1OihVh+EvYUUzpy0sWDnP15amR2Z9optAi\nqbAR+7pd1ajOrN2x5ff9DoIfZDqDi1mySUZl//7dcB0Z/fY61YMEVT7gqmJTkMvD\nAJZuzcIUtUYFlH1lA1Ilgaap4/4eqhSCL+X4mrIrePdf/cBrzPwT6GanGMGHXRtn\nJHXyhM6/JEP1z4I8dQ8y+d3byL5qxXyprbzaMA8xkQIDAQABo0AwPjAsBgNVHSUB\nAf8EIjAgBggrBgEFBQcDAgYIKwYBBQUHAwQGCisGAQQBgjcUAgIwDgYDVR0PAQH/\nBAQDAgXgMA0GCSqGSIb3DQEBBQUAA4IBAQAhjRY1hG6A22WuujQLsZ9MnYL4R6X1\nCXpcxbh9dslPtjmaLDPTMAJVP4ZlRK6gf+ULP+IXSFd0qg01tQ4MOTJOO6Uiu+4x\nUK4xlzdTuRWE6MXeCobxpnAMbmbMU1/4k8WRSH3qiZjGlHUoic4C16WmX7tHXsL2\ni8nrmLC9haaFyPzecw28YSL3Y98Xv2japQhywoJRcpkqR4A0OvG9puE0+fDY8lLm\ndKHsoycCtu/IFlANDseX5mke1oz9UP7SFE7FXAXWMurmGZqKzt8OEapY62ZthOP9\n8NP9BB625rCYygcL9QNiCpmN76G3zYkASuGNmELjPdYsdTRwb8tvyuIi\n-----END CERTIFICATE-----\n";

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
my $cert_obj = $default_token->get_object({
    DATA => $cert,
    TYPE => "X509",
});
ok $cert_obj, "Create X509 object";

## check that all required functions are available and work
foreach my $func ("version", "serial", "subject", "openssl_subject", "issuer",
                  "notbefore", "notafter", "fingerprint",
                  "subject_hash", "emailaddress", "extensions",
                  "pubkey_algorithm", "pubkey", "keysize", "modulus", "exponent",
                  "pubkey_hash", "signature_algorithm", "signature") {
    ## FIXME: this is a bypass of the API !!!
    my $result = $cert_obj->$func();
    if (defined $result) {
        pass "$func";
    }
    elsif (grep /$func/, ("emailaddress")) {
        pass "$func: should not be available";
    } else {
        fail "$func";
    }
}

1;
