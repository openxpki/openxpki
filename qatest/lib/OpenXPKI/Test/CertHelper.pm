package OpenXPKI::Test::CertHelper;
use Moose;
use utf8;

=head1 NAME

OpenXPKI::Test::CertHelper - Helper class for tests to quickly create
certificates etc.

=head1 SYNOPSIS

This class provides mainly three functions:

=head2 1. PEM test data

Access PEM encoded test certificates:

    my $ch = CertHelper->new;
    my $cert = $ch-E<gt>certs-E<gt>{acme2_client}; # instance of OpenXPKI::Test::CertHelper::PEM
    print $cert->id, "\n";     # certificate identifier
    print $cert->data, "\n";   # PEM encoded certificate

There is a set of predefined test certificates:

    $ch->certs->{acme_root}         # ACME self signed Root Certificate
    $ch->certs->{acme_signer}       # ACME Signing CA (signed by Root Certificate)
    $ch->certs->{acme_client}       # ACME client (signed by Signing CA)
    $ch->certs->{acme2_root}        # ACME-2 self signed Root Certificate
    $ch->certs->{acme2_signer}      # ACME-2 Signing CA (signed by Root Certificate)
    $ch->certs->{acme2_client}      # ACME-2 client (signed by Signing CA)
    $ch->certs->{expired_root}      # Expired Root Certificate
    $ch->certs->{expired_signer}    # Expired Signing CA
    $ch->certs->{orphan}            # Client Certificate withouth Signing or Root CA)

=head2 2. OpenSSL wrapper

Create certificates on disk (default: in a temporaray directory) with
L</via_openssl>.

=head2 3. OpenXPKI workflow wrapper

Create certificates in a running OpenXPKI test instance with L</via_workflow>.

=cut

# Core modules

# CPAN modules

# Project modules
use OpenXPKI::Test::CertHelper::OpenSSL;
use OpenXPKI::Test::CertHelper::Workflow;
use OpenXPKI::Test::CertHelper::PEM;

################################################################################
# Other attributes
#
has certs => (
    is => 'rw',
    isa => 'HashRef[OpenXPKI::Test::CertHelper::PEM]',
    lazy => 1,
    builder => '_build_certs',
);

################################################################################
# METHODS
#

=head2 via_openssl

Class method (does not require instantiation) that creates a CSR and the
certificate on disk using the OpenSSL binary.

    my $cert = OpenXPKI::Test::CertHelper-E<gt>via_openssl(
        basedir => '/tmp',  # default to an auto-generated temp dir
        verbose => 0,
        stateOrProvinceName => 'bla',
        localityName => 'bla',
        0_organizationName => 'bla',
        organizationUnitName => 'bla',
        countryName => 'bla',
        commonName => 'bla',
        emailAddress => 'bla',
        password => 'pass',
    );
    print $cert->cert_pem;

Possible arguments are all attributes of L<OpenXPKI::Test::CertHelper::OpenSSL>.

Returns the instance of L<OpenXPKI::Test::CertHelper::OpenSSL>.

=cut
sub via_openssl {
    my $class = shift;
    my $helper = OpenXPKI::Test::CertHelper::OpenSSL->new(@_);
    $helper->create_cert;
    return $helper;
}

=head2 via_workflow

Class method (does not require instantiation) that creates a CSR and the
certificate in OpenXPKI via workflows.

    my $ch =
    my $cert_id = OpenXPKI::Test::CertHelper-E<gt>via_workflow(
        tester => $test,                      # Instance of L<OpenXPKI::Test::More> (required)
        hostname => "myhost",                 # Hostname for certificate (I<Str>, required)
        hostname2 => [],                      # List of additional hostnames (I<ArrayRef[Str]>, optional)
        profile => "I18N_OPENXPKI_PROFILE_TLS_SERVER", # Certificate profile (I<Str>, optional, default: "I18N_OPENXPKI_PROFILE_TLS_SERVER")
        requestor_gname => "tom",             # Surname of person requesting cert (I<Str>, optional)
        requestor_name => "table",            # Name of person requesting cert (I<Str>, optional)
        requestor_email => "tom@table.local", #  Email of person requesting cert (I<Str>, optional)
    );

Possible arguments are all attributes of L<OpenXPKI::Test::CertHelper::Workflow>.

Returns the ID of the created certificate.

=cut
sub via_workflow {
    my $class = shift;
    my $helper = OpenXPKI::Test::CertHelper::Workflow->new(@_);
    return $helper->create_cert; # returns the certificate ID
}

=head1 Methods

=head2 all_cert_ids

Returns an ArrayRef with the IDs ("subject_key_identifier") of all test
certificates handled by this class.

=cut
sub all_cert_ids {
    my $self = shift;
    return [ map { $_->id } values %{$self->certs} ];
}

=head2 all_cert_names

Returns an ArrayRef with the internal short names of all test certificates
handled by this class.

=cut
sub all_cert_names {
    my $self = shift;
    return [ keys %{$self->certs} ];
}

=head2 acme1_pkcs7

Returns the PKCS7 file contents that containts the certificates "acme1_root",
"acme1_signer" and "acme1_client".

=cut
sub acme1_pkcs7 {
    return "-----BEGIN PKCS7-----\n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\n-----END PKCS7-----\n";
}

# Test certificate data
sub _build_certs {
    return {
        acme_root => OpenXPKI::Test::CertHelper::PEM->new(
            label => "ACME Root CA",
            database => {
                authority_key_identifier => '2F:B1:CC:C4:B9:9E:1C:1C:EC:8A:51:3B:BA:E8:19:13:15:BE:D8:BF',
                cert_key => '10137952561889812311',
                data => "-----BEGIN CERTIFICATE-----\nMIIDkzCCAnugAwIBAgIJAIyxPiRRNB9XMA0GCSqGSIb3DQEBCwUAMFcxEzARBgoJ\nkiaJk/IsZAEZFgNPUkcxGDAWBgoJkiaJk/IsZAEZFghPcGVuWFBLSTENMAsGA1UE\nCwwEQUNNRTEXMBUGA1UEAwwOQUNNRS0xIFJvb3QgQ0EwIBcNMTcwMjE2MTY1ODQy\nWhgPMjExNzAxMjMxNjU4NDJaMFcxEzARBgoJkiaJk/IsZAEZFgNPUkcxGDAWBgoJ\nkiaJk/IsZAEZFghPcGVuWFBLSTENMAsGA1UECwwEQUNNRTEXMBUGA1UEAwwOQUNN\nRS0xIFJvb3QgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDBqJBO\nGHI3xMpwZ96As29rblcGdzlYY17cvg4AVcznfH0clxiFBHug3kcaqjyZum7MoWjH\n+u3P2s+xc1c/AEvWEsiCWmZQD3vFRCBzYD/H4hXWID0M9nEkh4jAiDmN4xkgCgm1\nOyCu4IiKK1mOoKLem2qdm6FXRJZfRGaklUtXbnu0WbQxkeDCgXERj3o2ZoKzU/ZP\nzuhyiT8dQEDDFqBUK/0uc1ZCktcwd++N9fCzMmzFF6n5czRoNYqD32vLEMj0fwlJ\nnovOPhO90vjzBTUTxqWUetCKZ8n1MOoeOlbkdDwy6nh5Df0D/UfNY3Xvx1xZL2Am\n08iQcfCwTJXBY66JAgMBAAGjYDBeMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYE\nFC+xzMS5nhwc7IpRO7roGRMVvti/MB8GA1UdIwQYMBaAFC+xzMS5nhwc7IpRO7ro\nGRMVvti/MAsGA1UdDwQEAwIBBjANBgkqhkiG9w0BAQsFAAOCAQEAqdTxzJdI8ed/\nhHU1ok0ZnIKmRRH0gdRlYpn35mAlAjJHnyb/SZMWtV6mhzHfD18IFT7phI4Ykly1\nk482rH8inf6X08ztDh2bc528mXf32XyAa0Fo8eRXeuaYBDY/NoKS/d/YrRJfjvYA\nsZHnMq5+p6BYeID9P9yz+DiLJVT24M6+SRCiZotHvN+01sy/zVadCB0sZUsQJr+y\nhvY4lG516j5AhZ815k9kNQX0fDvwcPffvLRDx+ireNkvBbIT1JwpK0a7T08n8NrT\nFJx0sBlPlbv7FD5Wi4Vob2LcGk4/jnRxyGMrRBUF6bUCnq1TYqUWQZlCvz5CfLIr\nIoEjHNtZXQ==\n-----END CERTIFICATE-----\n",
                identifier => 'Ri08UcTF0pEXQEQVngBwa-JvPQA',
                issuer_dn => 'CN=ACME-1 Root CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'Ri08UcTF0pEXQEQVngBwa-JvPQA',
                loa => undef,
                notafter => '4294967295',  # 2106-02-07T06:28:15
                notbefore => '1487264322', # 2017-02-16T16:58:42
                pki_realm => 'acme-1',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:c1:a8:90:4e:18:72:37:c4:ca:70:67:de:80:b3:\n    6f:6b:6e:57:06:77:39:58:63:5e:dc:be:0e:00:55:\n    cc:e7:7c:7d:1c:97:18:85:04:7b:a0:de:47:1a:aa:\n    3c:99:ba:6e:cc:a1:68:c7:fa:ed:cf:da:cf:b1:73:\n    57:3f:00:4b:d6:12:c8:82:5a:66:50:0f:7b:c5:44:\n    20:73:60:3f:c7:e2:15:d6:20:3d:0c:f6:71:24:87:\n    88:c0:88:39:8d:e3:19:20:0a:09:b5:3b:20:ae:e0:\n    88:8a:2b:59:8e:a0:a2:de:9b:6a:9d:9b:a1:57:44:\n    96:5f:44:66:a4:95:4b:57:6e:7b:b4:59:b4:31:91:\n    e0:c2:81:71:11:8f:7a:36:66:82:b3:53:f6:4f:ce:\n    e8:72:89:3f:1d:40:40:c3:16:a0:54:2b:fd:2e:73:\n    56:42:92:d7:30:77:ef:8d:f5:f0:b3:32:6c:c5:17:\n    a9:f9:73:34:68:35:8a:83:df:6b:cb:10:c8:f4:7f:\n    09:49:9e:8b:ce:3e:13:bd:d2:f8:f3:05:35:13:c6:\n    a5:94:7a:d0:8a:67:c9:f5:30:ea:1e:3a:56:e4:74:\n    3c:32:ea:78:79:0d:fd:03:fd:47:cd:63:75:ef:c7:\n    5c:59:2f:60:26:d3:c8:90:71:f0:b0:4c:95:c1:63:\n    ae:89\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ACME-1 Root CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '2F:B1:CC:C4:B9:9E:1C:1C:EC:8A:51:3B:BA:E8:19:13:15:BE:D8:BF',
            },
        ),
        acme_signer => OpenXPKI::Test::CertHelper::PEM->new(
            label => "ACME Signing CA",
            database => {
                authority_key_identifier => '2F:B1:CC:C4:B9:9E:1C:1C:EC:8A:51:3B:BA:E8:19:13:15:BE:D8:BF',
                cert_key => '1',
                data => "-----BEGIN CERTIFICATE-----\nMIIDjjCCAnagAwIBAgIBATANBgkqhkiG9w0BAQsFADBXMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nFzAVBgNVBAMMDkFDTUUtMSBSb290IENBMCAXDTE3MDIxNjE2NTg0MloYDzIxMTcw\nMTIzMTY1ODQyWjBaMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZImiZPyLGQB\nGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxGjAYBgNVBAMMEUFDTUUtMSBTaWdu\naW5nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuoK7FgQLvbf4\nY51zw0UCUSvLCewqnYyRW40NbbyhccaU4lzGGJfhHz6tCjmuJ8V4rss8AuYCVAc6\n4xoMSaQeC+UXoAepSFPwqOGYNg/RC47yMlwmEqSxfI4poMBvV0L2XWY/t7HVhDNj\n868eC/9ob2+Q1jFt75R8Sc9+TAM8thv0MgLAiqdpVtuiNhGkF4gnSG9EpGkzG2uO\nKxR+veShRy0MX/U2CY1cgDX90fa4mlncJS3AYPvoFidHj+AJNZWY6w4ljRM5BlP6\npZj/ES68sL7FcZc8h8BtOjinrkgy90KCG4ZqD0Xc8NN0tPSUV+eavv78SsrV8HGM\n1QNRKb5nIwIDAQABo2AwXjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBT0RN8k\nD1xPDiPXX5kxBxdeGSG7eTAfBgNVHSMEGDAWgBQvsczEuZ4cHOyKUTu66BkTFb7Y\nvzALBgNVHQ8EBAMCAQYwDQYJKoZIhvcNAQELBQADggEBABAmIIGvt34DUWFEHPOu\nw+a4KAXrjkBAVCWWXL8eFQQ1F61i5opQvCOw3VPFtByISFxBX3dI7JhydPbIJJvR\n8cufqijd3hIm9gxa9Ye6fA84xOz855t7niNaJY55kxAGnxC3Csqwx0oicjbz94rp\nDv9OgtZHWSwR/rjzrYhCF96/AkkVQVhDwWjGVLMDcUemcM4IMsPu0gl8qln8Xv7b\n6IrWeRz4rFvwSMDLQEE2YSZjFcU99WA+JB+NnmAK5oIRITpJbNm08yoQYe23Q8ag\n9BeT/2ngAgLwZ7jEVFUD77Md5HKIr2NecxfhXxLnC5qnTiRKaVtr/QYzXSRCkShe\nOmo=\n-----END CERTIFICATE-----\n",
                identifier => 'sLjz3BunOk-rLQLSMJU8RTRaNQ8',
                issuer_dn => 'CN=ACME-1 Root CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'Ri08UcTF0pEXQEQVngBwa-JvPQA',
                loa => undef,
                notafter => '4294967295',  # 2106-02-07T06:28:15
                notbefore => '1487264322', # 2017-02-16T16:58:42
                pki_realm => 'acme-1',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:ba:82:bb:16:04:0b:bd:b7:f8:63:9d:73:c3:45:\n    02:51:2b:cb:09:ec:2a:9d:8c:91:5b:8d:0d:6d:bc:\n    a1:71:c6:94:e2:5c:c6:18:97:e1:1f:3e:ad:0a:39:\n    ae:27:c5:78:ae:cb:3c:02:e6:02:54:07:3a:e3:1a:\n    0c:49:a4:1e:0b:e5:17:a0:07:a9:48:53:f0:a8:e1:\n    98:36:0f:d1:0b:8e:f2:32:5c:26:12:a4:b1:7c:8e:\n    29:a0:c0:6f:57:42:f6:5d:66:3f:b7:b1:d5:84:33:\n    63:f3:af:1e:0b:ff:68:6f:6f:90:d6:31:6d:ef:94:\n    7c:49:cf:7e:4c:03:3c:b6:1b:f4:32:02:c0:8a:a7:\n    69:56:db:a2:36:11:a4:17:88:27:48:6f:44:a4:69:\n    33:1b:6b:8e:2b:14:7e:bd:e4:a1:47:2d:0c:5f:f5:\n    36:09:8d:5c:80:35:fd:d1:f6:b8:9a:59:dc:25:2d:\n    c0:60:fb:e8:16:27:47:8f:e0:09:35:95:98:eb:0e:\n    25:8d:13:39:06:53:fa:a5:98:ff:11:2e:bc:b0:be:\n    c5:71:97:3c:87:c0:6d:3a:38:a7:ae:48:32:f7:42:\n    82:1b:86:6a:0f:45:dc:f0:d3:74:b4:f4:94:57:e7:\n    9a:be:fe:fc:4a:ca:d5:f0:71:8c:d5:03:51:29:be:\n    67:23\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ACME-1 Signing CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => 'F4:44:DF:24:0F:5C:4F:0E:23:D7:5F:99:31:07:17:5E:19:21:BB:79',
            },
        ),
        acme_client => OpenXPKI::Test::CertHelper::PEM->new(
            label => "ACME Client",
            database => {
                authority_key_identifier => 'F4:44:DF:24:0F:5C:4F:0E:23:D7:5F:99:31:07:17:5E:19:21:BB:79',
                cert_key => '2',
                data => "-----BEGIN CERTIFICATE-----\nMIIDejCCAmKgAwIBAgIBAjANBgkqhkiG9w0BAQsFADBaMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGjAYBgNVBAMMEUFDTUUtMSBTaWduaW5nIENBMCAXDTE3MDIxNjE2NTg0MloYDzIx\nMTcwMTIzMTY1ODQyWjBWMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZImiZPy\nLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxFjAUBgNVBAMMDUFDTUUtMSBD\nbGllbnQwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDf8zUPAysGj3gH\nVBL2JFREjzS7sCQ6sI44fxCkePQz7mWhMbfJCrtuU2saLcsNMBbVYnDTstWbDJdl\nDdxw1XPJYxZulf/BGiV0taD7HcCV9Fo9emoA1Oi3qAwTAh24L/DUAI8oT5jubodO\nqDzvspIhXnFV3m68+0G47XJCFS7Dp4DRcf/S2DK6Jf/JWiCCFtrWWusK//QxPSkc\nvd6OqHKUkp37p9qvfS6l72TMPfjDxkm8hJt1RH2EgoS5JbXP24AatlyY83kY0KF1\njKJGrjRhyoKCWTUVnuqIz1Ki3W2S4toRL/rYzO8aaO1StRvpyxrkfI9tnqQ7fSYy\nSMJ0sU/lAgMBAAGjTTBLMAkGA1UdEwQCMAAwHQYDVR0OBBYEFIkTF/rxFBuMBB+l\naRY/ulgRXRg2MB8GA1UdIwQYMBaAFPRE3yQPXE8OI9dfmTEHF14ZIbt5MA0GCSqG\nSIb3DQEBCwUAA4IBAQBvXvvJZoAcH659yi+V2lgRGo3jpkyn+qShtg+xJUTMisZ6\nB893yg10XXvPmAh2ccbGLZdlGmAG6qtOTCB7v/rDq0ZSktgj7MvaBk4bYVVeDgGa\nXr7P9NpWN/KN4jZnsbdhKfQUUBNx15peOB890QxQRyhdPe0NTt6Lsj59L77mS13W\n0KPHKNlozPTAjc+3taIoX6maHH4efWeXZ1O593EMyProhidr4OLg4WS3aHNgdyj2\nB2oQRekpZjh1jLI1xOSJkmhjl20TpI3icwAUKoef2x5vouZMdBRfc4NZmbtvfJWQ\nMgt5gguh6rZSJozLLNYIF1q3nwmvHAjZM5tlrFH+\n-----END CERTIFICATE-----\n",
                identifier => '04XzBpBzgLtzdSAPjCr5JVJkKfQ',
                issuer_dn => 'CN=ACME-1 Signing CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'sLjz3BunOk-rLQLSMJU8RTRaNQ8',
                loa => undef,
                notafter => '4294967295',  # 2106-02-07T06:28:15
                notbefore => '1487264322', # 2017-02-16T16:58:42
                pki_realm => 'acme-1',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:df:f3:35:0f:03:2b:06:8f:78:07:54:12:f6:24:\n    54:44:8f:34:bb:b0:24:3a:b0:8e:38:7f:10:a4:78:\n    f4:33:ee:65:a1:31:b7:c9:0a:bb:6e:53:6b:1a:2d:\n    cb:0d:30:16:d5:62:70:d3:b2:d5:9b:0c:97:65:0d:\n    dc:70:d5:73:c9:63:16:6e:95:ff:c1:1a:25:74:b5:\n    a0:fb:1d:c0:95:f4:5a:3d:7a:6a:00:d4:e8:b7:a8:\n    0c:13:02:1d:b8:2f:f0:d4:00:8f:28:4f:98:ee:6e:\n    87:4e:a8:3c:ef:b2:92:21:5e:71:55:de:6e:bc:fb:\n    41:b8:ed:72:42:15:2e:c3:a7:80:d1:71:ff:d2:d8:\n    32:ba:25:ff:c9:5a:20:82:16:da:d6:5a:eb:0a:ff:\n    f4:31:3d:29:1c:bd:de:8e:a8:72:94:92:9d:fb:a7:\n    da:af:7d:2e:a5:ef:64:cc:3d:f8:c3:c6:49:bc:84:\n    9b:75:44:7d:84:82:84:b9:25:b5:cf:db:80:1a:b6:\n    5c:98:f3:79:18:d0:a1:75:8c:a2:46:ae:34:61:ca:\n    82:82:59:35:15:9e:ea:88:cf:52:a2:dd:6d:92:e2:\n    da:11:2f:fa:d8:cc:ef:1a:68:ed:52:b5:1b:e9:cb:\n    1a:e4:7c:8f:6d:9e:a4:3b:7d:26:32:48:c2:74:b1:\n    4f:e5\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ACME-1 Client,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '89:13:17:FA:F1:14:1B:8C:04:1F:A5:69:16:3F:BA:58:11:5D:18:36',
            },
        ),
        acme2_root => OpenXPKI::Test::CertHelper::PEM->new(
            label => "ACME-2 Root CA",
            database => {
                authority_key_identifier => '99:08:1D:F2:0B:53:49:28:F0:29:37:CA:88:97:2D:92:A0:68:2B:89',
                cert_key => '11310484291401902951',
                data => "-----BEGIN CERTIFICATE-----\nMIIDkzCCAnugAwIBAgIJAJz26YmapWtnMA0GCSqGSIb3DQEBCwUAMFcxEzARBgoJ\nkiaJk/IsZAEZFgNPUkcxGDAWBgoJkiaJk/IsZAEZFghPcGVuWFBLSTENMAsGA1UE\nCwwEQUNNRTEXMBUGA1UEAwwOQUNNRS0yIFJvb3QgQ0EwIBcNMTcwMjE2MTY1NzU5\nWhgPMjExNzAxMjMxNjU3NTlaMFcxEzARBgoJkiaJk/IsZAEZFgNPUkcxGDAWBgoJ\nkiaJk/IsZAEZFghPcGVuWFBLSTENMAsGA1UECwwEQUNNRTEXMBUGA1UEAwwOQUNN\nRS0yIFJvb3QgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCx3iYv\nFj6DLUlWyCNJhIFgJ3jbQo/chOU//PsoYDmmFnFus0GV0CHXDAa+RTZsEoRmDJuq\nJH4TfS7VwrCiCMcXONnyP3bJa/dpfAA4sEWSTmKK/czaEAjpISrScAY6StC4H2Sy\nBCEegLfGTHw1cZoE5BAqsPTZzQf3NXKlzaUyXmgZohgXPoQr2s4QupCVSXAz3sDs\nCpFL/nWLnkxjD4Pi72g+WkE9BuV96mUCF0nNXcngRXx60e9sGjcCtqjfC5DkyZhK\n+yQ4uLTrhPkf93IILQ4teYERZRSSzfxRLwMwhDJR6BXD5AaODqjLNFN/5w0oh+I7\nUcwMRfrz4JutlvhJAgMBAAGjYDBeMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYE\nFJkIHfILU0ko8Ck3yoiXLZKgaCuJMB8GA1UdIwQYMBaAFJkIHfILU0ko8Ck3yoiX\nLZKgaCuJMAsGA1UdDwQEAwIBBjANBgkqhkiG9w0BAQsFAAOCAQEAfeuD7nsFVpZd\n7MqLYPbHJL+zG8hUNeJqiJI4AQBdF2RuFsqVKnhJaQxHiHI++oPKRrKgj4atUYRn\nraehZzVi9g1qc3ZHH2E4jAll8FoAyXreKc9rMUYuLX/np+jSAewfzH/iGAvz8/Yn\ny59UxFwzmxz5NkIMHm8NMC6l4oMgPAF0CWexkARUdoKFOk75kR5JC+SDEmdXoeec\nujgYSFmN0o9arR1JXKaaeXkLWQ48UFeIHfEiMWgerpZsO/4KliLp7BHF7FTnD3pl\nRvk/YUgjZVtGzSahvXOE0pyF9fMFff+ry+7uw9AclOEXmOq96h6BrdP4PeWZNY4R\nD2TQMcpx5A==\n-----END CERTIFICATE-----\n",
                identifier => 'HRJ3wKdu7Xrf0eki_Coo-Q9OGrA',
                issuer_dn => 'CN=ACME-2 Root CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'HRJ3wKdu7Xrf0eki_Coo-Q9OGrA',
                loa => undef,
                notafter => '4294967295',  # 2106-02-07T06:28:15
                notbefore => '1487264279', # 2017-02-16T16:57:59
                pki_realm => 'acme-2',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:b1:de:26:2f:16:3e:83:2d:49:56:c8:23:49:84:\n    81:60:27:78:db:42:8f:dc:84:e5:3f:fc:fb:28:60:\n    39:a6:16:71:6e:b3:41:95:d0:21:d7:0c:06:be:45:\n    36:6c:12:84:66:0c:9b:aa:24:7e:13:7d:2e:d5:c2:\n    b0:a2:08:c7:17:38:d9:f2:3f:76:c9:6b:f7:69:7c:\n    00:38:b0:45:92:4e:62:8a:fd:cc:da:10:08:e9:21:\n    2a:d2:70:06:3a:4a:d0:b8:1f:64:b2:04:21:1e:80:\n    b7:c6:4c:7c:35:71:9a:04:e4:10:2a:b0:f4:d9:cd:\n    07:f7:35:72:a5:cd:a5:32:5e:68:19:a2:18:17:3e:\n    84:2b:da:ce:10:ba:90:95:49:70:33:de:c0:ec:0a:\n    91:4b:fe:75:8b:9e:4c:63:0f:83:e2:ef:68:3e:5a:\n    41:3d:06:e5:7d:ea:65:02:17:49:cd:5d:c9:e0:45:\n    7c:7a:d1:ef:6c:1a:37:02:b6:a8:df:0b:90:e4:c9:\n    98:4a:fb:24:38:b8:b4:eb:84:f9:1f:f7:72:08:2d:\n    0e:2d:79:81:11:65:14:92:cd:fc:51:2f:03:30:84:\n    32:51:e8:15:c3:e4:06:8e:0e:a8:cb:34:53:7f:e7:\n    0d:28:87:e2:3b:51:cc:0c:45:fa:f3:e0:9b:ad:96:\n    f8:49\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ACME-2 Root CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '99:08:1D:F2:0B:53:49:28:F0:29:37:CA:88:97:2D:92:A0:68:2B:89',
            },
        ),
        acme2_signer => OpenXPKI::Test::CertHelper::PEM->new(
            label => "ACME-2 Signing CA",
            database => {
                authority_key_identifier => '99:08:1D:F2:0B:53:49:28:F0:29:37:CA:88:97:2D:92:A0:68:2B:89',
                cert_key => '1',
                data => "-----BEGIN CERTIFICATE-----\nMIIDjjCCAnagAwIBAgIBATANBgkqhkiG9w0BAQsFADBXMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nFzAVBgNVBAMMDkFDTUUtMiBSb290IENBMCAXDTE3MDIxNjE2NTc1OVoYDzIxMTcw\nMTIzMTY1NzU5WjBaMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZImiZPyLGQB\nGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxGjAYBgNVBAMMEUFDTUUtMiBTaWdu\naW5nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0sFK8eR/AyvT\nDZ7UwNmaFxPQzgVVa/6eYomRDJP85O/SrkLgeYFSBQ4BSs8j4t1I51rGUnCAsybd\n+RhspoeapRAY4+Caqbjnuc39B2A5s5qiolaYkcwoxIPUbP2k1+BNSKWeLoRESX+2\nU2lfWb2gsvCETq2kWV55qFO5Q2b1YIbvbGttIPRGw7r2n6X8tA60BJ4kH1CmMRnU\ntLdv7pOLLcnIACNof8XCKYKiyepT2UrvqWG5y2CxPC77UhhuJCvjlzilGjGq7y1S\nJIwkyrqca+UVec1Sn3KUmR9Qk6LpVbfWmbwjl3/PEKVhlYY1chNA+zPdFx10VfrT\nZ5jET2qiUwIDAQABo2AwXjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBQO9JSb\n8YjiWC12bNYlYmmID36AKjAfBgNVHSMEGDAWgBSZCB3yC1NJKPApN8qIly2SoGgr\niTALBgNVHQ8EBAMCAQYwDQYJKoZIhvcNAQELBQADggEBAJSE9Kcjd/sXtN+DsYI2\nZ9Oeqx1LYlQdCz8SHA80RzRP2A+bLB/EqwBoEAgk++f7UhEymbPBE4oqrv8VW2FV\nbjoYXc1ab8yQlEcMlY8np/rxn9W9vrjr7lALts++AwBCQL0XEDcAk3IlVQdadJQu\npxJgyro3XKQXRl9bVbBpWI7GG7eFyC9hq58USSdxCsm1VzTXwAUPRpwOzENmeYg2\nnqMOXMK34PuRAFhO7RlaN+HHtKoIvqRFLGIeP42j5vqLpA4YXD1z8zqUDVYk78Yb\nUjwOSUo6s03TiNWCnVgA9V0nxycnXUsj7fMeXYUliVDyToAWUpRDKuikSjusYn8c\nfEI=\n-----END CERTIFICATE-----\n",
                identifier => 'QRGQSHUv3_v2rA4tI1593y9Dla0',
                issuer_dn => 'CN=ACME-2 Root CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'HRJ3wKdu7Xrf0eki_Coo-Q9OGrA',
                loa => undef,
                notafter => '4294967295',  # 2106-02-07T06:28:15
                notbefore => '1487264279', # 2017-02-16T16:57:59
                pki_realm => 'acme-2',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:d2:c1:4a:f1:e4:7f:03:2b:d3:0d:9e:d4:c0:d9:\n    9a:17:13:d0:ce:05:55:6b:fe:9e:62:89:91:0c:93:\n    fc:e4:ef:d2:ae:42:e0:79:81:52:05:0e:01:4a:cf:\n    23:e2:dd:48:e7:5a:c6:52:70:80:b3:26:dd:f9:18:\n    6c:a6:87:9a:a5:10:18:e3:e0:9a:a9:b8:e7:b9:cd:\n    fd:07:60:39:b3:9a:a2:a2:56:98:91:cc:28:c4:83:\n    d4:6c:fd:a4:d7:e0:4d:48:a5:9e:2e:84:44:49:7f:\n    b6:53:69:5f:59:bd:a0:b2:f0:84:4e:ad:a4:59:5e:\n    79:a8:53:b9:43:66:f5:60:86:ef:6c:6b:6d:20:f4:\n    46:c3:ba:f6:9f:a5:fc:b4:0e:b4:04:9e:24:1f:50:\n    a6:31:19:d4:b4:b7:6f:ee:93:8b:2d:c9:c8:00:23:\n    68:7f:c5:c2:29:82:a2:c9:ea:53:d9:4a:ef:a9:61:\n    b9:cb:60:b1:3c:2e:fb:52:18:6e:24:2b:e3:97:38:\n    a5:1a:31:aa:ef:2d:52:24:8c:24:ca:ba:9c:6b:e5:\n    15:79:cd:52:9f:72:94:99:1f:50:93:a2:e9:55:b7:\n    d6:99:bc:23:97:7f:cf:10:a5:61:95:86:35:72:13:\n    40:fb:33:dd:17:1d:74:55:fa:d3:67:98:c4:4f:6a:\n    a2:53\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ACME-2 Signing CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '0E:F4:94:9B:F1:88:E2:58:2D:76:6C:D6:25:62:69:88:0F:7E:80:2A',
            },
        ),
        acme2_client => OpenXPKI::Test::CertHelper::PEM->new(
            label => "ACME-2 Client",
            database => {
                authority_key_identifier => '0E:F4:94:9B:F1:88:E2:58:2D:76:6C:D6:25:62:69:88:0F:7E:80:2A',
                cert_key => '2',
                data => "-----BEGIN CERTIFICATE-----\nMIIDejCCAmKgAwIBAgIBAjANBgkqhkiG9w0BAQsFADBaMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGjAYBgNVBAMMEUFDTUUtMiBTaWduaW5nIENBMCAXDTE3MDIxNjE2NTc1OVoYDzIx\nMTcwMTIzMTY1NzU5WjBWMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZImiZPy\nLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxFjAUBgNVBAMMDUFDTUUtMiBD\nbGllbnQwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC6ApC820jCHUFt\npejJITJUhSAg/cbShMvvnKwazH3L8elt2uN3AwwjPtAfSQHsQVM/mxOtgjrK4KV4\n8z1PcSVcFm+Lwt27SjkU38dJ2ehK1tnVACfoanxv/lwtamrrVAzsKuTHMAoeh8CZ\nBS0PgHtPUEIApZJAWl7CaiudrlgjPZEMX4STDuoPVpa7O3y+6g4G/va3Gdxug2h1\nLuM3dzapau2Frqo64WExOj+r8pCsV3l/5B27sGwciGPBRvYJLenbnrJs9m0g8sRt\nE1TMJMUEkHz3bOmU1fk2W4TpY2saXCb9uREg9zTCzs1ImiS6wtzCEGV6Z7H0nF/U\nsOeLSWklAgMBAAGjTTBLMAkGA1UdEwQCMAAwHQYDVR0OBBYEFDmhB9M1fFyQhU5E\n31rF16f5wiECMB8GA1UdIwQYMBaAFA70lJvxiOJYLXZs1iViaYgPfoAqMA0GCSqG\nSIb3DQEBCwUAA4IBAQBqSCig4XC8Z9RUrICTQNHqi+987JmiNbOnI6TfjrUD2dIf\nDK5RKO7jdpiuoHbTb0sbEPyYmyIDG7p/y7RgU49QcrW+31axAJInRwzal7jKVrEY\nVPzMDwfqvG8yUq2z4zkLhjVuyeHgTHvdrGTe1GuTsjXyYTQY6lTKn+Bm64Ul4M08\ns844fDMzsjT7GFXkdKP5wWNMVAX/+PfPQs/aE3AacaaCQ32P6q4ohtWxXucF7fT9\nLCSvh8/1dBnZ7XDj/eph/8HvHa/dPWaBKzHkbKsETEF84eiOfoxdvji0S3RUSAPd\nrqpx2zkkC45eyTZGNiPm2TK1nJkb1BTjbE4xa2iH\n-----END CERTIFICATE-----\n",
                identifier => 'CPYneSZtM110FsxCphDlPK_3wrY',
                issuer_dn => 'CN=ACME-2 Signing CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'QRGQSHUv3_v2rA4tI1593y9Dla0',
                loa => undef,
                notafter => '4294967295',  # 2106-02-07T06:28:15
                notbefore => '1487264279', # 2017-02-16T16:57:59
                pki_realm => 'acme-2',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:ba:02:90:bc:db:48:c2:1d:41:6d:a5:e8:c9:21:\n    32:54:85:20:20:fd:c6:d2:84:cb:ef:9c:ac:1a:cc:\n    7d:cb:f1:e9:6d:da:e3:77:03:0c:23:3e:d0:1f:49:\n    01:ec:41:53:3f:9b:13:ad:82:3a:ca:e0:a5:78:f3:\n    3d:4f:71:25:5c:16:6f:8b:c2:dd:bb:4a:39:14:df:\n    c7:49:d9:e8:4a:d6:d9:d5:00:27:e8:6a:7c:6f:fe:\n    5c:2d:6a:6a:eb:54:0c:ec:2a:e4:c7:30:0a:1e:87:\n    c0:99:05:2d:0f:80:7b:4f:50:42:00:a5:92:40:5a:\n    5e:c2:6a:2b:9d:ae:58:23:3d:91:0c:5f:84:93:0e:\n    ea:0f:56:96:bb:3b:7c:be:ea:0e:06:fe:f6:b7:19:\n    dc:6e:83:68:75:2e:e3:37:77:36:a9:6a:ed:85:ae:\n    aa:3a:e1:61:31:3a:3f:ab:f2:90:ac:57:79:7f:e4:\n    1d:bb:b0:6c:1c:88:63:c1:46:f6:09:2d:e9:db:9e:\n    b2:6c:f6:6d:20:f2:c4:6d:13:54:cc:24:c5:04:90:\n    7c:f7:6c:e9:94:d5:f9:36:5b:84:e9:63:6b:1a:5c:\n    26:fd:b9:11:20:f7:34:c2:ce:cd:48:9a:24:ba:c2:\n    dc:c2:10:65:7a:67:b1:f4:9c:5f:d4:b0:e7:8b:49:\n    69:25\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ACME-2 Client,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '39:A1:07:D3:35:7C:5C:90:85:4E:44:DF:5A:C5:D7:A7:F9:C2:21:02',
            },
        ),
        expired_root => OpenXPKI::Test::CertHelper::PEM->new(
            label => "Expired Root CA",
            database => {
                authority_key_identifier => '94:3A:81:EF:5C:58:88:A8:97:CD:34:FF:35:DD:EB:71:B6:FE:FA:2E',
                cert_key => '11692266029049298850',
                data => "-----BEGIN CERTIFICATE-----\nMIIDkzCCAnugAwIBAgIJAKJDRgFQ2b+iMA0GCSqGSIb3DQEBCwUAMFgxEzARBgoJ\nkiaJk/IsZAEZFgNPUkcxGDAWBgoJkiaJk/IsZAEZFghPcGVuWFBLSTEQMA4GA1UE\nCwwHQUNNRSBDQTEVMBMGA1UEAwwMQUNNRSBSb290IENBMB4XDTE1MDEyNzAwMTUw\nMVoXDTE1MDIyNjAwMTUwMVowWDETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmS\nJomT8ixkARkWCE9wZW5YUEtJMRAwDgYDVQQLDAdBQ01FIENBMRUwEwYDVQQDDAxB\nQ01FIFJvb3QgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDnHV0W\nZnsX4LBZNI9iMoidOhBx/fOTRCHjO/73ms16begvDSqbhwDZms5OhC9BYAmmmYjJ\nIvlPkOR/IiU6bLtgDk9WZjIbKw28gjM4C6EZtCPa2vxwXJUR5vcDZerdN3/9IAAm\n0vMHgFzDxC0t472yURF9B4oRXbN2RxQ197SMml+2XlnWc6bBSNSVWfCWVHbTlU00\nW4nWqIoPcGk2MceMgo9t4Ta/jpfXivMWRJ3SGw+HH6ETtJmI8BpQNzarawsOEKKN\n1zCy5Wya4U72KwitZpr1Qcr1d+kLe5NLGPVrQpYBHjmxXWXza7VxVEW79TKtzu2g\n8jRMpkYKfd0TlcY3AgMBAAGjYDBeMB0GA1UdDgQWBBSUOoHvXFiIqJfNNP813etx\ntv76LjAfBgNVHSMEGDAWgBSUOoHvXFiIqJfNNP813etxtv76LjAPBgNVHRMBAf8E\nBTADAQH/MAsGA1UdDwQEAwIBBjANBgkqhkiG9w0BAQsFAAOCAQEABLiqD5BzqFCK\nB7aqWZs29Xc42DlofJN3i0NXTWcM0bNuQJqOJMR96seyNPZZu41pHnJV0WDPhuNL\nD0tXku1TSGpf6fmmuPSfxksXjNG9HXivmPA89u6DfPA4+BZ+Q+yOIKQeciHkODUQ\n+g8kWASmMH4zWXxQpZQ9iI7LdZxRRmuwpCATuyth/yU6aa6aJsg4Juuf4P5OO4vs\nvC1kqgUWNc/OIHzgu6NBLv2XUr0mka3iRT4hsZcFBgyKJhf4b1hmC24WakuWqSaS\n/hx42PNwpbirUlNVrHWIm50z3jRCKgJHfJwrpWIWxMkEz6Rn9AeY2AEUpy5RGjPU\nfvP239/QKg==\n-----END CERTIFICATE-----\n",
                identifier => 'ig29xFOKRNUpPh8spF6hyCWgExA',
                issuer_dn => 'CN=ACME Root CA,OU=ACME CA,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'ig29xFOKRNUpPh8spF6hyCWgExA',
                loa => undef,
                notafter => '1424909701',  # 2015-02-26T00:15:01
                notbefore => '1422317701', # 2015-01-27T00:15:01
                pki_realm => 'acme-expired',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:e7:1d:5d:16:66:7b:17:e0:b0:59:34:8f:62:32:\n    88:9d:3a:10:71:fd:f3:93:44:21:e3:3b:fe:f7:9a:\n    cd:7a:6d:e8:2f:0d:2a:9b:87:00:d9:9a:ce:4e:84:\n    2f:41:60:09:a6:99:88:c9:22:f9:4f:90:e4:7f:22:\n    25:3a:6c:bb:60:0e:4f:56:66:32:1b:2b:0d:bc:82:\n    33:38:0b:a1:19:b4:23:da:da:fc:70:5c:95:11:e6:\n    f7:03:65:ea:dd:37:7f:fd:20:00:26:d2:f3:07:80:\n    5c:c3:c4:2d:2d:e3:bd:b2:51:11:7d:07:8a:11:5d:\n    b3:76:47:14:35:f7:b4:8c:9a:5f:b6:5e:59:d6:73:\n    a6:c1:48:d4:95:59:f0:96:54:76:d3:95:4d:34:5b:\n    89:d6:a8:8a:0f:70:69:36:31:c7:8c:82:8f:6d:e1:\n    36:bf:8e:97:d7:8a:f3:16:44:9d:d2:1b:0f:87:1f:\n    a1:13:b4:99:88:f0:1a:50:37:36:ab:6b:0b:0e:10:\n    a2:8d:d7:30:b2:e5:6c:9a:e1:4e:f6:2b:08:ad:66:\n    9a:f5:41:ca:f5:77:e9:0b:7b:93:4b:18:f5:6b:42:\n    96:01:1e:39:b1:5d:65:f3:6b:b5:71:54:45:bb:f5:\n    32:ad:ce:ed:a0:f2:34:4c:a6:46:0a:7d:dd:13:95:\n    c6:37\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ACME Root CA,OU=ACME CA,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '94:3A:81:EF:5C:58:88:A8:97:CD:34:FF:35:DD:EB:71:B6:FE:FA:2E',
            },
        ),
        expired_signer => OpenXPKI::Test::CertHelper::PEM->new(
            label => "Cert signed by expired Root CA",
            database => {
                authority_key_identifier => '94:3A:81:EF:5C:58:88:A8:97:CD:34:FF:35:DD:EB:71:B6:FE:FA:2E',
                cert_key => '1',
                data => "-----BEGIN CERTIFICATE-----\nMIIDjjCCAnagAwIBAgIBATANBgkqhkiG9w0BAQsFADBYMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxEDAOBgNVBAsMB0FDTUUg\nQ0ExFTATBgNVBAMMDEFDTUUgUm9vdCBDQTAeFw0xNTAxMjcwMDE1MDJaFw0xNTAx\nMjgwMDE1MDJaMFsxEzARBgoJkiaJk/IsZAEZFgNPUkcxGDAWBgoJkiaJk/IsZAEZ\nFghPcGVuWFBLSTEQMA4GA1UECwwHQUNNRSBDQTEYMBYGA1UEAwwPQUNNRSBTaWdu\naW5nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAxwgkacEdUlZs\nxzJQqz58AJgu6ikPIb3zWbr/BaG+usjmVC+WabqmUiPHllbE7/TfBn4T4uxtXPBa\nxmIVueoXbGhexgTorGPAReQqhUPZ5KlEGVqb02hc0uIJ1ff8eiRlitqeO0GbCIzo\nJXsYw323m3YYftxlbFIt26gFikvi9zaoeaoxDFyky+fErBkvle6JGV508aZBph/S\nBr3xmzylrVEoO4bkePDIaQBzdUNRh6FDG7ING+YbjtZfYgS2UjP3gg474EeztbtH\ngPww2aUfnlIYtXqqt9bXSrbywJ4EM/OvSr26S1Txuh8tp5fC9tngTmb1ypnlUnOt\nnlA1JK/9oQIDAQABo2AwXjAdBgNVHQ4EFgQU5zb2OrQeUD6wx6nX1ZriqoCmD7ww\nHwYDVR0jBBgwFoAUlDqB71xYiKiXzTT/Nd3rcbb++i4wDwYDVR0TAQH/BAUwAwEB\n/zALBgNVHQ8EBAMCAQYwDQYJKoZIhvcNAQELBQADggEBANQpf3CrUNOc2XD5cvJV\nIbS4zE1pxRq/bsxkK3nj9th9OdseAqsiWwKuLz1j8KkFN+2eqjvisH5UCzcW/n4k\nJFjFJ+hq0UKkqiGv6KtdMIhdM8rODDnwLQGMCD8vKqNZk3vI1lFbEuTmlz9a95d8\nVkWfgz4/8a7PmIcMp87jFiepweobeHoq+081sHwQnUMgjLujLscfJevHWSrbtFD9\nOPWyyp62FbHQckU5tn6dQYgJsLCJp7jJ8jf5RCQaXKwV+Q0qhDOyaCVIhCzP5gW2\n+BylcwN+rNmBH0RP0QzurBU0PrR2xrlAzXZYuMAB8D0cAsziyvPZtV5fDn9RZG7G\nvW0=\n-----END CERTIFICATE-----\n",
                identifier => 'fcE0MpW-8xXvb5gZTiVYkNMHP30',
                issuer_dn => 'CN=ACME Root CA,OU=ACME CA,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'ig29xFOKRNUpPh8spF6hyCWgExA',
                loa => undef,
                notafter => '1422404102',  # 2015-01-28T00:15:02
                notbefore => '1422317702', # 2015-01-27T00:15:02
                pki_realm => 'acme-expired',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:c7:08:24:69:c1:1d:52:56:6c:c7:32:50:ab:3e:\n    7c:00:98:2e:ea:29:0f:21:bd:f3:59:ba:ff:05:a1:\n    be:ba:c8:e6:54:2f:96:69:ba:a6:52:23:c7:96:56:\n    c4:ef:f4:df:06:7e:13:e2:ec:6d:5c:f0:5a:c6:62:\n    15:b9:ea:17:6c:68:5e:c6:04:e8:ac:63:c0:45:e4:\n    2a:85:43:d9:e4:a9:44:19:5a:9b:d3:68:5c:d2:e2:\n    09:d5:f7:fc:7a:24:65:8a:da:9e:3b:41:9b:08:8c:\n    e8:25:7b:18:c3:7d:b7:9b:76:18:7e:dc:65:6c:52:\n    2d:db:a8:05:8a:4b:e2:f7:36:a8:79:aa:31:0c:5c:\n    a4:cb:e7:c4:ac:19:2f:95:ee:89:19:5e:74:f1:a6:\n    41:a6:1f:d2:06:bd:f1:9b:3c:a5:ad:51:28:3b:86:\n    e4:78:f0:c8:69:00:73:75:43:51:87:a1:43:1b:b2:\n    0d:1b:e6:1b:8e:d6:5f:62:04:b6:52:33:f7:82:0e:\n    3b:e0:47:b3:b5:bb:47:80:fc:30:d9:a5:1f:9e:52:\n    18:b5:7a:aa:b7:d6:d7:4a:b6:f2:c0:9e:04:33:f3:\n    af:4a:bd:ba:4b:54:f1:ba:1f:2d:a7:97:c2:f6:d9:\n    e0:4e:66:f5:ca:99:e5:52:73:ad:9e:50:35:24:af:\n    fd:a1\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ACME Signing CA,OU=ACME CA,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => 'E7:36:F6:3A:B4:1E:50:3E:B0:C7:A9:D7:D5:9A:E2:AA:80:A6:0F:BC',
            },
        ),
        orphan => OpenXPKI::Test::CertHelper::PEM->new(
            label => "Orphan cert with unknown issuer",
            database => {
                authority_key_identifier => 'AA:06:FF:AE:29:6B:C0:E2:A3:D1:64:D6:25:25:45:95:B4:2A:BE:8F',
                cert_key => '2',
                data => "-----BEGIN CERTIFICATE-----\nMIIDejCCAmKgAwIBAgIBAjANBgkqhkiG9w0BAQsFADBaMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGjAYBgNVBAMMEUFDTUUtMyBTaWduaW5nIENBMCAXDTE3MDIxNjE3MzcxNloYDzIx\nMTcwMTIzMTczNzE2WjBWMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZImiZPy\nLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxFjAUBgNVBAMMDUFDTUUtMyBD\nbGllbnQwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDGZegxNEy+cYf9\nYtMzjF96mUv2t6OpfWMlbGWvvzjpDegGBgL1a9fB1UWK+0UTELOzeAMjlR62+Mzk\nBdPZhHe7w1MtP3hAFaUTA99RN8Rdguabffe94wJ/Q6pwM7dyncqMK8NiNilcUwq/\n5osKDVLr59c1TCitfqASShJALD0zxrecBGnMTn4e0QnjEAy6gtFDKDO1VEaZXbGh\nYXfomwniOFPkUqsjqqssG1a5UrUVNqk01KH8CgxtB7O5+gZpcVTXhGcsHS/jWcCm\nvTkmKqXZWNLTfTcfcS32bXdbghIDC7gC1fTRUyNFFIjiiDqmjsOZIiX2MbJS0fg4\nREnF1fqzAgMBAAGjTTBLMAkGA1UdEwQCMAAwHQYDVR0OBBYEFDJxmLK7HBuQcP1M\nh76eeqJm6fz2MB8GA1UdIwQYMBaAFKoG/64pa8Dio9Fk1iUlRZW0Kr6PMA0GCSqG\nSIb3DQEBCwUAA4IBAQCfF54YSziI0AW1ORFm3ziJsLz0HL7M3Xc4rMFQzk25chuL\ny095ste87qu1Nfw4jloP8sT3P5XsU1AV3ip/5shzewHsKP7fQSnygx/MyempCH/V\nGN0cz6RvQjVJ10CgZfAjvOBaqK5DBTv5zPq4/SkyQtC1dnezS+TheJKSAZv7CYld\nPksfJ3Xa7T9oMDyp69aw119SVNKxgsRjpJyYkg4aYlf77ZtnPu/3TYkVYvrA/+7F\nb4yOqRn3O7dbDnCcgpbZUq4Cfls3mLVI3wLzbhC1DvNzhHAtkIVZ3YucU2AMhYLo\n5M5DoXH9sC7ZoNVwDpk/Ej0M8NSuWKxr22kzCuco\n-----END CERTIFICATE-----\n",
                identifier => 'eB9CmYm6TKzk6ZtR5pTpXh1Exjc',
                issuer_dn => 'CN=ACME-3 Signing CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => '',
                loa => undef,
                notafter => '4294967295',  # 2106-02-07T06:28:15
                notbefore => '1487266636', # 2017-02-16T17:37:16
                pki_realm => 'acme-orphan',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:c6:65:e8:31:34:4c:be:71:87:fd:62:d3:33:8c:\n    5f:7a:99:4b:f6:b7:a3:a9:7d:63:25:6c:65:af:bf:\n    38:e9:0d:e8:06:06:02:f5:6b:d7:c1:d5:45:8a:fb:\n    45:13:10:b3:b3:78:03:23:95:1e:b6:f8:cc:e4:05:\n    d3:d9:84:77:bb:c3:53:2d:3f:78:40:15:a5:13:03:\n    df:51:37:c4:5d:82:e6:9b:7d:f7:bd:e3:02:7f:43:\n    aa:70:33:b7:72:9d:ca:8c:2b:c3:62:36:29:5c:53:\n    0a:bf:e6:8b:0a:0d:52:eb:e7:d7:35:4c:28:ad:7e:\n    a0:12:4a:12:40:2c:3d:33:c6:b7:9c:04:69:cc:4e:\n    7e:1e:d1:09:e3:10:0c:ba:82:d1:43:28:33:b5:54:\n    46:99:5d:b1:a1:61:77:e8:9b:09:e2:38:53:e4:52:\n    ab:23:aa:ab:2c:1b:56:b9:52:b5:15:36:a9:34:d4:\n    a1:fc:0a:0c:6d:07:b3:b9:fa:06:69:71:54:d7:84:\n    67:2c:1d:2f:e3:59:c0:a6:bd:39:26:2a:a5:d9:58:\n    d2:d3:7d:37:1f:71:2d:f6:6d:77:5b:82:12:03:0b:\n    b8:02:d5:f4:d1:53:23:45:14:88:e2:88:3a:a6:8e:\n    c3:99:22:25:f6:31:b2:52:d1:f8:38:44:49:c5:d5:\n    fa:b3\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ACME-3 Client,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '32:71:98:B2:BB:1C:1B:90:70:FD:4C:87:BE:9E:7A:A2:66:E9:FC:F6',
            },
        ),
    };
}

__PACKAGE__->meta->make_immutable;
