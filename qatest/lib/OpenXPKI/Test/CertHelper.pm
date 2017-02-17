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
    return "-----BEGIN PKCS7-----\nMIIK1AYJKoZIhvcNAQcCoIIKxTCCCsECAQExADALBgkqhkiG9w0BBwGgggqnMIID\nkzCCAnugAwIBAgIJAIyxPiRRNB9XMA0GCSqGSIb3DQEBCwUAMFcxEzARBgoJkiaJ\nk/IsZAEZFgNPUkcxGDAWBgoJkiaJk/IsZAEZFghPcGVuWFBLSTENMAsGA1UECwwE\nQUNNRTEXMBUGA1UEAwwOQUNNRS0xIFJvb3QgQ0EwIBcNMTcwMjE2MTY1ODQyWhgP\nMjExNzAxMjMxNjU4NDJaMFcxEzARBgoJkiaJk/IsZAEZFgNPUkcxGDAWBgoJkiaJ\nk/IsZAEZFghPcGVuWFBLSTENMAsGA1UECwwEQUNNRTEXMBUGA1UEAwwOQUNNRS0x\nIFJvb3QgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDBqJBOGHI3\nxMpwZ96As29rblcGdzlYY17cvg4AVcznfH0clxiFBHug3kcaqjyZum7MoWjH+u3P\n2s+xc1c/AEvWEsiCWmZQD3vFRCBzYD/H4hXWID0M9nEkh4jAiDmN4xkgCgm1OyCu\n4IiKK1mOoKLem2qdm6FXRJZfRGaklUtXbnu0WbQxkeDCgXERj3o2ZoKzU/ZPzuhy\niT8dQEDDFqBUK/0uc1ZCktcwd++N9fCzMmzFF6n5czRoNYqD32vLEMj0fwlJnovO\nPhO90vjzBTUTxqWUetCKZ8n1MOoeOlbkdDwy6nh5Df0D/UfNY3Xvx1xZL2Am08iQ\ncfCwTJXBY66JAgMBAAGjYDBeMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFC+x\nzMS5nhwc7IpRO7roGRMVvti/MB8GA1UdIwQYMBaAFC+xzMS5nhwc7IpRO7roGRMV\nvti/MAsGA1UdDwQEAwIBBjANBgkqhkiG9w0BAQsFAAOCAQEAqdTxzJdI8ed/hHU1\nok0ZnIKmRRH0gdRlYpn35mAlAjJHnyb/SZMWtV6mhzHfD18IFT7phI4Ykly1k482\nrH8inf6X08ztDh2bc528mXf32XyAa0Fo8eRXeuaYBDY/NoKS/d/YrRJfjvYAsZHn\nMq5+p6BYeID9P9yz+DiLJVT24M6+SRCiZotHvN+01sy/zVadCB0sZUsQJr+yhvY4\nlG516j5AhZ815k9kNQX0fDvwcPffvLRDx+ireNkvBbIT1JwpK0a7T08n8NrTFJx0\nsBlPlbv7FD5Wi4Vob2LcGk4/jnRxyGMrRBUF6bUCnq1TYqUWQZlCvz5CfLIrIoEj\nHNtZXTCCA44wggJ2oAMCAQICAQEwDQYJKoZIhvcNAQELBQAwVzETMBEGCgmSJomT\n8ixkARkWA09SRzEYMBYGCgmSJomT8ixkARkWCE9wZW5YUEtJMQ0wCwYDVQQLDARB\nQ01FMRcwFQYDVQQDDA5BQ01FLTEgUm9vdCBDQTAgFw0xNzAyMTYxNjU4NDJaGA8y\nMTE3MDEyMzE2NTg0MlowWjETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmSJomT\n8ixkARkWCE9wZW5YUEtJMQ0wCwYDVQQLDARBQ01FMRowGAYDVQQDDBFBQ01FLTEg\nU2lnbmluZyBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALqCuxYE\nC723+GOdc8NFAlErywnsKp2MkVuNDW28oXHGlOJcxhiX4R8+rQo5rifFeK7LPALm\nAlQHOuMaDEmkHgvlF6AHqUhT8KjhmDYP0QuO8jJcJhKksXyOKaDAb1dC9l1mP7ex\n1YQzY/OvHgv/aG9vkNYxbe+UfEnPfkwDPLYb9DICwIqnaVbbojYRpBeIJ0hvRKRp\nMxtrjisUfr3koUctDF/1NgmNXIA1/dH2uJpZ3CUtwGD76BYnR4/gCTWVmOsOJY0T\nOQZT+qWY/xEuvLC+xXGXPIfAbTo4p65IMvdCghuGag9F3PDTdLT0lFfnmr7+/ErK\n1fBxjNUDUSm+ZyMCAwEAAaNgMF4wDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU\n9ETfJA9cTw4j11+ZMQcXXhkhu3kwHwYDVR0jBBgwFoAUL7HMxLmeHBzsilE7uugZ\nExW+2L8wCwYDVR0PBAQDAgEGMA0GCSqGSIb3DQEBCwUAA4IBAQAQJiCBr7d+A1Fh\nRBzzrsPmuCgF645AQFQllly/HhUENRetYuaKULwjsN1TxbQciEhcQV93SOyYcnT2\nyCSb0fHLn6oo3d4SJvYMWvWHunwPOMTs/Oebe54jWiWOeZMQBp8QtwrKsMdKInI2\n8/eK6Q7/ToLWR1ksEf64862IQhfevwJJFUFYQ8FoxlSzA3FHpnDOCDLD7tIJfKpZ\n/F7+2+iK1nkc+Kxb8EjAy0BBNmEmYxXFPfVgPiQfjZ5gCuaCESE6SWzZtPMqEGHt\nt0PGoPQXk/9p4AIC8Ge4xFRVA++zHeRyiK9jXnMX4V8S5wuap04kSmlba/0GM10k\nQpEoXjpqMIIDejCCAmKgAwIBAgIBAjANBgkqhkiG9w0BAQsFADBaMRMwEQYKCZIm\niZPyLGQBGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsM\nBEFDTUUxGjAYBgNVBAMMEUFDTUUtMSBTaWduaW5nIENBMCAXDTE3MDIxNjE2NTg0\nMloYDzIxMTcwMTIzMTY1ODQyWjBWMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYK\nCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxFjAUBgNVBAMMDUFD\nTUUtMSBDbGllbnQwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDf8zUP\nAysGj3gHVBL2JFREjzS7sCQ6sI44fxCkePQz7mWhMbfJCrtuU2saLcsNMBbVYnDT\nstWbDJdlDdxw1XPJYxZulf/BGiV0taD7HcCV9Fo9emoA1Oi3qAwTAh24L/DUAI8o\nT5jubodOqDzvspIhXnFV3m68+0G47XJCFS7Dp4DRcf/S2DK6Jf/JWiCCFtrWWusK\n//QxPSkcvd6OqHKUkp37p9qvfS6l72TMPfjDxkm8hJt1RH2EgoS5JbXP24AatlyY\n83kY0KF1jKJGrjRhyoKCWTUVnuqIz1Ki3W2S4toRL/rYzO8aaO1StRvpyxrkfI9t\nnqQ7fSYySMJ0sU/lAgMBAAGjTTBLMAkGA1UdEwQCMAAwHQYDVR0OBBYEFIkTF/rx\nFBuMBB+laRY/ulgRXRg2MB8GA1UdIwQYMBaAFPRE3yQPXE8OI9dfmTEHF14ZIbt5\nMA0GCSqGSIb3DQEBCwUAA4IBAQBvXvvJZoAcH659yi+V2lgRGo3jpkyn+qShtg+x\nJUTMisZ6B893yg10XXvPmAh2ccbGLZdlGmAG6qtOTCB7v/rDq0ZSktgj7MvaBk4b\nYVVeDgGaXr7P9NpWN/KN4jZnsbdhKfQUUBNx15peOB890QxQRyhdPe0NTt6Lsj59\nL77mS13W0KPHKNlozPTAjc+3taIoX6maHH4efWeXZ1O593EMyProhidr4OLg4WS3\naHNgdyj2B2oQRekpZjh1jLI1xOSJkmhjl20TpI3icwAUKoef2x5vouZMdBRfc4NZ\nmbtvfJWQMgt5gguh6rZSJozLLNYIF1q3nwmvHAjZM5tlrFH+oQAxAA==\n-----END PKCS7-----\n";
}

# Test certificate data
sub _build_certs {
    return {
        acme_root => OpenXPKI::Test::CertHelper::PEM->new(
            label => "ACME Root CA",
            db => {
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
            db => {
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
            db => {
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
            db => {
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
            db => {
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
            db => {
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
            db => {
                authority_key_identifier => '0B:42:5E:FD:D9:FA:B7:BD:70:9D:A9:9C:32:FC:48:1A:D5:DA:A9:2B',
                cert_key => '10610044628722553795',
                data => "-----BEGIN CERTIFICATE-----\nMIIDkTCCAnmgAwIBAgIJAJM+c2AaDJPDMA0GCSqGSIb3DQEBCwUAMFcxEzARBgoJ\nkiaJk/IsZAEZFgNPUkcxGDAWBgoJkiaJk/IsZAEZFghPcGVuWFBLSTENMAsGA1UE\nCwwEQUNNRTEXMBUGA1UEAwwOQUNNRS00IFJvb3QgQ0EwHhcNMTAwMjE3MTYwNzE0\nWhcNMTEwMjE3MTYwNzE0WjBXMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZIm\niZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxFzAVBgNVBAMMDkFDTUUt\nNCBSb290IENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2u3lKlo3\n9LlcWR6j0YqD3kq//KMn6ESERYefmRiCcE7VthoqnSvie7IWiqdhbX6Jwi8kYDG+\nW6gJ6QggFIe5tspvh8oAqkltaLg6yvqp0HZRADtiF2WbsUvC5R5U0wJ5ZJIYA186\n88lCt9FztgiiRZ8bL+zA3v9ON+24uH/eLJLh1Z7YJaS76fcOyNLfwiJGZ1b4XdLx\nQtkmb3vMQLVSAMsOem2/+FFNpYaIwWqoR8zBhnXWjGXi3FG0gHZ/512Pvw27uo4u\nRnj3rKv0S1BBxbpnAJgN140ePKwfki6xwZUNS5PKd/lRmISLOQXVa+Gicwa/LNIv\nFm5kzxDTkYkvmwIDAQABo2AwXjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBQL\nQl792fq3vXCdqZwy/Ega1dqpKzAfBgNVHSMEGDAWgBQLQl792fq3vXCdqZwy/Ega\n1dqpKzALBgNVHQ8EBAMCAQYwDQYJKoZIhvcNAQELBQADggEBADTIt+4PzJcbxnFv\nTfTeeWjy7ttUMLNtT+jbHrSPfhgXk2sEA2g11f+giahMFysLVBZ9w9+Z+cZvDS+N\n8/yz8KoCtbJIPusrgfwb67wC+XMGtnaRPnOUZj/bgv2FD7fFSph/S3MUsXcFJomv\nizkqURiar38bSFzbPSs1eyVysltCcWqt6FmNiFZzBk54Jkh9sHipJcEG5dlEichJ\ne+DMd8QChCQHM8XDnY44emMu1EqjEZxZROzd88nJurJhvVVBMqHvFh55SHv53UZs\neJPDHVsFl/KzV66YFD8+AkYr8qpo98aC+XEXWEpen3K57XDxTyUvaN2zRGyrCTm6\n0GHrWWU=\n-----END CERTIFICATE-----\n",
                identifier => 'pp2WoAH3leE0sHaamHzXA61ASWA',
                issuer_dn => 'CN=ACME-4 Root CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'pp2WoAH3leE0sHaamHzXA61ASWA',
                loa => undef,
                notafter => '1297958834',  # 2011-02-17T16:07:14
                notbefore => '1266422834', # 2010-02-17T16:07:14
                pki_realm => 'acme-expired',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:da:ed:e5:2a:5a:37:f4:b9:5c:59:1e:a3:d1:8a:\n    83:de:4a:bf:fc:a3:27:e8:44:84:45:87:9f:99:18:\n    82:70:4e:d5:b6:1a:2a:9d:2b:e2:7b:b2:16:8a:a7:\n    61:6d:7e:89:c2:2f:24:60:31:be:5b:a8:09:e9:08:\n    20:14:87:b9:b6:ca:6f:87:ca:00:aa:49:6d:68:b8:\n    3a:ca:fa:a9:d0:76:51:00:3b:62:17:65:9b:b1:4b:\n    c2:e5:1e:54:d3:02:79:64:92:18:03:5f:3a:f3:c9:\n    42:b7:d1:73:b6:08:a2:45:9f:1b:2f:ec:c0:de:ff:\n    4e:37:ed:b8:b8:7f:de:2c:92:e1:d5:9e:d8:25:a4:\n    bb:e9:f7:0e:c8:d2:df:c2:22:46:67:56:f8:5d:d2:\n    f1:42:d9:26:6f:7b:cc:40:b5:52:00:cb:0e:7a:6d:\n    bf:f8:51:4d:a5:86:88:c1:6a:a8:47:cc:c1:86:75:\n    d6:8c:65:e2:dc:51:b4:80:76:7f:e7:5d:8f:bf:0d:\n    bb:ba:8e:2e:46:78:f7:ac:ab:f4:4b:50:41:c5:ba:\n    67:00:98:0d:d7:8d:1e:3c:ac:1f:92:2e:b1:c1:95:\n    0d:4b:93:ca:77:f9:51:98:84:8b:39:05:d5:6b:e1:\n    a2:73:06:bf:2c:d2:2f:16:6e:64:cf:10:d3:91:89:\n    2f:9b\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ACME-4 Root CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '0B:42:5E:FD:D9:FA:B7:BD:70:9D:A9:9C:32:FC:48:1A:D5:DA:A9:2B',
            },
        ),
        expired_signer => OpenXPKI::Test::CertHelper::PEM->new(
            label => "Expired Signing CA cert",
            db => {
                authority_key_identifier => '0B:42:5E:FD:D9:FA:B7:BD:70:9D:A9:9C:32:FC:48:1A:D5:DA:A9:2B',
                cert_key => '1',
                data => "-----BEGIN CERTIFICATE-----\nMIIDjDCCAnSgAwIBAgIBATANBgkqhkiG9w0BAQsFADBXMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nFzAVBgNVBAMMDkFDTUUtNCBSb290IENBMB4XDTEwMDIxNzE2MDcxNFoXDTExMDIx\nNzE2MDcxNFowWjETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmSJomT8ixkARkW\nCE9wZW5YUEtJMQ0wCwYDVQQLDARBQ01FMRowGAYDVQQDDBFBQ01FLTQgU2lnbmlu\nZyBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALiov1MAxJv60PV1\nr9Q+o94773qaOHa40kFr6+rx5gCDrr82YsxGfPXEji7Er5ubsArhdLyOTXxzlRxZ\nBo9txw03F+fA3u2Bpa5XVt3NnFdk/wLlxn+QdLKdoEbWMS2msWjS274lwRGSw67E\nt4IgeZBTj7+muKxS/zjc2b4RvKydK8xNuxtlDYPLU/w8veV+oUK7v0W7w5Ecgyxj\n6bDFmkdunwWodsLOzXOQ/FPyuc6Nqa3OoimlUX9B9dMmndD5eWqO6efCWKb/0CFq\nr4Ez9uE6wziKH55SK620Juw8ayIfVPPHM8a98sX3P55YAo2Uz5Uccxi4yHNk0sbN\nLpuUzEUCAwEAAaNgMF4wDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU1VO8GT9y\n4gCPGIS7GooLxFzchqcwHwYDVR0jBBgwFoAUC0Je/dn6t71wnamcMvxIGtXaqSsw\nCwYDVR0PBAQDAgEGMA0GCSqGSIb3DQEBCwUAA4IBAQDBsmHgrGqUyo103fPQBZj7\nwIMMw/NRN/ZlBK0Ur4cRfmxM/Ii5wFOOG3rBN3OLYLcpYZqdlkSvqTMb+GarTBFS\nrED8/wKF8VKbnzoYVwwf6eeqYtD1RRI0BDrn4gcUA2cDJgLVpMOtMBc0bj9ktydS\nOUGzfJb77g60XlllQ8EpsCIMYNFf7vWmeS0YGfu2p1JcMMqq6lm9mCm1C7AT4SK1\n9ox8ECLhboWzcchZqZ1b8P7sJMlNM8gargo020FAJLPwSySycwt1nTTEOo5qlR8I\nrG3jdZeywO6MdLOoRqsI56EkE5RpZDNUhTckT/o/9qNOBD21+th1tfTxCqs+cSTB\n-----END CERTIFICATE-----\n",
                identifier => 'WdsEj95LKDzZV6rWvy12Up5GEOY',
                issuer_dn => 'CN=ACME-4 Root CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'pp2WoAH3leE0sHaamHzXA61ASWA',
                loa => undef,
                notafter => '1297958834',  # 2011-02-17T16:07:14
                notbefore => '1266422834', # 2010-02-17T16:07:14
                pki_realm => 'acme-expired',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:b8:a8:bf:53:00:c4:9b:fa:d0:f5:75:af:d4:3e:\n    a3:de:3b:ef:7a:9a:38:76:b8:d2:41:6b:eb:ea:f1:\n    e6:00:83:ae:bf:36:62:cc:46:7c:f5:c4:8e:2e:c4:\n    af:9b:9b:b0:0a:e1:74:bc:8e:4d:7c:73:95:1c:59:\n    06:8f:6d:c7:0d:37:17:e7:c0:de:ed:81:a5:ae:57:\n    56:dd:cd:9c:57:64:ff:02:e5:c6:7f:90:74:b2:9d:\n    a0:46:d6:31:2d:a6:b1:68:d2:db:be:25:c1:11:92:\n    c3:ae:c4:b7:82:20:79:90:53:8f:bf:a6:b8:ac:52:\n    ff:38:dc:d9:be:11:bc:ac:9d:2b:cc:4d:bb:1b:65:\n    0d:83:cb:53:fc:3c:bd:e5:7e:a1:42:bb:bf:45:bb:\n    c3:91:1c:83:2c:63:e9:b0:c5:9a:47:6e:9f:05:a8:\n    76:c2:ce:cd:73:90:fc:53:f2:b9:ce:8d:a9:ad:ce:\n    a2:29:a5:51:7f:41:f5:d3:26:9d:d0:f9:79:6a:8e:\n    e9:e7:c2:58:a6:ff:d0:21:6a:af:81:33:f6:e1:3a:\n    c3:38:8a:1f:9e:52:2b:ad:b4:26:ec:3c:6b:22:1f:\n    54:f3:c7:33:c6:bd:f2:c5:f7:3f:9e:58:02:8d:94:\n    cf:95:1c:73:18:b8:c8:73:64:d2:c6:cd:2e:9b:94:\n    cc:45\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ACME-4 Signing CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => 'D5:53:BC:19:3F:72:E2:00:8F:18:84:BB:1A:8A:0B:C4:5C:DC:86:A7',
            }
        ),
        expired_client => OpenXPKI::Test::CertHelper::PEM->new(
            label => "Expired Client cert",
            db => {
                authority_key_identifier => 'D5:53:BC:19:3F:72:E2:00:8F:18:84:BB:1A:8A:0B:C4:5C:DC:86:A7',
                cert_key => '2',
                data => "-----BEGIN CERTIFICATE-----\nMIIDeDCCAmCgAwIBAgIBAjANBgkqhkiG9w0BAQsFADBaMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGjAYBgNVBAMMEUFDTUUtNCBTaWduaW5nIENBMB4XDTEwMDIxNzE2MDcxNFoXDTEx\nMDIxNzE2MDcxNFowVjETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmSJomT8ixk\nARkWCE9wZW5YUEtJMQ0wCwYDVQQLDARBQ01FMRYwFAYDVQQDDA1BQ01FLTQgQ2xp\nZW50MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtPZuUycYeGTn01K8\nQsL/76RkHJvxAKESQoi1/wRdPFx8N0LlMkxx+10qZbX46Pupf+vwrJ96DhfyjVrn\nqle66Yc1O6NV7LGN6kLOkXzl9zqHTh12PNOi5urZu6TdmqlP7Qa1cadrAypMYyIm\n4wWgt1+dmTXDRIsBI3gpEh2VfdRb5zFCJE0E5JlgXMwkfmYDQ2ykfVSUbCeHUUlF\n7jKhvHbVP9NNA8pnzsOLqO6pTJ+uNnw8N1vfKBfIxbX2YI132NK2S5SOoUuQoOXm\npcoTeCKoOq0Qt8oX9ENIxFWWOxoNPMerRn7tzfacGQ4/fR0VLoxln8hWGivyx3MS\nx+eEDQIDAQABo00wSzAJBgNVHRMEAjAAMB0GA1UdDgQWBBT+EZDbmBKocso0yrkE\n7vtuChcCSDAfBgNVHSMEGDAWgBTVU7wZP3LiAI8YhLsaigvEXNyGpzANBgkqhkiG\n9w0BAQsFAAOCAQEAoPBwdAQq4/db7VjYpdSF4cpRlWx9m/maubHMjuH4HR98OFMd\ny1NOdvYnSovsHLUOYWIHK3L+HWqWdAm48iRo4mfTwCE/olx2aMC39qjIex0kTFCL\n3lCK4i/CLveMt9gYMrb0McZadkxA+6zAyzUwFfbLTBakPG66X0sF6UNX/5CDlRQF\nj4udhaXiKz4qNP6q0tEUtKjj2rYYjgqEyjlD/++GbjJXa8zKZZkkZlum5uj5fcgi\nevewJ/2NnhWuUHZuio8ceQ5964XYTX+hUICBLMquHKaAvfp+YmMP8CEievG6D+YS\nysLxpRXg8AGQDerL6SKshBsfQiv+c0+auC22KA==\n-----END CERTIFICATE-----\n",
                identifier => '2KEPBWHVallRrfapK7GuDq3ygSQ',
                issuer_dn => 'CN=ACME-4 Signing CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'WdsEj95LKDzZV6rWvy12Up5GEOY',
                loa => undef,
                notafter => '1297958834',  # 2011-02-17T16:07:14
                notbefore => '1266422834', # 2010-02-17T16:07:14
                pki_realm => 'acme-expired',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:b4:f6:6e:53:27:18:78:64:e7:d3:52:bc:42:c2:\n    ff:ef:a4:64:1c:9b:f1:00:a1:12:42:88:b5:ff:04:\n    5d:3c:5c:7c:37:42:e5:32:4c:71:fb:5d:2a:65:b5:\n    f8:e8:fb:a9:7f:eb:f0:ac:9f:7a:0e:17:f2:8d:5a:\n    e7:aa:57:ba:e9:87:35:3b:a3:55:ec:b1:8d:ea:42:\n    ce:91:7c:e5:f7:3a:87:4e:1d:76:3c:d3:a2:e6:ea:\n    d9:bb:a4:dd:9a:a9:4f:ed:06:b5:71:a7:6b:03:2a:\n    4c:63:22:26:e3:05:a0:b7:5f:9d:99:35:c3:44:8b:\n    01:23:78:29:12:1d:95:7d:d4:5b:e7:31:42:24:4d:\n    04:e4:99:60:5c:cc:24:7e:66:03:43:6c:a4:7d:54:\n    94:6c:27:87:51:49:45:ee:32:a1:bc:76:d5:3f:d3:\n    4d:03:ca:67:ce:c3:8b:a8:ee:a9:4c:9f:ae:36:7c:\n    3c:37:5b:df:28:17:c8:c5:b5:f6:60:8d:77:d8:d2:\n    b6:4b:94:8e:a1:4b:90:a0:e5:e6:a5:ca:13:78:22:\n    a8:3a:ad:10:b7:ca:17:f4:43:48:c4:55:96:3b:1a:\n    0d:3c:c7:ab:46:7e:ed:cd:f6:9c:19:0e:3f:7d:1d:\n    15:2e:8c:65:9f:c8:56:1a:2b:f2:c7:73:12:c7:e7:\n    84:0d\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ACME-4 Client,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => 'FE:11:90:DB:98:12:A8:72:CA:34:CA:B9:04:EE:FB:6E:0A:17:02:48',
            }
        ),
        orphan => OpenXPKI::Test::CertHelper::PEM->new(
            label => "Orphan cert with unknown issuer",
            db => {
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
