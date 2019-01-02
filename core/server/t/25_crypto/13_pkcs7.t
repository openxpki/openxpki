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
$oxitest->insert_testcerts;

my $passwd = "vcgT7MtIRrZJmWVTgTsO+w";
my $rsa    = "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFHzBJBgkqhkiG9w0BBQ0wPDAbBgkqhkiG9w0BBQwwDgQIFqUCZvq+XB0CAggA\nMB0GCWCGSAFlAwQBKgQQzTPzZuVsU6radhmu9BMFSQSCBNBLK2/owV7t2QdQtxqo\n4S7lGwBcogaDEu4huif+6NYDwMopuTSDfR9kb5fADTU2Fk2u6x1H5tU+JowIv8mf\nVcV0BZwtZd4AnvUw8Eggad/27it+LuwJ0CAs75wQXN102DSM13In9Xb1t6yttUv+\nrx0WqJbRPHfRdhAxZYSZP/MWqF/Xgy8ftcXMH38Aq6zBQNMjsgShPj0n5nX1/QP8\nlle3Xe9EaUr1W8xpbAsS2YR3qWcgBgiezddlvN/xacOpXMym9EtAvfqRmTW71zk9\nZPy95l1TFP6KL1HfcWLSZ0Ga3kQprZM4zP2DVwtpycDa5cUIZqT++/DEAuW3dR1h\nS2QrNRdt26hiXph2dLqluzbZzKS3VifaaElDRvcqKTGA5sGUKvpKVzgTboWBLMLa\n6l6MnnT8OunlSWx3BCfqEDDsnWy08EkemHrG9JSLkOMTD6b/nZOdFlfUi786L6yl\nGuoUOGexuhf2Z7UYOpxe+HT1Fs7odg6NOqqx1tq3Yj5B2ZVcUEZg3/ARwTrKkJwk\nhmFAOGeFxRtzpsPo7CB1sC7IeMB2RpaE8MAFbq2YxTR2r7Xrdzzbkv81f0STikWa\nm77vYBuM4V2oNjAynFB6Rwh1oIOND5h838CXnV9243D3NgQBmnyG2QieC2PFxtkA\nmfRB13r6FDVk53H3SH2H4H3AXmUHznJaNlVja1EYBdhuGj53GkJzhoGo1FqMvyoF\nFphxrJcmZyD8xOM2K5npdm5dvZIj+55t562vRno6SPjZBWmOdqEQfad/kdD+9pKw\nnkKyndM7F8yjJZL/gnY8nO91mXBeEvJXXBFa21DX8QpBj2Axil4pyr96gai65kr/\n6k2gpizzrqCCpOIvWGplDA/vp+j5GfGD5BBhO/MJzEj2hNsBXqpGQBHip1TLauBM\npTLR9LTSJAgn+yR+9wsXdT70WM2KBPR0sDXF69pnWcs+WE/+blX9ENoJYoG95WYj\n/0JO2fUh9A0kzucXioal7awAexqKpHEN+tZ+jOTDNUMfGMlUx+eCj23cblvZzpIU\n7gITu6yNjvgs96tEyB3KUr2sr8AN73eGUcX+iTfiHMc6OrCxPrUrT/4IbqtPb/X+\naofmkeZy6sy93W0+MD7ccqXuVmeu4/F/Ekh4Cy1H4Ord5NI9rZXMIon3F5MYpRiq\nsV30QOYiNrNQB5oQBLw2p7cAWWDUMmSw2rsNNllMPTYa75thi/ay3TerkmvS2VUC\n8dJu6J7MjSgOA305Q588hykOGOaKpfq5Jbia9sY9y0nQct8ICCj4yAt3M5u/h0iT\nNkzL1wUOjt4lttm5JZ1FkI2BPxEzthc0z98f2NwsHUgjm9I5LInWoyEDQA36wKR5\nrtBaZXhHefQlbJvGoV6E+Y8Z69dc0ajOnVi1hCx5labqcnliWLrh6FRXbWbW00v7\nSiHAAqmeHt3iMHDqER89kkQls23Vim75Da+yvRHb/OxQ54UcSdNBCWWqqEF5iLE3\nNo1azB1Xj/I/TN7FhcBqORxzMVMiIk49QkyTyUUozHZfEyDY1qnICLZItTSZjiX7\nrAqWkZSgC3dxrSbFPlO4FWWl2+5rg6gaRM9sWSklgEXC9DqoHPhF5WX333Ua26Lt\nGCIdf7YrwXtQLlS62mcUkoWMPQ==\n-----END ENCRYPTED PRIVATE KEY-----";
my $cert   = "-----BEGIN CERTIFICATE-----\nMIIDGTCCAgGgAwIBAgIBAjANBgkqhkiG9w0BAQsFADAjMSEwHwYDVQQDDBhFeHRl\ncm5hbCBUZXN0IElzc3VpbmcgQ0EwHhcNMTkwMTAyMTEzODE5WhcNMjQwNjI0MTEz\nODE5WjATMREwDwYDVQQDDAhKb2huIERvZTCCASIwDQYJKoZIhvcNAQEBBQADggEP\nADCCAQoCggEBAOyiCtZPGhyw1lnI0sOFc6b3C8ZzA2UMCL5RXFnl5ZCf8g2mZQ63\n7nOcpFnZyKVEyTwz6CAwmGGh3T/M/sSsyWzCQ/fPDTmrL8Djk7VB29esIRwyETLc\nb4DZN7KbRt7F0uXNznpp0I8rQrbVa1xRPG8kQqzKytW4bOObvT8KwwjE5qQTr9G9\nWR1Tg93pFQ+THIS7ci1Fyer1ue+aFS2xna3iWuEH3RgPSWiuCsH8RB2ykzg1EPqf\n5Y4scWpw/CMKSAHQ+HFozsz8x2O/bsBcpECS5cfkt/q2kNasTnSEj9XAlU0mByLW\nXBIafjc3UHy+kuFWtKXRmPbls7qhmrPO9h0CAwEAAaNoMGYwHQYDVR0OBBYEFM0C\nH56/Pbue6FNKIMWbbTWsCWBAMA4GA1UdDwEB/wQEAwIFoDAnBgNVHSUEIDAeBggr\nBgEFBQcDAQYIKwYBBQUHAwIGCCsGAQUFBwMEMAwGA1UdEwEB/wQCMAAwDQYJKoZI\nhvcNAQELBQADggEBALPIoGu3sOwZ27AofL9obbUYn/scs92Q3qbxzbHhuG4aZhIH\n+QmFQmdt9J6PRyvs1ID2cDcwn2KyYRu4RuHEOQNo7ePfsj5ls9Qxq3b5OC0film3\nxDO6Z2iGBzJIjv+mVqKHviKuExfd9C0GAk2fHP79mbstxW2GABHZEzuSETKB/m4o\nztqqYSYM0MknmLqIAD+ckYKT8covPU9U6qyJMfavdbQ8DaggkB7EpQDPEoTtGq2B\nGfyHo+zajqwzkWnEaIteOli3CM4B52guaJJeGPS4hpSw816yBUOY6hZpbMWh2qVw\nzsny5q2T1hUFRU+Oa7bLaSE9uyqxBV55YISeMxI=\n-----END CERTIFICATE-----";
my $cacert = "-----BEGIN CERTIFICATE-----\nMIIDHjCCAgagAwIBAgIBATANBgkqhkiG9w0BAQsFADAgMR4wHAYDVQQDDBVFeHRl\ncm5hbCBUZXN0IFJvb3QgQ0EwHhcNMTgxMDAyMTQ0NzE2WhcNMTkwNjA5MTQ0NzE2\nWjAjMSEwHwYDVQQDDBhFeHRlcm5hbCBUZXN0IElzc3VpbmcgQ0EwggEiMA0GCSqG\nSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDbEHHfrID+vWEkR1gTvMLGUejzQsmRVs48\n38EIbddTGY8y5CMCPS2kI2kjZBxu1/E8L0PFWoWJkesLB80HYfT1sBt7jT0fvj/f\nolhQQ7cGmeJkEp83OLKmJTPuDPfZMnoMN4leDjisn1zwG7hl+IKFQgRKOo7qr0qA\nDsUBXMaKAvPPSiTVvyxxi4WIZS0+mP/NMx6mU/AD4yiYu6DrUtr0YzjNJPlUhNGi\nvLlNm/1KVvOa6672SZXtxxKssHE+HwbhRWxRuWPb+91hSIPtWgmfGSeINGLpI9AQ\ntVFZuMN6yTqnI/JNdROEFcczUKFtr+pb0o4dIHk5lIe03Vj8sGQhAgMBAAGjYDBe\nMB0GA1UdDgQWBBRxs3vIfZc6RTtMhV79b9bla5UTkzALBgNVHQ8EBAMCAYYwDwYD\nVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRnWPYNGOXV41hSIlQqgpQ1kw3NWzAN\nBgkqhkiG9w0BAQsFAAOCAQEAypbadXEazuOQNbAyYldrNrPjlQvdq/XRsTjjlbjW\nmf+HPdtODRbk7RrtsvUv7QHL9fmMlRktOCxB8Qx0vVk3Y2e5+huxn/AedNVbEQtr\nwbbLK/txNw28bZhXkD8eGH3SsBUIch1TsUhBrJYjbdsWidTgYkLP+qO9NccYcEsL\nWhfr0ouATrl+qEJy0HrxB9MXXCK+PAI1LCiTuYYg62ZWe98ev9ITC/clLl8kdvOS\nFJtQsB0UBfHqm0hIKS2V0PIrQRC2RXySGJnzbHsVlNWQxyAC/xSqZ7dCxHvkQBLq\nnQWm2bBNk6QSophe3PS2L8A8LcGphdiyOkcNv5ugOEY4WA==\n-----END CERTIFICATE-----";
my $rootcert = "-----BEGIN CERTIFICATE-----\nMIIDFjCCAf6gAwIBAgIJAN58mveKwFdHMA0GCSqGSIb3DQEBCwUAMCAxHjAcBgNV\nBAMMFUV4dGVybmFsIFRlc3QgUm9vdCBDQTAeFw0xODEwMDIxNDQ0NDFaFw0yMDAy\nMTQxNDQ0NDFaMCAxHjAcBgNVBAMMFUV4dGVybmFsIFRlc3QgUm9vdCBDQTCCASIw\nDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANSpPYWi1et9quVEHRNpFhQja3t2\nHpKlz2Y+hGYs+CSHJfs9D+DzuO1TROy62pvBZ1L0A1rkERjcklJDkqvbnYhZtlPb\nukM58prLyW0zvLyhM2RjY+0nq3P7WhnVvAqaAYa3t3bNMsB8jfgc654ailtrswH6\njkbQt7G9qns8KzMnCNZMyQykn1dP4HrjI6WhoBbzzXw2fymhk5mmUd+t6jQt+BMy\nMQrb5zuanW9SkLbnMvoMyA1jWbUfWQObXPR9lbb6yMzCQeWZyteTKI7BkZ5fwtlA\nbNwBfPWC184U2H5vWIYRfU5qxy+iHbrJx3CGY17XdH12c+Addm6QBlOz/YcCAwEA\nAaNTMFEwHQYDVR0OBBYEFGdY9g0Y5dXjWFIiVCqClDWTDc1bMB8GA1UdIwQYMBaA\nFGdY9g0Y5dXjWFIiVCqClDWTDc1bMA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZIhvcN\nAQELBQADggEBAANwLH5blcVCOqx8N3DgqGgk8i5FnudS1niAbHqI0gyuaVphk67Q\nojFlZDIxSe8Mkmoi+6lGKKdHejmoAYVsoPSajPmcacVPjo+ofh9PS5N3AtWYV1rJ\nSHmi6I6f6LsofpKSiIcn1xblrCFgvUsSydFqFRxRUbEjPweq57W0Xve9YxTpy2yz\nlRJoDPET8hAAqRCgiv+eRlqJvAqpoIKAx3gJzCNMmuD1EaNSBP2KiZRfzJs0BoQY\ntdL6Spz3FdhHzeQ02G8qwcI2G2qYgGfj7IpZTvymt8+Lae9sH0GRxC6PnLJAZvYx\nzA4016vfqDlpKd2rqoY/QAKtoxmhlbdM3n4=\n-----END CERTIFICATE-----";
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

#
# Cleanup
#
$oxitest->delete_testcerts;

1;
