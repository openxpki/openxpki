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
my $oxitest = OpenXPKI::Test->new(
    with => "CryptoLayer",
);

my $passwd = "root";
my $rsa    = "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFDjBABgkqhkiG9w0BBQ0wMzAbBgkqhkiG9w0BBQwwDgQI92Z4mO7qmCsCAggA\nMBQGCCqGSIb3DQMHBAi2Hforzj6ykwSCBMjLkgjSC4E1XewpNnD5CpnJHRQ3g6OI\nr6moMJOn/7f1sbjhW3kMdDvjvexkxo2tc9ujmEIcQOLK1gH+ljVtNbs4mGj1CQnE\nve242QVKDFQ6B5MZ9hF7sPe/sl8Z4/9yJEA1TlKYe7fSdO4evDC9ztFm43mIE+NR\nn48xuHdrolUb3MVATqG/kD5aGfopLF0WjXFViGYTI+xJsrxn5FWsVpnS2tc3Sh39\nUzyP05wP8Hj6BaEbXvyhBExj45z4gYhmaIWUhyKw83y3t+XdqMK4UEoUaoddpveE\naISbOugxlH59/ghNKj9jUM25SaGKKx5rfoTMUTofULHOOR1rK5i6YyAb23oeKMDi\nb0XZTmKbKzblfarX/IRUqCgDkzCkbANC/otG7fy3XzVASlDpY7oAUK9Q8wm+d//7\nSq3q+PYUETCILrWgWsitw/vfmTezFUY3RtVTIzbWPKnKS2bnC4N1hsvOzfHvkOAO\n4HkXAsUlUnNjcwg8hoHnJdgIr/LY8FkdTmnFtsECLa48v7Gab/Vt1CUIB1sbDErU\n1qS0w2bTZyz5gmk3TC/0uXdyuRqqXaTMkMI3yiqXZxYcJeNuSUhs9MChb5O78YxP\n+8ILoU2jd1VPaz6ZjxNRtoqzLc2+G9PLylpROwmGycpx2tYQDT5UOQdRnSD1gzQs\nEh++xXEO487c2h37NyTozfqfCydU95bm0WN5ReHtE5uq6Djr/p0rxfrHqwlzPQLz\nX6Cj+1xg22l54TkV7zhgU+y57mS3g9a7pLouGqgILVNLjz+fZR0sJRnmDHPMxIL1\n6av2FUkOIuzHR/otqE6krr1vjlJPvSYD7L6K954d+TCzoF79HvKMQCUAt1uNexk1\nhMgRCL5G0a3/wQyjZ0+YCAZPtpHMWvm/Gt2tyKvMdWWVwjR+wh/udQRhCfdemUj+\njO1R/ReGD/pRmkoq+TjNmQbrw74yuvA25ZxDrLa0mjTd0i7cugN5lO7CX6O+/GsI\nFQ/nExxiq2TOAFNn0aOlv7SFimH2WHDi6RFnINItq9TjS+/YN4tDf7Kac5pJe6Ip\nZAMu+INWdJfcOD6KdbUVlE3uY3Fr07JPUwjHYVq2GQvFr6MmCR8Bp8W5D+ophwTN\nIgGDAuDu8cjNZHiUey+H5cHMaKJx8u9PsZN5vzJZoVYFdLcnpfmx+bJudsiEpMq0\nfPzXwAsUxC1rVYzJWLKzab25j2YAbJFDYKEnFIdCwxsQnQjgolDeOUtT429l0/2i\nxZIMbc8DCnUjdljhrFgOHql6jz1ixjuyulwUXb47Aq4ozwX9PGBulmz/WklxuV+r\nmxcHkO32HMGOUgZv1+awVgKeLtLGkBgPTvZCFsghhCe0YRmuMEAG8phJOZn++R8/\n+2InSH0ti6z9saR0eEETyzghb4u7SfqHJFRWFpQMPEXF2ftvyGGpY/9LUfdeS1S6\n5Ir9JCnMQXZHFZnlQ4bBcEmQAvyfQGkkKnCFAMrDqyDAv1TfsdP0aH0jTaBr8r9J\nS+ge6r9SOSiNb9M6wZxPIny8ez1Zw10UzLfbBNn16bue7mZ2Zqy8rSNhxaCYPwmF\nt/wiQRK4sJfCi/yiu6cEKtyoaTSnpbskbiOsZCMx6AVEjRQdVMOQCfoTxTzOCUFX\nF/w=\n-----END ENCRYPTED PRIVATE KEY-----";
my $cert   = "-----BEGIN CERTIFICATE-----\nMIIDhDCCAmygAwIBAgIBCzANBgkqhkiG9w0BAQsFADBbMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGzAZBgNVBAMMEkFMUEhBIFNpZ25pbmcgQ0EgMjAiGA8yMDA3MDEwMTAwMDAwMFoY\nDzIxMDAwMTMxMjM1OTU5WjBdMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZIm\niZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxHTAbBgNVBAMMFEFMUEhB\nIENsaWVudCBBbGljZSAyMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA\nsVsAN84HFUBnXbrIn7im07Ry/qgCyfVbzKbTBOwr1XDP63xkEkgBVuuOVtDgBNrd\nkxf9wbYq3CAaYdOO9YwjxfysTOr8YpOQj4xJSTrsoG0d+YGTzcnR/+4tJHqva8hh\nXNIP3ysb68rpADXCJH+dlhbn7NTaG8wN+2uWJnUifeUjO6tCK8ZgqPsRlB2PfTxg\nWGjcdotNO3vQK2esXbuCKGIL3py67AYWFGy7FkTjCQ33d75WvL6aGrq9Lg3MCEIT\n1F9Ihotyen6Ox8D4sWjxynRAZoou5+MjWItefMDENwfqVUKvVAix27vmZfOwcnLf\nwcvmMpADREilFhdigMBgYwIDAQABo00wSzAJBgNVHRMEAjAAMB0GA1UdDgQWBBRO\nMVcVPei89IY9+yCEt0kDJa+qVTAfBgNVHSMEGDAWgBQllePFkXgXBsY2tGKOEGnj\nVj1sLDANBgkqhkiG9w0BAQsFAAOCAQEAfb/hC3hzH4dAV74BIl3CLh9PuPGjlL3m\ngpkTrn9SogrDMtTaq6ewoFaqioBFVeLwwnflVpYnzG41tjlCXq3JGx8Oiw0pz6Om\nBv3Z6FzeA7/yY05l6XO82xRtl7BF6k0Akh6lkz0+Of2P/cUwmBid2PkWuwx9bIpb\n8pj32E9h2OmrAao+MWwfskHlER3JR144llHxbM0oDPUR9cAn9thq5am9XGqxMHdJ\n8xMcSX3dq6XYADel8zMpYWDoWbwq3pptVqnvy69BUoV7zcp8iYNoEHwrLG4mPUHh\nNntk2IV3UJZdjCm5ZhVnFs5ZLoI/d4+uzb3mEH0ziOsCvNJxTAihsA==\n-----END CERTIFICATE-----";
my $cacert = "-----BEGIN CERTIFICATE-----\nMIIDkjCCAnqgAwIBAgIBCTANBgkqhkiG9w0BAQsFADBYMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGDAWBgNVBAMMD0FMUEhBIFJvb3QgQ0EgMjAiGA8yMDA3MDEwMTAwMDAwMFoYDzIx\nMDAwMTMxMjM1OTU5WjBbMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZImiZPy\nLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxGzAZBgNVBAMMEkFMUEhBIFNp\nZ25pbmcgQ0EgMjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMiovn8+\ndjhIOADUUtE7mgSXlYJoPjjRinGzCRtHy8YdM+uzgKXiyYODEpK8YpRROsuBpEPO\n6nkdilI6ONdz2IkwHHJSx9d8SPvW/pKSshBQ27wl5bHqihY32AdqdkUH8YFCCheD\nSBV9IfGRd4RVNITNEmXPIDN2LDHmNwRURbzEjM7rZwkIwJy3ksiW6PCXRmwCt7F+\nHAj8afn4niTyni3BU4SQGuszzoO6jzvrmTxIhZ6PGJ0uzxHyS3u61lkAEF2a+pnV\nVuUnVQ9QsWleVbaWIsxbcF9BRNMc1OaBnJKGlGzcqWRhJx6fzuyzcclJBgcsniTK\n5jl43BLhRAC4pikCAwEAAaNgMF4wDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU\nJZXjxZF4FwbGNrRijhBp41Y9bCwwHwYDVR0jBBgwFoAUjNW5hSaTjfK6RnG/bYUr\nvV8tQZUwCwYDVR0PBAQDAgEGMA0GCSqGSIb3DQEBCwUAA4IBAQCFX+bll/CC4hJe\nRMkmFWsq3UcvNkp84NROYsZejdub/tkn4C8YLi/elgIU360Wam8WpnY+qvNBMk86\nZoj6K3R8nmaHUdRFoRp8wqwKbCDgyb1QwXwsm7bDwg5DstOoL0Ol8OBasG5YSX+B\nLSF/3EpSHUUW5s9JXiAOMo382CmsZY+/J8yF/L+TqSs4CObXjzbrrTftj4El0Ih/\nlnJyKhkvhfI5YSInPwByg0m9mpOhd2gdk15WFM5D+RIGjb7QAuSY+mvZJ38rzU2y\nNDjL+w3olKW/wD1FI6yn0/QmJGHhCAblXQmF7yJsIeFQEWGm43tOqx9SVuzhxfdP\nGihYtVw3\n-----END CERTIFICATE-----";
my $rootcert = "-----BEGIN CERTIFICATE-----\nMIIDjzCCAnegAwIBAgIBCDANBgkqhkiG9w0BAQsFADBYMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGDAWBgNVBAMMD0FMUEhBIFJvb3QgQ0EgMjAiGA8yMDA3MDEwMTAwMDAwMFoYDzIx\nMDAwMTMxMjM1OTU5WjBYMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZImiZPy\nLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxGDAWBgNVBAMMD0FMUEhBIFJv\nb3QgQ0EgMjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANziBj72oup2\nX3QNFhZEQW5aZqv/4Q0jp8bA6mdNYC0ZFVHyE3OP0E3myc7IJfGW1mJH2ojtJ1ms\ngB0Z3DlAgec76kwo0Q36MLNmuB/DAN5+4P3wYhW3eCRgfLWcdzkYTRYxAL8O7XuK\nBVOPVt34CRnYct9pPojpLL/goi70bxQ153+ZgO3zJPdmT7vPMNU7pTBFRYUIpHRF\njwo6qerCV2AvveXp4kjJe2AHvbL0JCN+pdm0lFG7WY0sQN2PLei+qplRWkM8eOjH\nrPMv/C0/Saqly37QapyIqq/7jvxz6jv0F0uBbc5tQmT4Oidl/KNnBZAdNpKx4xoB\n3swjYPMYPysCAwEAAaNgMF4wDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUjNW5\nhSaTjfK6RnG/bYUrvV8tQZUwHwYDVR0jBBgwFoAUjNW5hSaTjfK6RnG/bYUrvV8t\nQZUwCwYDVR0PBAQDAgEGMA0GCSqGSIb3DQEBCwUAA4IBAQCoqYzWPbowgJxmR1Mb\nIMhyyg7VdF44P8e8Sv2h+i2LaWBY6HwUVkDByqCEDysWfvH4RNzjNNiWQ10yoiFp\n59NQcNjXC5GMZZYdLjB/+OkVUAT8KwV+GMeB9LTSju4yMxmvtjj+auVZmadADh1b\n7/atPtRSAH/O9CJTXupoceh/AXeYV9Vx2J7Y4cujHIH3H326QidnR9zeUyha8wqF\n1/nwFOwt5CFZ89PjyAl/D2g0IowNNHRGdm7oLvQAR8HDwFvlS+Qpc2PLYiqGG8eo\nK7jxPAQWCvdQU5b3xFYUehK35E58DTGA0wnKrAxeB47ZrZF11jc9xrMCGg2BLm8R\n+UwW\n-----END CERTIFICATE-----";
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
lives_and {
    my $result = $default_token->command({
        COMMAND => "pkcs7_verify",
        CONTENT => $content,
        PKCS7   => $sig,
        CHAIN   => [ $cacert, $rootcert ],
    });
    ok $result;
} "Decrypt content";

lives_and {
    my $result = $default_token->command({
        COMMAND => "pkcs7_get_chain",
        PKCS7   => $sig,
    });
    cmp_deeply $result, [ $cert ];
} "Extract certificate (chain) from signature";

1;
