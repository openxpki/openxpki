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

plan tests => 7;

#
# Setup env
#
my $oxitest = OpenXPKI::Test->new->setup_env->init_server();
$oxitest->insert_testcerts;

my $passwd = "vcgT7MtIRrZJmWVTgTsO+w";
my $rsa    = "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFHzBJBgkqhkiG9w0BBQ0wPDAbBgkqhkiG9w0BBQwwDgQISNoARhy+9wACAggA\nMB0GCWCGSAFlAwQBKgQQirJStjGiObx5dsFHCJg4sgSCBNAFyOpg4yIXOEpDyr+t\ntz7WARhPVJLziYKPT83W+dQwwjUyBFlPWdbzGsA6CeMf5WoRPhRFBm6MBbxhsRk2\nmas8BgKDddIxMU/M4RaDD62nIpfUHkGsdh97kxzUZElDeORQS9m9y/b6b4BMx+vH\n9Zu6e6unlhZjBSnDiOYfbI4DBySZH+imjQPNXYkn2WwSH2Dh2VyuzdvxWvUlaNeU\nwOWi3iknatyKyE33fnSpA9AmsSwnfPWyQ77kKffkYbFZq337iyckz7GIWaNPVH/r\niJ6rS+60KB2no5mAROQ8ixMKT56rKK8cl4kowMpV7S0+sO4j3RqVePwCUX/qScS5\nP6+YMl326ZWyChzuiuSLbjz95GR0DKXIlMK5JGgq4KNl4LIysU5gn8OBNqXW5Dkr\nQmU5zQllhO3iSwuv+lNBBh7lDj5iWVPIn6O911d8wOJVsME16UKGqVicuz+cDhZB\nQCBtJkZ8m1CgDviDGZoqgoSyQA1BLo4gKNfZqfyFoupJjDtqPvngjCQZtuYwlZ+d\nu/FpsTPhYa9qx23HGKaDPZ95lOkEYfGQ9ClbkzI1cCMLzgUNSgFcSGczpt+EgrqF\nA+lJFToyetO9BpeTIgQyUJiaFm7/9hZEHJNPUH6MXrQDVYjgHgtEn8406Luh2vrd\nk8cUqd6YZADZSUxNElCbmhzyp6YNMYzO6xp/kCXq/MOhvWvtOzTnVq7YgCUgtDry\ngj7WegLI+BUtBxvVSXq6w8lyW4lisVz/KVxgmjHdNMtj5L8g6UJzVnAy/ecpVi91\njVcz8gHxWxvedVjoJBOx21BismVFLadOrU3pMmj33SdjePC7ON9DCZ8KVSHoENym\nYEWoMxCNKM0s74WoK6FCwJBAS5V3qnsvPRXw8bsB2B3Nt2BcM31o2ohPba5n9T/p\nwUkEBq6K7hsceUfMgkZbcGiJbxiipT/lbLpDW3IpaH0//BVJDRXFvwd43nwby0E0\nB0l9md98Hq4fUEZBpIXuaoxSw6cJRh5GI+h4pmbx/PQaSWV63bjZTd9WcGggdy80\nYe873PfOeQ3oFMJyg/Zn2OAFBNVGMmaP7l1fkOYTCOu69yK8+Q6q3KDkRKZU/Pec\nEKvciwXA3Z2p45Q8HHzNUZGpbr27ZCp6gyHLyXLcOePPyS4AExw6Vyu1UWcdaozj\nPg+luu+dlgu+S+2sIfhXgihDWH/iOTcxP/kHdC74Ee+OqflrJ7FZlrvNshEjNvvM\nLxmtDBj98YG5r45k56mOKSDjyLfU+MgjD2Lj1TMFYOY2AuZY6GY+OiXJPDyVc8Bv\nnDPV9+IO3Auq9gNjYEAlUUfw4eJHve3fnSZs3ifAyhELNfds5fhJOTUxhbHB7tip\nZiYIh61WY5wSnTmd2ZZKPZHQa/UL+WgxHF6Jsr8BAXgzC7PAallBNP44/pP9ED/B\nBP3Fce97R6k9pR1Cxegq8NFEm9zM/cwDKhhQrFlZ5rcMOy6qDk8bU2ZkamBtVXFo\nRnGd4qjtS+aCWfz+fjmYz1Pdz+ju6H0jfAjoyHc1WWYbeDM1S7C1XN9D3K2md56A\nm5SydJXOqO+eRjfOBB9m/nneB7sd8LPwaXUB3VOdiKX0LEW8GIprPDmp3C4tEpef\ni9d8OJm/t2KAaBchNlJOauEvBw==\n-----END ENCRYPTED PRIVATE KEY-----\n";
my $cert_subject = "cn=John Dö,dc=OpenXPKI,dc=org";
my $cert   = "-----BEGIN CERTIFICATE-----\nMIIDVjCCAj6gAwIBAgIBATANBgkqhkiG9w0BAQUFADBZMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGTAXBgNVBAMMEEFMUEhBIFNpZ25pbmcgQ0EwHhcNMTcwNDI1MTE0NDA4WhcNNjcw\nNDI1MTE0NDA4WjBCMRMwEQYKCZImiZPyLGQBGRYDb3JnMRgwFgYKCZImiZPyLGQB\nGRYIT3BlblhQS0kxETAPBgNVBAMMCEpvaG4gRMO2MIIBIjANBgkqhkiG9w0BAQEF\nAAOCAQ8AMIIBCgKCAQEA7q6WrYmPkMM5xKmp6xMyzGXN02LGlhMdUzGyVGX4uhu7\nXzJA1HJNKnommiICVbRAcvBQ7mj0QnuVPRYGS5Wx8vwjWjlFhXOXn+y0sS8LUFUt\nCrDbVM26PuORYMqLPV6SSR5WplV8El1OihVh+EvYUUzpy0sWDnP15amR2Z9optAi\nqbAR+7pd1ajOrN2x5ff9DoIfZDqDi1mySUZl//7dcB0Z/fY61YMEVT7gqmJTkMvD\nAJZuzcIUtUYFlH1lA1Ilgaap4/4eqhSCL+X4mrIrePdf/cBrzPwT6GanGMGHXRtn\nJHXyhM6/JEP1z4I8dQ8y+d3byL5qxXyprbzaMA8xkQIDAQABo0AwPjAsBgNVHSUB\nAf8EIjAgBggrBgEFBQcDAgYIKwYBBQUHAwQGCisGAQQBgjcUAgIwDgYDVR0PAQH/\nBAQDAgXgMA0GCSqGSIb3DQEBBQUAA4IBAQAhjRY1hG6A22WuujQLsZ9MnYL4R6X1\nCXpcxbh9dslPtjmaLDPTMAJVP4ZlRK6gf+ULP+IXSFd0qg01tQ4MOTJOO6Uiu+4x\nUK4xlzdTuRWE6MXeCobxpnAMbmbMU1/4k8WRSH3qiZjGlHUoic4C16WmX7tHXsL2\ni8nrmLC9haaFyPzecw28YSL3Y98Xv2japQhywoJRcpkqR4A0OvG9puE0+fDY8lLm\ndKHsoycCtu/IFlANDseX5mke1oz9UP7SFE7FXAXWMurmGZqKzt8OEapY62ZthOP9\n8NP9BB625rCYygcL9QNiCpmN76G3zYkASuGNmELjPdYsdTRwb8tvyuIi\n-----END CERTIFICATE-----\n";
my $cacert = "-----BEGIN CERTIFICATE-----\nMIIDjjCCAnagAwIBAgIBCTANBgkqhkiG9w0BAQsFADBWMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nFjAUBgNVBAMMDUFMUEhBIFJvb3QgQ0EwIhgPMjAwNzAxMDEwMDAwMDBaGA8yMTAw\nMDEzMTIzNTk1OVowWTETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmSJomT8ixk\nARkWCE9wZW5YUEtJMQ0wCwYDVQQLDARBQ01FMRkwFwYDVQQDDBBBTFBIQSBTaWdu\naW5nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuEbqBcD169VA\n9GGLpfo57A6gfo3HSIZSGMCbG9zCN1kG3pUm2DmiRdY5ImbB+PD9gHY6L3/d7/H9\nDtjIc9V3HkYzd8OyiTor7gUidadLa942L5RRCXVzcEIGwXbglCaqAxiJdPJR1Rp1\nB4WNksnF+T1ay5PuZmAlExhhEixQXppJdHEYO/W8H0cwQzp9IV/gX4n4MNX/H7fz\n2HAHVes5luFLBJoV3sCMdAQaDevFcQOzQfxPNUtuO/hrlWZwInOGzkOqGpWhEk8B\nBxc/UGl83uWv3v5WXLexFr2eBU2mJEYJJbK5CCgemOWnWxdcpDIN68L7Tl7C38jy\niaPdOTSyZwIDAQABo2AwXjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBRMkWbI\n6lemI9vyRpD9bOttDl6NojAfBgNVHSMEGDAWgBScyqlYeK0jySM6/yI/213S3JRA\n1DALBgNVHQ8EBAMCAQYwDQYJKoZIhvcNAQELBQADggEBACqgCbSGraAkPxcATdzM\nitXoLY1s/lhXLb1kvkJt9bGXFsl4LWfQoUdCtUMuIW4yXKZMvZax08pFwxHatG6d\nPx5glTWDtU7YeRvcl6OSzCByd75zQqZdbzzJ4NCnmxWLG9OVXoEDkPS0pvbRKr/f\naE+ebcG36kvEO95TqrD6K8QWkPSHWn/THZ7seizbKXcWdN/JcZapaReU42rf6zJ9\nIX5Mv/Gs1Ub+fpsJWL40AVxxJsxY1n8MIr5endNV/fkoP6fTjzgsoSEQc+YVqHqM\n9CkH3SPv+WNqjA0Fz74l6L3AiE+6DXlBpuo+QF08hxrFUJmD0t9b/r9/9SdJh0z8\nX74=\n-----END CERTIFICATE-----\n";
my $rootcert = "-----BEGIN CERTIFICATE-----\nMIIDizCCAnOgAwIBAgIBCDANBgkqhkiG9w0BAQsFADBWMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nFjAUBgNVBAMMDUFMUEhBIFJvb3QgQ0EwIhgPMjAwNzAxMDEwMDAwMDBaGA8yMTAw\nMDEzMTIzNTk1OVowVjETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmSJomT8ixk\nARkWCE9wZW5YUEtJMQ0wCwYDVQQLDARBQ01FMRYwFAYDVQQDDA1BTFBIQSBSb290\nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAth3/K35L2cWIb40V\n1h+vkkutI6aOeNzQGgCFc20f73CjvdlaR97td0T+lCrAD7jzyRYKMwFtpntfEVzS\nGqbA39xDhhrK3o7pFsAYmzphMAPz1vjhrm6OdAzPIjB+gay6eNwbYndXD7fnS0/O\n63yek339ACsiTRUMfdww+LnyAwOPNZTiZcYIzcauzhVCKTCMNN3coNjfgDGfV45e\nJadDgT5U/jbqsOe6Rr2uhg11jk8NqfvqFEmGQS3F4Q0rERTEzbRfqTr6w35vnkiD\ng4p2zghtuuKTsXLv0Sb2dWAGEIKoY6JTMTPIX9QZTZanQWoj2QY2/NynbwA3VEkQ\nz6MwMwIDAQABo2AwXjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBScyqlYeK0j\nySM6/yI/213S3JRA1DAfBgNVHSMEGDAWgBScyqlYeK0jySM6/yI/213S3JRA1DAL\nBgNVHQ8EBAMCAQYwDQYJKoZIhvcNAQELBQADggEBALKITKPrh5x+T2EBqPHHN6UZ\nV3DWxJXrBa8oLIYZ47pxf7HkCJABr0mFyYt06NnhIDl4IYCPYr26NPqJf3rvJAcn\nwwVOuZTgKC3alOoXmoek0/wCasvUzmhXow7BJQkD/aCHvLjrDBBRVNIX1yTIPwbG\nGgwQBdKTNeK/d28uDRFGUF5xLDHFHmvZFJFuberj4ZVJHnxLWM0ym1u8cOHSL2jO\nhkHOsbqfxRCzrUlKAv4/zIOM0ih78DSJYq+ZMIVtpYhRbExZ1vWXpv/jI3YLz0s/\nAz7uz/KCQJ3HIC/FQvkxeDUV6WCe2hUinmBLskWINrmXfLpxwqn6kFi4Al6vkqk=\n-----END CERTIFICATE-----\n";
my $content = "This is for example a passprase.";

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

# create signature
my $sig;
lives_and {
    $sig = $default_token->command({
        COMMAND   => "pkcs7_sign",
        CONTENT   => $content,
        CERT      => $cert,
        KEY       => $rsa,
        PASSWD    => $passwd,
    });
    like $sig, qr/^-----BEGIN PKCS7-----/;
} "Create PKCS#7 signature";

## encrypt content
my $enc;
lives_and {
    $enc = $default_token->command({
        COMMAND   => "pkcs7_encrypt",
        CONTENT   => $content,
        CERT      => $cert,
    });
    like $enc, qr/^-----BEGIN PKCS7-----/;
} "Encrypt content";

## decrypt content
lives_and {
    my $plain = $default_token->command({
        COMMAND => "pkcs7_decrypt",
        PKCS7   => $enc,
        CERT    => $cert,
        KEY     => $rsa,
        PASSWD  => $passwd,
    });
    is $plain, $content;
} "Decrypt content";

## verify signature
TODO: {
    todo_skip 'See issue #526', 1;

    lives_and {
        my $result = $default_token->command({
            COMMAND => "pkcs7_verify",
            CONTENT => $content,
            PKCS7   => $sig,
            CHAIN   => [ $cacert, $rootcert ],
        });
        ok $result;
    } "Decrypt content";
};

lives_and {
    my $result = $default_token->command({
        COMMAND => "pkcs7_get_chain",
        PKCS7   => $sig,
    });
    cmp_deeply $result, [ $cert ];
} "Extract certificate (chain) from signature";

1;
