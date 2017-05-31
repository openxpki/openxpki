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

#use OpenXPKI::Debug; $OpenXPKI::Debug::LEVEL{'OpenXPKI::Crypto::CLI.*'} = 100;

# Project modules
use OpenXPKI::FileUtils;
use lib "$Bin/../lib";
use OpenXPKI::Test;

plan tests => 16;

#
# Setup env
#
my $oxitest = OpenXPKI::Test->new->setup_env->init_server();
$oxitest->insert_testcerts;

my $passwd = "vcgT7MtIRrZJmWVTgTsO+w";
my $dsa    = "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIICrzBJBgkqhkiG9w0BBQ0wPDAbBgkqhkiG9w0BBQwwDgQITEGk3D73FL0CAggA\nMB0GCWCGSAFlAwQBKgQQ7ijEla44y8CAMYJr5RFhOgSCAmB1PEQzbL3hBI8yD0zx\n9YFV52Cj3hiMl9F+q3bpC2Uax9cwwqgQfa2+jcrIEmoocQV6VJl+j5wzHMDbkVcg\nHnEPtbAn/3nv0W8zvqOKqNJDf0P4DHSvOKfK3tctQpKO2lUgEQ5AejcP5s3WphQC\nJ+7LW+0aZhwPDVsDdBcXVaDocyb9fQ6iw3PC3xafgC0ngy8tXdkWXSlCN2MNOZT6\nOpbzn+SUnHOfMr1QzddQq8BO8Zbjo2Bx37ZySjil/CQxW/Wfz4lhBUS3MpmV6HH3\ncBu29JvogA1Uxo86FRRrrxxvmadwJius1M8rrfkVToWDHtwztkUb7ylW8MoZNtax\n2xEF1U/upoOcRn33gVREeGqmoar5dk6zLA9sU85/UBtT6iBucthWhuzDkpVqDNuc\n6f+pbnuLPp8KyiYJG1qNGEU/Ua+z1Ks1wtwsd9hwSDyt1l1SrHTp/huyLKT/QXPB\n7X/hxsxuCcVG0P67sxdUTsFNac+rJNLFpOv10qmVgmDbnCUSeZJUMDnVZnOzQcLu\n7LZrQG2FkQk5Ipfmrn14gI7pA2QarQ8J9yBhzqq53LTWGxwZUuO6dzolNlsklYV8\nN+i7XsL/j4bPfGe+yrK9OQYmMstjLkjP9u0aPuIvqwCDQ5y0CuF4AP1UMC1mJyak\n7rGp6OEMgDlIRFCb313XYbaqbRhWvN2GGWUH6a9OGjzaVhDjKhf4uk7tJO4GsObm\nFYa7r9DoKhDzbBAZQo/Jj8PBtH4phsZ9Iz7Kvtj4C9HXlrzHTnO5xQ9jzTVtSUax\nqviSQK2qmPpdommwRGQgkL3+kQ==\n-----END ENCRYPTED PRIVATE KEY-----\n";
my $rsa    = "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFHzBJBgkqhkiG9w0BBQ0wPDAbBgkqhkiG9w0BBQwwDgQISNoARhy+9wACAggA\nMB0GCWCGSAFlAwQBKgQQirJStjGiObx5dsFHCJg4sgSCBNAFyOpg4yIXOEpDyr+t\ntz7WARhPVJLziYKPT83W+dQwwjUyBFlPWdbzGsA6CeMf5WoRPhRFBm6MBbxhsRk2\nmas8BgKDddIxMU/M4RaDD62nIpfUHkGsdh97kxzUZElDeORQS9m9y/b6b4BMx+vH\n9Zu6e6unlhZjBSnDiOYfbI4DBySZH+imjQPNXYkn2WwSH2Dh2VyuzdvxWvUlaNeU\nwOWi3iknatyKyE33fnSpA9AmsSwnfPWyQ77kKffkYbFZq337iyckz7GIWaNPVH/r\niJ6rS+60KB2no5mAROQ8ixMKT56rKK8cl4kowMpV7S0+sO4j3RqVePwCUX/qScS5\nP6+YMl326ZWyChzuiuSLbjz95GR0DKXIlMK5JGgq4KNl4LIysU5gn8OBNqXW5Dkr\nQmU5zQllhO3iSwuv+lNBBh7lDj5iWVPIn6O911d8wOJVsME16UKGqVicuz+cDhZB\nQCBtJkZ8m1CgDviDGZoqgoSyQA1BLo4gKNfZqfyFoupJjDtqPvngjCQZtuYwlZ+d\nu/FpsTPhYa9qx23HGKaDPZ95lOkEYfGQ9ClbkzI1cCMLzgUNSgFcSGczpt+EgrqF\nA+lJFToyetO9BpeTIgQyUJiaFm7/9hZEHJNPUH6MXrQDVYjgHgtEn8406Luh2vrd\nk8cUqd6YZADZSUxNElCbmhzyp6YNMYzO6xp/kCXq/MOhvWvtOzTnVq7YgCUgtDry\ngj7WegLI+BUtBxvVSXq6w8lyW4lisVz/KVxgmjHdNMtj5L8g6UJzVnAy/ecpVi91\njVcz8gHxWxvedVjoJBOx21BismVFLadOrU3pMmj33SdjePC7ON9DCZ8KVSHoENym\nYEWoMxCNKM0s74WoK6FCwJBAS5V3qnsvPRXw8bsB2B3Nt2BcM31o2ohPba5n9T/p\nwUkEBq6K7hsceUfMgkZbcGiJbxiipT/lbLpDW3IpaH0//BVJDRXFvwd43nwby0E0\nB0l9md98Hq4fUEZBpIXuaoxSw6cJRh5GI+h4pmbx/PQaSWV63bjZTd9WcGggdy80\nYe873PfOeQ3oFMJyg/Zn2OAFBNVGMmaP7l1fkOYTCOu69yK8+Q6q3KDkRKZU/Pec\nEKvciwXA3Z2p45Q8HHzNUZGpbr27ZCp6gyHLyXLcOePPyS4AExw6Vyu1UWcdaozj\nPg+luu+dlgu+S+2sIfhXgihDWH/iOTcxP/kHdC74Ee+OqflrJ7FZlrvNshEjNvvM\nLxmtDBj98YG5r45k56mOKSDjyLfU+MgjD2Lj1TMFYOY2AuZY6GY+OiXJPDyVc8Bv\nnDPV9+IO3Auq9gNjYEAlUUfw4eJHve3fnSZs3ifAyhELNfds5fhJOTUxhbHB7tip\nZiYIh61WY5wSnTmd2ZZKPZHQa/UL+WgxHF6Jsr8BAXgzC7PAallBNP44/pP9ED/B\nBP3Fce97R6k9pR1Cxegq8NFEm9zM/cwDKhhQrFlZ5rcMOy6qDk8bU2ZkamBtVXFo\nRnGd4qjtS+aCWfz+fjmYz1Pdz+ju6H0jfAjoyHc1WWYbeDM1S7C1XN9D3K2md56A\nm5SydJXOqO+eRjfOBB9m/nneB7sd8LPwaXUB3VOdiKX0LEW8GIprPDmp3C4tEpef\ni9d8OJm/t2KAaBchNlJOauEvBw==\n-----END ENCRYPTED PRIVATE KEY-----\n";
my $cert_subject = "cn=John Dö,dc=OpenXPKI,dc=org";
my $csr    = "-----BEGIN CERTIFICATE REQUEST-----\nMIIChzCCAW8CAQAwQjETMBEGCgmSJomT8ixkARkWA29yZzEYMBYGCgmSJomT8ixk\nARkWCE9wZW5YUEtJMREwDwYDVQQDDAhKb2huIETDtjCCASIwDQYJKoZIhvcNAQEB\nBQADggEPADCCAQoCggEBAO6ulq2Jj5DDOcSpqesTMsxlzdNixpYTHVMxslRl+Lob\nu18yQNRyTSp6JpoiAlW0QHLwUO5o9EJ7lT0WBkuVsfL8I1o5RYVzl5/stLEvC1BV\nLQqw21TNuj7jkWDKiz1ekkkeVqZVfBJdTooVYfhL2FFM6ctLFg5z9eWpkdmfaKbQ\nIqmwEfu6XdWozqzdseX3/Q6CH2Q6g4tZsklGZf/+3XAdGf32OtWDBFU+4KpiU5DL\nwwCWbs3CFLVGBZR9ZQNSJYGmqeP+HqoUgi/l+JqyK3j3X/3Aa8z8E+hmpxjBh10b\nZyR18oTOvyRD9c+CPHUPMvnd28i+asV8qa282jAPMZECAwEAAaAAMA0GCSqGSIb3\nDQEBCwUAA4IBAQCLNy08onPziRPLxvtqeI5staff0qSXVKmT1nKPGGnNp5PHg8NJ\n4q17cUVNY/mP9GfVl6J3lp8iv8FoqdaOP5O/cAx1ROSPHKAN9P347OZ5hAPxCazg\nrZdRhCVcQsDb1pRXLWvTOo8phKBOa9yIQQqO+oGMB7oSGe39+wN7QmyQGD1f4+dq\nkaQa2kzEMOsCRYKtcQrRm2rNtqzwe/vLUdqsuSYvTFY2WRNkOj548L3sG0AI9+Nl\nxZVvgZqgRlX3naIVKtZt3lBkIJjiNvVxGrgBRLeSoJ5hZRbAMSuX+En0dy/90DQk\n8ToYNrytQlgEsyg9kTZaYbMPTn/aJSrgNYdM\n-----END CERTIFICATE REQUEST-----\n";
my $cert   = "-----BEGIN CERTIFICATE-----\nMIIDVjCCAj6gAwIBAgIBATANBgkqhkiG9w0BAQUFADBZMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGTAXBgNVBAMMEEFMUEhBIFNpZ25pbmcgQ0EwHhcNMTcwNDI1MTE0NDA4WhcNNjcw\nNDI1MTE0NDA4WjBCMRMwEQYKCZImiZPyLGQBGRYDb3JnMRgwFgYKCZImiZPyLGQB\nGRYIT3BlblhQS0kxETAPBgNVBAMMCEpvaG4gRMO2MIIBIjANBgkqhkiG9w0BAQEF\nAAOCAQ8AMIIBCgKCAQEA7q6WrYmPkMM5xKmp6xMyzGXN02LGlhMdUzGyVGX4uhu7\nXzJA1HJNKnommiICVbRAcvBQ7mj0QnuVPRYGS5Wx8vwjWjlFhXOXn+y0sS8LUFUt\nCrDbVM26PuORYMqLPV6SSR5WplV8El1OihVh+EvYUUzpy0sWDnP15amR2Z9optAi\nqbAR+7pd1ajOrN2x5ff9DoIfZDqDi1mySUZl//7dcB0Z/fY61YMEVT7gqmJTkMvD\nAJZuzcIUtUYFlH1lA1Ilgaap4/4eqhSCL+X4mrIrePdf/cBrzPwT6GanGMGHXRtn\nJHXyhM6/JEP1z4I8dQ8y+d3byL5qxXyprbzaMA8xkQIDAQABo0AwPjAsBgNVHSUB\nAf8EIjAgBggrBgEFBQcDAgYIKwYBBQUHAwQGCisGAQQBgjcUAgIwDgYDVR0PAQH/\nBAQDAgXgMA0GCSqGSIb3DQEBBQUAA4IBAQAhjRY1hG6A22WuujQLsZ9MnYL4R6X1\nCXpcxbh9dslPtjmaLDPTMAJVP4ZlRK6gf+ULP+IXSFd0qg01tQ4MOTJOO6Uiu+4x\nUK4xlzdTuRWE6MXeCobxpnAMbmbMU1/4k8WRSH3qiZjGlHUoic4C16WmX7tHXsL2\ni8nrmLC9haaFyPzecw28YSL3Y98Xv2japQhywoJRcpkqR4A0OvG9puE0+fDY8lLm\ndKHsoycCtu/IFlANDseX5mke1oz9UP7SFE7FXAXWMurmGZqKzt8OEapY62ZthOP9\n8NP9BB625rCYygcL9QNiCpmN76G3zYkASuGNmELjPdYsdTRwb8tvyuIi\n-----END CERTIFICATE-----\n";
# CRL serial number: 23
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

### DSA KEY: PEM --> DER
my $dsa_der;
lives_and {
    $dsa_der = $default_token->command({
        COMMAND => "convert_pkey",
        DATA    => $dsa,
        IN      => "PEM",
        OUT     => "DER",
        PASSWD  => $passwd,
    });
    ok $dsa_der;
} "Convert DSA key (PEM --> DER)";

### DSA KEY: DER --> PEM
lives_and {
    my $pem = $default_token->command({
        COMMAND => "convert_pkey",
        DATA    => $dsa_der,
        IN      => "DER",
        OUT     => "PEM",
        PASSWD  => $passwd,
    });
    ok $pem;
} "Convert DSA key (DER --> PEM)";

## RSA KEY: PEM --> DER
lives_and {
    my $der = $default_token->command({
        COMMAND => "convert_pkey",
        DATA    => $rsa,
        IN      => "PEM",
        OUT     => "DER",
        PASSWD  => $passwd,
        NOPASSWD => 1,
    });
    ok $der;
} "Convert RSA key (PEM --> DER)";

## DSA KEY: PEM --> PKCS#8
lives_and {
    my $pkcs8 = $default_token->command({
        COMMAND => "convert_pkcs8",
        DATA    => $dsa,
        IN      => "PEM",
        OUT     => "PEM",
        PASSWD  => $passwd,
        REVERSE => 1,
    });
    like $pkcs8, qr/^-----BEGIN ENCRYPTED PRIVATE KEY-----/;
} "Convert DSA key to PKCS#8";

## RSA KEY: PEM --> PKCS#8
my $rsa_pkcs8;
lives_and {
    $rsa_pkcs8 = $default_token->command({
        COMMAND => "convert_pkcs8",
        DATA    => $rsa,
        IN      => "PEM",
        OUT     => "PEM",
        PASSWD  => $passwd,
        REVERSE => 1,
    });
    like $rsa_pkcs8, qr/^-----BEGIN ENCRYPTED PRIVATE KEY-----/;
} "Convert RSA key to PKCS#8";

## PKCS#8: PEM --> DER
lives_and {
    my $der = $default_token->command({
        COMMAND => "convert_pkey",
        DATA    => $rsa_pkcs8,
        IN      => "PEM",
        OUT     => "DER",
        PASSWD  => $passwd,
    });
    ok $der;
} "Convert PKCS#8 (PEM --> DER)";

## PKCS#10: PEM --> DER
my $csr_der;
lives_and {
    $csr_der = $default_token->command({
        COMMAND => "convert_pkcs10",
        DATA    => $csr,
        OUT     => "DER",
    });
    ok $csr_der;
} "Convert PKCS#10 CSR (PEM --> DER)";

## PKCS#10: DER --> PEM
lives_and {
    my $pem = $default_token->command({
        COMMAND => "convert_pkcs10",
        DATA    => $csr_der,
        IN      => "DER",
        OUT     => "PEM",
    });
    is $pem, $csr;
} "Convert PKCS#10 CSR (DER --> PEM, resulting in original CSR)";

## PKCS#10: DER --> TXT
lives_and {
    my $txt = $default_token->command({
        COMMAND => "convert_pkcs10",
        DATA    => $csr_der,
        IN      => "DER",
        OUT     => "TXT",
    });
    like $txt, qr/DC=OpenXPKI,DC=org/;
} "Convert PKCS#10 CSR (DER --> TXT)";

## Cert: PEM --> DER
my $cert_der;
lives_and {
    $cert_der = $default_token->command({
        COMMAND => "convert_cert",
        DATA    => $cert,
        IN      => "PEM",
        OUT     => "DER",
    });
    ok $cert_der;
} "Convert certificate (PEM --> DER)";

## Cert: DER --> PEM
lives_and {
    my $pem = $default_token->command({
        COMMAND => "convert_cert",
        DATA    => $cert_der,
        IN      => "DER",
        OUT     => "PEM",
    });
    is $pem, $cert;
} "Convert certificate (DER --> PEM)";

TODO: {
    todo_skip 'See issue #525', 1;

    lives_and {
        my $txt = $default_token->command({
            COMMAND => "convert_cert",
            DATA    => $cert,
            IN      => "PEM",
            OUT     => "TXT",
        });
        like $txt, qr/DC=OpenXPKI,DC=org/;
    } "Convert certificate (PEM --> TXT)";
}

### CRL: PEM --> DER
lives_and {
    my $der = $default_token->command({
        COMMAND => "convert_crl",
        DATA    => $crl,
        OUT     => "DER",
    });
    ok $der;
} "Convert CRL (PEM --> DER)";

## CRL: PEM --> TXT
lives_and {
    my $txt = $default_token->command({
        COMMAND => "convert_crl",
        DATA    => $crl,
        OUT     => "TXT",
    });
    like $txt, qr/ X509v3\ CRL\ Number: \s* 23 /msxi;
} "Convert CRL (PEM --> TXT)";

1;
