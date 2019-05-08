package OpenXPKI::Test::CertHelper::Database;
use Moose;
use utf8;

=head1 NAME

OpenXPKI::Test::CertHelper::Database - Test helper that contains raw
certificate data to be inserted into the database.

=head1 DESCRIPTION

    # instance of OpenXPKI::Test::CertHelper::Database::Cert
    my $cert = $db->cert("alpha-alice-1");

    print $cert->id, "\n";     # certificate identifier
    print $cert->data, "\n";   # PEM encoded certificate

The following predefined test certificates are available:

=over

=item * B<alpha> PKI realm

=over 1

=item * set 1 (expired certificates)

    $db->cert("alpha-root-1")      # self signed Root Cert
    $db->cert("alpha-signer-1")    # Signing CA   (signed by Root Cert)
    $db->cert("alpha-alice-1")     # client Alice (signed by Signing CA)
    $db->cert("alpha-bob-1")       # client Bob   (signed by Signing CA)
    $db->cert("alpha-scep-1")      # SCEP service (signed by Root Cert)
    $db->cert("alpha-datavault-1")     # self signed DataVault Cert

=item * set 2 (valid till year 2100)

    $db->cert("alpha-root-2")      # self signed Root Cert
    ...

=item * set 3 (valid from 2100 till 2105)

    $db->cert("alpha-root-3")      # self signed Root Cert
    ...

=item * set 4 (valid till year 2100)

    ...
    $db->cert("alpha_alice_4")     # client Alice: a revoked certificate
    $db->cert("alpha_bob_4")       # client Bob    a revoked certificate
    $db->crl("alpha-4")            # PEM encoded Certificate Revocation List
    ...

=back

=item * B<beta> PKI realm (valid till year 2105)

    $db->cert("beta-root-1")      # self signed Root Cert
    $db->cert("beta-signer-1")    # Signing CA   (signed by Root Cert)
    $db->cert("beta-alice-1")     # client Alice (signed by Signing CA)
    $db->cert("beta-bob-1")       # client Bob   (signed by Signing CA)
    $db->cert("beta-scep-1")      # SCEP service (signed by Root Cert)
    $db->cert("beta-datavault-1")     # self signed DataVault Cert

=item * B<gamma> PKI realm (valid till year 2105)

    $db->cert("gamma-bob-1")       # "Orphan" client cert without known Signing or Root CA

=back

=cut

# Project modules
use OpenXPKI::Test::CertHelper::Database::Cert;

################################################################################
# Other attributes
has _certs_by_alias => (
    is => 'rw',
    isa => 'HashRef[OpenXPKI::Test::CertHelper::Database::Cert]',
    traits => ['Hash'],
    lazy => 1,
    builder => '_build_certs',
    handles => {
        all_certs => 'values',
        all_cert_names => 'keys',
    },
);

has _crls => (
    is => 'rw',
    isa => 'HashRef[Str]',
    lazy => 1,
    builder => '_build_crl',
);

=head1 METHODS

=head2 all_certs

Returns a list with all cert objects of type L<OpenXPKI::Test::CertHelper::Database::Cert> handled by this class.

=head2 all_cert_names

Returns a list with the internal short names of all test certificates
handled by this class.

=cut



=head2 pkcs7

Returns a HashRef: C<certificate alias => PKCS7 container>.

The container consists of the certificate chain for each client: Root, Signing
CA and Client certificate.

=cut
has pkcs7 => (
    is => 'rw',
    isa => 'HashRef[Str]',
    lazy => 1,
    builder => '_build_pkcs7',
);

################################################################################
# Methods

=head2 cert

Returns an instance of L<OpenXPKI::Test::CertHelper::Database::Cert> with the
requested test certificate data.

    print $db->cert("beta-alice-1")->id, "\n";

=cut
sub cert {
    my ($self, $certname) =@_;
    return $self->_certs_by_alias->{$certname} || die "A test certificate named '$certname' does not exist.";
}

=head2 crl

Returns the PEM encoded CRL for the given realm / generation.

    print $db->crl("alpha-4"), "\n";

=cut
sub crl {
    my ($self, $realm_gen) =@_;
    return $self->_crls->{$realm_gen} || die "A CRL named '$realm_gen' does not exist.";
}

=head2 all_cert_ids

Returns an ArrayRef with the internal "identifier" of all test certificates
handled by this class.

=cut
sub all_cert_ids {
    my $self = shift;
    return [ map { $_->id } $self->all_certs ];
}

=head2 cert_names_where

Returns a list with the internal short names of all test certificates
where the given attribute has the given value.

=cut
sub cert_names_where {
    my ($self, $attribute, $value) = @_;
    my @result = grep { $self->cert($_)->db->{$attribute} eq $value } $self->all_cert_names;
    die "No test certificates found where $attribute == '$value'" unless scalar(@result);
    return @result;
}

=head2 cert_names_by_realm_gen

Returns a list with the internal short names of all test certificates
in the given PKI realm and generation.

=cut
sub cert_names_by_realm_gen {
    my ($self, $realm, $gen) = @_;
    my @result = grep {
        $self->cert($_)->db->{pki_realm} eq $realm
        and $self->cert($_)->db_alias->{alias} =~ / - $gen $ /msx
    } $self->all_cert_names;
    die "No test certificates found for realm '$realm', generation $gen" unless scalar(@result);
    return @result;
}

#
# Methods below were copied from autogenerated code by tools/testdata/_pem-to-certhelper.pl
#
sub _build_pkcs7 {
    return {
        'alpha-alice-1' => "-----BEGIN PKCS7-----\n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\nMQA=\n-----END PKCS7-----",
        'alpha-alice-2' => "-----BEGIN PKCS7-----\nMIIK3gYJKoZIhvcNAQcCoIIKzzCCCssCAQExADALBgkqhkiG9w0BBwGgggqxMIID\njzCCAnegAwIBAgIBCDANBgkqhkiG9w0BAQsFADBYMRMwEQYKCZImiZPyLGQBGRYD\nT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxGDAW\nBgNVBAMMD0FMUEhBIFJvb3QgQ0EgMjAiGA8yMDA3MDEwMTAwMDAwMFoYDzIxMDAw\nMTMxMjM1OTU5WjBYMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZImiZPyLGQB\nGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxGDAWBgNVBAMMD0FMUEhBIFJvb3Qg\nQ0EgMjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANziBj72oup2X3QN\nFhZEQW5aZqv/4Q0jp8bA6mdNYC0ZFVHyE3OP0E3myc7IJfGW1mJH2ojtJ1msgB0Z\n3DlAgec76kwo0Q36MLNmuB/DAN5+4P3wYhW3eCRgfLWcdzkYTRYxAL8O7XuKBVOP\nVt34CRnYct9pPojpLL/goi70bxQ153+ZgO3zJPdmT7vPMNU7pTBFRYUIpHRFjwo6\nqerCV2AvveXp4kjJe2AHvbL0JCN+pdm0lFG7WY0sQN2PLei+qplRWkM8eOjHrPMv\n/C0/Saqly37QapyIqq/7jvxz6jv0F0uBbc5tQmT4Oidl/KNnBZAdNpKx4xoB3swj\nYPMYPysCAwEAAaNgMF4wDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUjNW5hSaT\njfK6RnG/bYUrvV8tQZUwHwYDVR0jBBgwFoAUjNW5hSaTjfK6RnG/bYUrvV8tQZUw\nCwYDVR0PBAQDAgEGMA0GCSqGSIb3DQEBCwUAA4IBAQCoqYzWPbowgJxmR1MbIMhy\nyg7VdF44P8e8Sv2h+i2LaWBY6HwUVkDByqCEDysWfvH4RNzjNNiWQ10yoiFp59NQ\ncNjXC5GMZZYdLjB/+OkVUAT8KwV+GMeB9LTSju4yMxmvtjj+auVZmadADh1b7/at\nPtRSAH/O9CJTXupoceh/AXeYV9Vx2J7Y4cujHIH3H326QidnR9zeUyha8wqF1/nw\nFOwt5CFZ89PjyAl/D2g0IowNNHRGdm7oLvQAR8HDwFvlS+Qpc2PLYiqGG8eoK7jx\nPAQWCvdQU5b3xFYUehK35E58DTGA0wnKrAxeB47ZrZF11jc9xrMCGg2BLm8R+UwW\nMIIDkjCCAnqgAwIBAgIBCTANBgkqhkiG9w0BAQsFADBYMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGDAWBgNVBAMMD0FMUEhBIFJvb3QgQ0EgMjAiGA8yMDA3MDEwMTAwMDAwMFoYDzIx\nMDAwMTMxMjM1OTU5WjBbMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZImiZPy\nLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxGzAZBgNVBAMMEkFMUEhBIFNp\nZ25pbmcgQ0EgMjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMiovn8+\ndjhIOADUUtE7mgSXlYJoPjjRinGzCRtHy8YdM+uzgKXiyYODEpK8YpRROsuBpEPO\n6nkdilI6ONdz2IkwHHJSx9d8SPvW/pKSshBQ27wl5bHqihY32AdqdkUH8YFCCheD\nSBV9IfGRd4RVNITNEmXPIDN2LDHmNwRURbzEjM7rZwkIwJy3ksiW6PCXRmwCt7F+\nHAj8afn4niTyni3BU4SQGuszzoO6jzvrmTxIhZ6PGJ0uzxHyS3u61lkAEF2a+pnV\nVuUnVQ9QsWleVbaWIsxbcF9BRNMc1OaBnJKGlGzcqWRhJx6fzuyzcclJBgcsniTK\n5jl43BLhRAC4pikCAwEAAaNgMF4wDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU\nJZXjxZF4FwbGNrRijhBp41Y9bCwwHwYDVR0jBBgwFoAUjNW5hSaTjfK6RnG/bYUr\nvV8tQZUwCwYDVR0PBAQDAgEGMA0GCSqGSIb3DQEBCwUAA4IBAQCFX+bll/CC4hJe\nRMkmFWsq3UcvNkp84NROYsZejdub/tkn4C8YLi/elgIU360Wam8WpnY+qvNBMk86\nZoj6K3R8nmaHUdRFoRp8wqwKbCDgyb1QwXwsm7bDwg5DstOoL0Ol8OBasG5YSX+B\nLSF/3EpSHUUW5s9JXiAOMo382CmsZY+/J8yF/L+TqSs4CObXjzbrrTftj4El0Ih/\nlnJyKhkvhfI5YSInPwByg0m9mpOhd2gdk15WFM5D+RIGjb7QAuSY+mvZJ38rzU2y\nNDjL+w3olKW/wD1FI6yn0/QmJGHhCAblXQmF7yJsIeFQEWGm43tOqx9SVuzhxfdP\nGihYtVw3MIIDhDCCAmygAwIBAgIBCzANBgkqhkiG9w0BAQsFADBbMRMwEQYKCZIm\niZPyLGQBGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsM\nBEFDTUUxGzAZBgNVBAMMEkFMUEhBIFNpZ25pbmcgQ0EgMjAiGA8yMDA3MDEwMTAw\nMDAwMFoYDzIxMDAwMTMxMjM1OTU5WjBdMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgw\nFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxHTAbBgNVBAMM\nFEFMUEhBIENsaWVudCBBbGljZSAyMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB\nCgKCAQEAsVsAN84HFUBnXbrIn7im07Ry/qgCyfVbzKbTBOwr1XDP63xkEkgBVuuO\nVtDgBNrdkxf9wbYq3CAaYdOO9YwjxfysTOr8YpOQj4xJSTrsoG0d+YGTzcnR/+4t\nJHqva8hhXNIP3ysb68rpADXCJH+dlhbn7NTaG8wN+2uWJnUifeUjO6tCK8ZgqPsR\nlB2PfTxgWGjcdotNO3vQK2esXbuCKGIL3py67AYWFGy7FkTjCQ33d75WvL6aGrq9\nLg3MCEIT1F9Ihotyen6Ox8D4sWjxynRAZoou5+MjWItefMDENwfqVUKvVAix27vm\nZfOwcnLfwcvmMpADREilFhdigMBgYwIDAQABo00wSzAJBgNVHRMEAjAAMB0GA1Ud\nDgQWBBROMVcVPei89IY9+yCEt0kDJa+qVTAfBgNVHSMEGDAWgBQllePFkXgXBsY2\ntGKOEGnjVj1sLDANBgkqhkiG9w0BAQsFAAOCAQEAfb/hC3hzH4dAV74BIl3CLh9P\nuPGjlL3mgpkTrn9SogrDMtTaq6ewoFaqioBFVeLwwnflVpYnzG41tjlCXq3JGx8O\niw0pz6OmBv3Z6FzeA7/yY05l6XO82xRtl7BF6k0Akh6lkz0+Of2P/cUwmBid2PkW\nuwx9bIpb8pj32E9h2OmrAao+MWwfskHlER3JR144llHxbM0oDPUR9cAn9thq5am9\nXGqxMHdJ8xMcSX3dq6XYADel8zMpYWDoWbwq3pptVqnvy69BUoV7zcp8iYNoEHwr\nLG4mPUHhNntk2IV3UJZdjCm5ZhVnFs5ZLoI/d4+uzb3mEH0ziOsCvNJxTAihsKEA\nMQA=\n-----END PKCS7-----",
        'alpha-alice-3' => "-----BEGIN PKCS7-----\n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\nMQA=\n-----END PKCS7-----",
        'beta-alice-1' => "-----BEGIN PKCS7-----\n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\n-----END PKCS7-----",
    };
}
sub _build_crl {
    return {
        'alpha-2' => "-----BEGIN X509 CRL-----\nMIICFjCB/wIBATANBgkqhkiG9w0BAQsFADBbMRMwEQYKCZImiZPyLGQBGRYDT1JH\nMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxGzAZBgNV\nBAMMEkFMUEhBIFNpZ25pbmcgQ0EgMhcNMTkwNTA4MTcyNjUwWhgPMjA2OTA0MjUx\nNzI2NTBaMF4wOgIBDRcNMTkwNTA4MTcyNjUwWjAmMAoGA1UdFQQDCgEBMBgGA1Ud\nGAQRGA8yMDEwMDMwNDA3MDgzMFowIAIBDhcNMTkwNTA4MTcyNjUwWjAMMAoGA1Ud\nFQQDCgEFoA4wDDAKBgNVHRQEAwIBADANBgkqhkiG9w0BAQsFAAOCAQEAEE956aYS\niCDMN8xZrjWE1Is0MDtsL2vTTecJr24AJcL8pC04I6nZlRb9H4F1X5q2HMFclpou\n5TxT/JsKOmdVX8BApogBRC7q/z4GkS/h/sOTMjLQ5/VOLZW3kTS9rVlY7TLG5tC8\nDo2+1k+FrBUdDa1EEy7omeIa8g06EpT3zUhGBotYlo34cjSJSyXjfJ+1qZwDE6bQ\n+cE9bwr76rqT3pYdG9xhRLffwrePWplPknsgszKX4HkZocMFfFkAe0WPRU3tuSZN\nLiRXEd7OCzF8TjdQfQWD6OhBbqABMYwqw4tGEm1osF7gYFUkLMwsiZimhgCQ4Uyj\nHvdHqZe9aBXp7A==\n-----END X509 CRL-----",
    };
}
sub _build_certs {
    return {
        'alpha-alice-1' => OpenXPKI::Test::CertHelper::Database::Cert->new(
            label => 'ALPHA Client Alice 1',
            name => 'alpha-alice-1',
            db => {
                authority_key_identifier => '93:D3:15:2C:E6:94:C1:D1:39:A9:28:DC:2D:0B:F6:6D:E7:2F:DF:CB',
                cert_key => '5',
                data => "-----BEGIN CERTIFICATE-----\nMIIDhDCCAmygAwIBAgIBBTANBgkqhkiG9w0BAQsFADBbMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGzAZBgNVBAMMEkFMUEhBIFNpZ25pbmcgQ0EgMTAiGA8yMDA2MDEwMTAwMDAwMFoY\nDzIwMDcwMTMxMjM1OTU5WjBdMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZIm\niZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxHTAbBgNVBAMMFEFMUEhB\nIENsaWVudCBBbGljZSAxMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA\nqm4yt95wH2yjTOmlWZD1f9EfvJwgJyYAhlt5hddR0YOYxWYCcnq5aVv2QpPKFdaM\nbj9n92MVlI9z6e3sUBU1weNcpZJPq5tZjxvsdfjO7Rsyn3rLilTP29yd6ikWgYj8\nSYyTmS73b2+5x8x0KV657s/IBKFjlK0g+hZrJ2ZyWlcdUYJHX9kOo6CwCFzk4wCS\n49CPsDahoe2zCWmXB0Xz1OZx2SaGdsmfYp/Gs08bDP8iXFWCWScL4bmspDF61Elx\nVMXZ1G9dh9cm2LnuYaGuZ1ook9Jvd7ZpjyZ0ifz2O5xHhM/NYBVVonmG0cOJn6fF\nkdOwZ7HbAq4Zw1A+0HZ/BwIDAQABo00wSzAJBgNVHRMEAjAAMB0GA1UdDgQWBBQf\nCjAjn2DaRPlCMF1xxq97hoGRJjAfBgNVHSMEGDAWgBST0xUs5pTB0TmpKNwtC/Zt\n5y/fyzANBgkqhkiG9w0BAQsFAAOCAQEAAgyd2fJfWcp8cDUTTKGqjhkOMnAdrWRM\nmUPqUKMhV5Ly4YsUk7nu7ZyyOVBJMLqfdYdHjIr8cfT8bMZB7J+4yRkwYpeiNtvT\nAkAbp65fTfjZNrzPznkQcX02cBZHkImHCA2BLDc7bNayoZHWLMLwGTi7Ol+Cjivp\nHJl0puP4uj4TobHV5fi1r6tEPqI7RydU61BgbZlgPU/swqyX98bojQd3IM3Oq617\n1SNz6S7TMGaR90uDK9MoMDEvlzz8LrMEsgPCbmj0FEwfoOu+b+x7OiQp/CuPeXiz\nAJMaBGUJiO2B8Etl3M3IqG/hRqDTxteMnl5e5GFPz3XPUSXRLcWqsQ==\n-----END CERTIFICATE-----",
                hold_instruction_code => undef,
                identifier => 'p7nTwt4--excs0L0Yb99YUgahts',
                invalidity_time => undef,
                issuer_dn => 'CN=ALPHA Signing CA 1,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'UDFhlBTPFnXDz_tiXZ_FZ7MuKng',
                notafter => '1170287999', # 2007-01-31T23:59:59
                notbefore => '1136073600', # 2006-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:aa:6e:32:b7:de:70:1f:6c:a3:4c:e9:a5:59:90:\n    f5:7f:d1:1f:bc:9c:20:27:26:00:86:5b:79:85:d7:\n    51:d1:83:98:c5:66:02:72:7a:b9:69:5b:f6:42:93:\n    ca:15:d6:8c:6e:3f:67:f7:63:15:94:8f:73:e9:ed:\n    ec:50:15:35:c1:e3:5c:a5:92:4f:ab:9b:59:8f:1b:\n    ec:75:f8:ce:ed:1b:32:9f:7a:cb:8a:54:cf:db:dc:\n    9d:ea:29:16:81:88:fc:49:8c:93:99:2e:f7:6f:6f:\n    b9:c7:cc:74:29:5e:b9:ee:cf:c8:04:a1:63:94:ad:\n    20:fa:16:6b:27:66:72:5a:57:1d:51:82:47:5f:d9:\n    0e:a3:a0:b0:08:5c:e4:e3:00:92:e3:d0:8f:b0:36:\n    a1:a1:ed:b3:09:69:97:07:45:f3:d4:e6:71:d9:26:\n    86:76:c9:9f:62:9f:c6:b3:4f:1b:0c:ff:22:5c:55:\n    82:59:27:0b:e1:b9:ac:a4:31:7a:d4:49:71:54:c5:\n    d9:d4:6f:5d:87:d7:26:d8:b9:ee:61:a1:ae:67:5a:\n    28:93:d2:6f:77:b6:69:8f:26:74:89:fc:f6:3b:9c:\n    47:84:cf:cd:60:15:55:a2:79:86:d1:c3:89:9f:a7:\n    c5:91:d3:b0:67:b1:db:02:ae:19:c3:50:3e:d0:76:\n    7f:07\nExponent: 65537 (0x10001)\n",
                reason_code => undef,
                req_key => undef,
                revocation_time => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA Client Alice 1,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '1F:0A:30:23:9F:60:DA:44:F9:42:30:5D:71:C6:AF:7B:86:81:91:26',
            },
            db_alias => {
                alias => 'alpha-alice-1',
                generation => undef,
                group_id => undef,
            },
            private_key => "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFDjBABgkqhkiG9w0BBQ0wMzAbBgkqhkiG9w0BBQwwDgQIAdP0xCMz+9ICAggA\nMBQGCCqGSIb3DQMHBAh0ChHHICoU0ASCBMgm+FIo6MM2tiZ+YG4+QfbYqZKbQjlp\nCiIO/rEWOc+RuQ4Zzk+9xmx8f+LoQYSn9hzF7a5oVfB6WPlTXaw7wAsEmDmi1AIr\nVP4heq99do6vLSHyJhC+UtnKFyy3P+NTSYeIRBrKYZODJB36mQOgB8Z9+d/2mWmk\nc3W3ULyI3KaYx+0KviETBZtwYfA4I5PBImeJU9L3Yj06pUOY27+BxszC31THgwcf\nLIc9gKIT+1x2GlgkxcpOzVqf4vkfiscwf0T5Q9hApk4yzfOrTxfq/zAVoMVc96Wm\n7tKsp/iOHmsjElGmwgiJ37Lm+m+U8jlivsIfvOqueJ6lgWTCsT/yUuCM6OauaJ2w\nN/kaJf7z438Q+F1ZiPXBdZ8806d72xSKAjR07lmt7yfIFNiaLlW0Wgbj9oVI3/kO\nUXvmmgHZjPFuJBWmRLwd1pji2macQK2k9/y23OFcKhcS4euVLzhFD37BdrwTl4Fz\nRaHFymsILNPaFbFIRrHo0zUp3sSDm9qzTiDM/h4XPUTxqdps/29xQPg1XoYQ5OIC\n6g1VOqHz5QxQf/itJLw/VVn0eWXd44XAz3kmcQbHujrtCAAtRAXNSozy0cAqvbqp\nvW1897+EP7v7Rl/wzIIowdOSrc7mllv/pRZakiRW9/nWQl2GNva95icXHKFRJjIr\naRli4t+47dTcrDyArt3LqQRuQjYPUtk55KLucRC5uO28RmNIAdR/e9+YmZCd4A6f\nhn2Iv8LoiB5RXnhSPuBFpRYRSZk9nvgaeZMhxEkMC5yduIbOd+fPkQ6n6CxUNm0o\nvteMuHw+tVOCyNjvAHpq7SD81cMG+bKamCS0oCypd5UxQppxHYcArntfFXq+lqyQ\nDUbvTo9niK4w0Wvvki/twBvmVMBhHPHVH8GLTDlSrRtIiVMg1d4DSbvQLoxwSnXL\nlNPBB508H3V2LMTKwpWj/lwL5YiwwCHC31bJ81l8GxNBn9gcWdxyg0zqKP9xpuXe\npcFwA48Y65YoJ/M3DsiYkp1IFyj361uvE8oBT3BxOopJU/A778frbvBcNgGBOBwp\nU7d9ITNxxCxmo8g2fXmdACT89K1rmgBCsGaOlZ4XT4WRoppz8hhI0inIr8jocuw8\nTpjCaBIGlUA/HeTrMhalac26zIjzjF/TPYOyiquJhIxnCZ3WSeyWTfVVGawVKOaz\nRipVLbEfTFmkR8LZV16voD7mUZYDCy5+SepBiQY9t7muP5UaojX92tnYiS9jfC9N\nwqDaWY/SqLkGID84x0OuwL56lnmewT+wvW8i12Fd1SEFhaop5+8yxSzUxBdPFV9Y\n9HcF56DxraY+mSgJ7Y5Gp055jeE6q5opoU8tQ/oEMEv/kyAZDO0Yj3FnwIMQjScg\n45UmcsKmKEGDiGwekpqceCYJIarfRdr5OtzbWGe4GsCHQmkr7SzuDfh0Lw4IqvT1\nQ56S56eFfEXuk/CExfQE/Rw9p2AJQTLwf7Ze0LQlOv7UuLVFtfDNR2xq8MqwV/sd\nf92cT9VKtjlS0VzuouEmYIKofs2eUnLhN8p8qrnXchF7V9ePWsxpToYf666eM9Cr\nBM4Qu6ihbJ2e1y8xvOI7DHYwYbr4NDXW0gt7ABGVFdbe1kEdTT/OtMR5dqmI/s1h\n8Ck=\n-----END ENCRYPTED PRIVATE KEY-----",
        ),

        'alpha-alice-2' => OpenXPKI::Test::CertHelper::Database::Cert->new(
            label => 'ALPHA Client Alice 2',
            name => 'alpha-alice-2',
            db => {
                authority_key_identifier => '25:95:E3:C5:91:78:17:06:C6:36:B4:62:8E:10:69:E3:56:3D:6C:2C',
                cert_key => '11',
                data => "-----BEGIN CERTIFICATE-----\nMIIDhDCCAmygAwIBAgIBCzANBgkqhkiG9w0BAQsFADBbMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGzAZBgNVBAMMEkFMUEhBIFNpZ25pbmcgQ0EgMjAiGA8yMDA3MDEwMTAwMDAwMFoY\nDzIxMDAwMTMxMjM1OTU5WjBdMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZIm\niZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxHTAbBgNVBAMMFEFMUEhB\nIENsaWVudCBBbGljZSAyMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA\nsVsAN84HFUBnXbrIn7im07Ry/qgCyfVbzKbTBOwr1XDP63xkEkgBVuuOVtDgBNrd\nkxf9wbYq3CAaYdOO9YwjxfysTOr8YpOQj4xJSTrsoG0d+YGTzcnR/+4tJHqva8hh\nXNIP3ysb68rpADXCJH+dlhbn7NTaG8wN+2uWJnUifeUjO6tCK8ZgqPsRlB2PfTxg\nWGjcdotNO3vQK2esXbuCKGIL3py67AYWFGy7FkTjCQ33d75WvL6aGrq9Lg3MCEIT\n1F9Ihotyen6Ox8D4sWjxynRAZoou5+MjWItefMDENwfqVUKvVAix27vmZfOwcnLf\nwcvmMpADREilFhdigMBgYwIDAQABo00wSzAJBgNVHRMEAjAAMB0GA1UdDgQWBBRO\nMVcVPei89IY9+yCEt0kDJa+qVTAfBgNVHSMEGDAWgBQllePFkXgXBsY2tGKOEGnj\nVj1sLDANBgkqhkiG9w0BAQsFAAOCAQEAfb/hC3hzH4dAV74BIl3CLh9PuPGjlL3m\ngpkTrn9SogrDMtTaq6ewoFaqioBFVeLwwnflVpYnzG41tjlCXq3JGx8Oiw0pz6Om\nBv3Z6FzeA7/yY05l6XO82xRtl7BF6k0Akh6lkz0+Of2P/cUwmBid2PkWuwx9bIpb\n8pj32E9h2OmrAao+MWwfskHlER3JR144llHxbM0oDPUR9cAn9thq5am9XGqxMHdJ\n8xMcSX3dq6XYADel8zMpYWDoWbwq3pptVqnvy69BUoV7zcp8iYNoEHwrLG4mPUHh\nNntk2IV3UJZdjCm5ZhVnFs5ZLoI/d4+uzb3mEH0ziOsCvNJxTAihsA==\n-----END CERTIFICATE-----",
                hold_instruction_code => undef,
                identifier => '3Mx4bA9yOps8owt3t5bLSK6rfmE',
                invalidity_time => undef,
                issuer_dn => 'CN=ALPHA Signing CA 2,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'zbwY62EfQRkBZ4bw-gUdZeHsCwE',
                notafter => '4105123199', # 2100-01-31T23:59:59
                notbefore => '1167609600', # 2007-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:b1:5b:00:37:ce:07:15:40:67:5d:ba:c8:9f:b8:\n    a6:d3:b4:72:fe:a8:02:c9:f5:5b:cc:a6:d3:04:ec:\n    2b:d5:70:cf:eb:7c:64:12:48:01:56:eb:8e:56:d0:\n    e0:04:da:dd:93:17:fd:c1:b6:2a:dc:20:1a:61:d3:\n    8e:f5:8c:23:c5:fc:ac:4c:ea:fc:62:93:90:8f:8c:\n    49:49:3a:ec:a0:6d:1d:f9:81:93:cd:c9:d1:ff:ee:\n    2d:24:7a:af:6b:c8:61:5c:d2:0f:df:2b:1b:eb:ca:\n    e9:00:35:c2:24:7f:9d:96:16:e7:ec:d4:da:1b:cc:\n    0d:fb:6b:96:26:75:22:7d:e5:23:3b:ab:42:2b:c6:\n    60:a8:fb:11:94:1d:8f:7d:3c:60:58:68:dc:76:8b:\n    4d:3b:7b:d0:2b:67:ac:5d:bb:82:28:62:0b:de:9c:\n    ba:ec:06:16:14:6c:bb:16:44:e3:09:0d:f7:77:be:\n    56:bc:be:9a:1a:ba:bd:2e:0d:cc:08:42:13:d4:5f:\n    48:86:8b:72:7a:7e:8e:c7:c0:f8:b1:68:f1:ca:74:\n    40:66:8a:2e:e7:e3:23:58:8b:5e:7c:c0:c4:37:07:\n    ea:55:42:af:54:08:b1:db:bb:e6:65:f3:b0:72:72:\n    df:c1:cb:e6:32:90:03:44:48:a5:16:17:62:80:c0:\n    60:63\nExponent: 65537 (0x10001)\n",
                reason_code => undef,
                req_key => undef,
                revocation_time => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA Client Alice 2,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '4E:31:57:15:3D:E8:BC:F4:86:3D:FB:20:84:B7:49:03:25:AF:AA:55',
            },
            db_alias => {
                alias => 'alpha-alice-2',
                generation => undef,
                group_id => undef,
            },
            private_key => "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFDjBABgkqhkiG9w0BBQ0wMzAbBgkqhkiG9w0BBQwwDgQI92Z4mO7qmCsCAggA\nMBQGCCqGSIb3DQMHBAi2Hforzj6ykwSCBMjLkgjSC4E1XewpNnD5CpnJHRQ3g6OI\nr6moMJOn/7f1sbjhW3kMdDvjvexkxo2tc9ujmEIcQOLK1gH+ljVtNbs4mGj1CQnE\nve242QVKDFQ6B5MZ9hF7sPe/sl8Z4/9yJEA1TlKYe7fSdO4evDC9ztFm43mIE+NR\nn48xuHdrolUb3MVATqG/kD5aGfopLF0WjXFViGYTI+xJsrxn5FWsVpnS2tc3Sh39\nUzyP05wP8Hj6BaEbXvyhBExj45z4gYhmaIWUhyKw83y3t+XdqMK4UEoUaoddpveE\naISbOugxlH59/ghNKj9jUM25SaGKKx5rfoTMUTofULHOOR1rK5i6YyAb23oeKMDi\nb0XZTmKbKzblfarX/IRUqCgDkzCkbANC/otG7fy3XzVASlDpY7oAUK9Q8wm+d//7\nSq3q+PYUETCILrWgWsitw/vfmTezFUY3RtVTIzbWPKnKS2bnC4N1hsvOzfHvkOAO\n4HkXAsUlUnNjcwg8hoHnJdgIr/LY8FkdTmnFtsECLa48v7Gab/Vt1CUIB1sbDErU\n1qS0w2bTZyz5gmk3TC/0uXdyuRqqXaTMkMI3yiqXZxYcJeNuSUhs9MChb5O78YxP\n+8ILoU2jd1VPaz6ZjxNRtoqzLc2+G9PLylpROwmGycpx2tYQDT5UOQdRnSD1gzQs\nEh++xXEO487c2h37NyTozfqfCydU95bm0WN5ReHtE5uq6Djr/p0rxfrHqwlzPQLz\nX6Cj+1xg22l54TkV7zhgU+y57mS3g9a7pLouGqgILVNLjz+fZR0sJRnmDHPMxIL1\n6av2FUkOIuzHR/otqE6krr1vjlJPvSYD7L6K954d+TCzoF79HvKMQCUAt1uNexk1\nhMgRCL5G0a3/wQyjZ0+YCAZPtpHMWvm/Gt2tyKvMdWWVwjR+wh/udQRhCfdemUj+\njO1R/ReGD/pRmkoq+TjNmQbrw74yuvA25ZxDrLa0mjTd0i7cugN5lO7CX6O+/GsI\nFQ/nExxiq2TOAFNn0aOlv7SFimH2WHDi6RFnINItq9TjS+/YN4tDf7Kac5pJe6Ip\nZAMu+INWdJfcOD6KdbUVlE3uY3Fr07JPUwjHYVq2GQvFr6MmCR8Bp8W5D+ophwTN\nIgGDAuDu8cjNZHiUey+H5cHMaKJx8u9PsZN5vzJZoVYFdLcnpfmx+bJudsiEpMq0\nfPzXwAsUxC1rVYzJWLKzab25j2YAbJFDYKEnFIdCwxsQnQjgolDeOUtT429l0/2i\nxZIMbc8DCnUjdljhrFgOHql6jz1ixjuyulwUXb47Aq4ozwX9PGBulmz/WklxuV+r\nmxcHkO32HMGOUgZv1+awVgKeLtLGkBgPTvZCFsghhCe0YRmuMEAG8phJOZn++R8/\n+2InSH0ti6z9saR0eEETyzghb4u7SfqHJFRWFpQMPEXF2ftvyGGpY/9LUfdeS1S6\n5Ir9JCnMQXZHFZnlQ4bBcEmQAvyfQGkkKnCFAMrDqyDAv1TfsdP0aH0jTaBr8r9J\nS+ge6r9SOSiNb9M6wZxPIny8ez1Zw10UzLfbBNn16bue7mZ2Zqy8rSNhxaCYPwmF\nt/wiQRK4sJfCi/yiu6cEKtyoaTSnpbskbiOsZCMx6AVEjRQdVMOQCfoTxTzOCUFX\nF/w=\n-----END ENCRYPTED PRIVATE KEY-----",
        ),

        'alpha-alice-3' => OpenXPKI::Test::CertHelper::Database::Cert->new(
            label => 'ALPHA Client Alice 3',
            name => 'alpha-alice-3',
            db => {
                authority_key_identifier => '7C:C0:F0:D4:83:F9:BF:97:8A:3C:55:F5:4A:F6:89:0F:00:2B:EC:0F',
                cert_key => '19',
                data => "-----BEGIN CERTIFICATE-----\nMIIDhDCCAmygAwIBAgIBEzANBgkqhkiG9w0BAQsFADBbMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGzAZBgNVBAMMEkFMUEhBIFNpZ25pbmcgQ0EgMzAiGA8yMTAwMDEwMTAwMDAwMFoY\nDzIxMDUwMTMxMjM1OTU5WjBdMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZIm\niZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxHTAbBgNVBAMMFEFMUEhB\nIENsaWVudCBBbGljZSAzMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA\n3kHwnEpnslhH2KoVxuI0/xk1dh09VYO+Rbfkm7yRt2IUjzzP8uzER9MdRyVvU+T6\nHAWJHMRifu7DSncsr1DEJ2C4h/vJV2gs62uT8toDRdPaOxNbsPZw49ll/0dysLzN\nKgO+K4Wzg1FPjZBL5IfEf8wqyfLsvi/DvejSlneqEZenBRjD4OqBxXlfSN5vkBgD\nF9j6kCkVtcjPLGLvK7zjPMo4ddGPOEFttuWGqul9UOr6VnuWMemJOeU7/XFb1Oii\n/f9sQiINNojvI+gk2Y6S+AkVSxyG3j847MttKIteH+WaY3WqSVBIRoEMQIvi/Nz6\nllzUffvEib/76F731GMGbQIDAQABo00wSzAJBgNVHRMEAjAAMB0GA1UdDgQWBBRE\nXGfsi2c61VEs8H9GqdD6jz7aezAfBgNVHSMEGDAWgBR8wPDUg/m/l4o8VfVK9okP\nACvsDzANBgkqhkiG9w0BAQsFAAOCAQEAYduPnhszH4rHWicqb63SekmOb/WircGf\nO7IYLhbrDAoWy5zWVv6/1QLZj/YIydWxk4L71yR95bGboJIyeu+nG6IPOi4zK6is\nxp5Oa3vt9ArdApfLhxODw1Zy/s7j7XeYlcQDaX6enzkmADUypx5BykF6tCKGFA0P\nKg6K3XtvVplRCUMwGQG/PjMdQ0rrcD2de6vkoqZ1cG4pXh//VtL2D5WFUDl//31b\nlgaF1a6hQfuo9sYVlW163wyfmbcIFp/pmwUto2dQYn2y/DtkFZkLiA4DJxcCS9k2\n8rO4pIWPuJ1LdHZZj/RUg5NxGwQzaV2ZmST987ebxZm4KLs2w7bVCw==\n-----END CERTIFICATE-----",
                hold_instruction_code => undef,
                identifier => 'qBHtYgX4yx9Bl2GI4EHMaFYF6MY',
                invalidity_time => undef,
                issuer_dn => 'CN=ALPHA Signing CA 3,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'q-yWkovtKUUH60U0_O-mjr54cBs',
                notafter => '4262889599', # 2105-01-31T23:59:59
                notbefore => '4102444800', # 2100-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:de:41:f0:9c:4a:67:b2:58:47:d8:aa:15:c6:e2:\n    34:ff:19:35:76:1d:3d:55:83:be:45:b7:e4:9b:bc:\n    91:b7:62:14:8f:3c:cf:f2:ec:c4:47:d3:1d:47:25:\n    6f:53:e4:fa:1c:05:89:1c:c4:62:7e:ee:c3:4a:77:\n    2c:af:50:c4:27:60:b8:87:fb:c9:57:68:2c:eb:6b:\n    93:f2:da:03:45:d3:da:3b:13:5b:b0:f6:70:e3:d9:\n    65:ff:47:72:b0:bc:cd:2a:03:be:2b:85:b3:83:51:\n    4f:8d:90:4b:e4:87:c4:7f:cc:2a:c9:f2:ec:be:2f:\n    c3:bd:e8:d2:96:77:aa:11:97:a7:05:18:c3:e0:ea:\n    81:c5:79:5f:48:de:6f:90:18:03:17:d8:fa:90:29:\n    15:b5:c8:cf:2c:62:ef:2b:bc:e3:3c:ca:38:75:d1:\n    8f:38:41:6d:b6:e5:86:aa:e9:7d:50:ea:fa:56:7b:\n    96:31:e9:89:39:e5:3b:fd:71:5b:d4:e8:a2:fd:ff:\n    6c:42:22:0d:36:88:ef:23:e8:24:d9:8e:92:f8:09:\n    15:4b:1c:86:de:3f:38:ec:cb:6d:28:8b:5e:1f:e5:\n    9a:63:75:aa:49:50:48:46:81:0c:40:8b:e2:fc:dc:\n    fa:96:5c:d4:7d:fb:c4:89:bf:fb:e8:5e:f7:d4:63:\n    06:6d\nExponent: 65537 (0x10001)\n",
                reason_code => undef,
                req_key => undef,
                revocation_time => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA Client Alice 3,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '44:5C:67:EC:8B:67:3A:D5:51:2C:F0:7F:46:A9:D0:FA:8F:3E:DA:7B',
            },
            db_alias => {
                alias => 'alpha-alice-3',
                generation => undef,
                group_id => undef,
            },
            private_key => "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFDjBABgkqhkiG9w0BBQ0wMzAbBgkqhkiG9w0BBQwwDgQItdLS7j/3E8sCAggA\nMBQGCCqGSIb3DQMHBAgYo6rjukx7OASCBMi2mhvq7zh4qm+wdxJyH9cE1p+ppbDp\nE+OTagU6PB5Cyacp+mmd/0QUZYYUOriQXEonfpyHuKb3vBc/IwIh62mIZsBOsw8m\ndc9iBt0/cFfYWvtwryc5yV1dtsiOsspsO+7mBqvf2zaR/jULtb1fwibAkE+NYoHw\ndfgZxgFp1CutTes8UdrsJ+uSkd19Scq10MNCeMU+x0zPeFin1/m/Fh3BaKoLxDgy\nATDjYFGsjzesj9eTYCCCMnDfKmOPQmm+X8MVoDSL0HH96ry05ihKUKKOk5uIA/82\nmpT8+Od4bVRJ7aHaDpVi6HNzaSo/5vmKHBvjZRFdEfQ6paYF/Sl5kBOOU12wni4J\n3inUAUPR0UL6+g2BG/aH9AMx7GJkomJ55abbmU0hMvVjuvH11E9Y2wg6CV3sZRbg\nXI0pySJfolLNiOgZFEViXb8UgFVXwE9EC3UvqYxnP62ouycJ29G27GV2lxvJzzcL\nFsw7UOeb6OZyqj+TqzKBN8+Req9aT+Qnpy1ory1sQJJuHucAhDEV4L1XSDxbwfW9\nCPEUg2zGlBKl7vzTGEsRtz+piFaG6IboDbu20M7Mro60jzfhumH0WG1hfjfBk/Dz\nsmLeUfY1sQb7puT5uSA4NNZMIZM4lgvrZc9o3Ka72RhkJ9HhgQyEzOar24opeUOy\nsUdKE9SagX0ramEQ7ObBBZd/xjk6EoQEmXW5LgntoZWCTV/M3/St+OjZmuTsVilM\nRQb/lfbONI3cThMJuAjPzSsaIHiJXaKTA2mERDIe4wQR7XUpGVr9TqZAvg7LBt4p\n6QtrgKy8KSNLy1TVgammUjoUdZYeAeLjjLLs5r4DVKCwqQk+mYwWFYBiOOTgFiUS\nEgVaVot7hTj70ssxv58EXZmY4g7SwQ+ZY/2YmRewvQStoJ7hdFuHmvAKXYpyFKg3\nALmqbxgZh17qKRYRKtKnuOESvSob+UluszLmHm/JlUJip7r1JnvyDn3xW0V+4tCx\n24CPhYfNXboiy1GVokiSpWsp6/s66WI0QzMt3lXDPE60QEtFsUBGygh4EpnktZNy\n3t0b1nKqSWdjuYuvS64Z2Lx5UHow/VHIFr+kOL863XorKUfn1FRytNsx3eYikwAw\nKjWRuLxvjDNwrZWz1wi9b3DwZOYWCuj+hoxJfmkfPKIQuYEUq3uwxn8hud+KbLH8\ngjpJIsXnE6P01X6/GLByGwmbz0/ZPXzbJlIWFw6PhunqwEsCMQ6VpWuEcQ7z6lKa\n2dDD+HI6TnxMI6bmotqoNqspFGcYW6npWUHzbg868AJUdM6BzXFYv7r+rRKQv1il\n4uNLf26BRmYg+463bsA5P45M1CoZqNWdHOOTQOY9aCAPu14CNju0gM1g7lejwnQn\ni9F6v+F5zzKD6pNeW48TVoAXJUAgfH9TCZiJP/vzoIfWKfzaKbWCREvO3pP3fdpJ\nhQO4To3H99KGumYdjqBw8iSfKbP1r0r77mdyY854KqMfsptpg10kAr46vtOq+UUu\nMEFWWGMiS3JPfmLjCqwi9lRYPi9JJT70JV2uEeaZtvj/ACH8eghhcdpwfGli7cd1\n8nTqvhr0VFbdpFU1+43zPYb5q0g94KlHnSlWbspHYypEl7pmkt2TR/yKa/pwAiO3\nNYw=\n-----END ENCRYPTED PRIVATE KEY-----",
        ),

        'alpha-bob-1' => OpenXPKI::Test::CertHelper::Database::Cert->new(
            label => 'ALPHA Client Bob 1',
            name => 'alpha-bob-1',
            db => {
                authority_key_identifier => '93:D3:15:2C:E6:94:C1:D1:39:A9:28:DC:2D:0B:F6:6D:E7:2F:DF:CB',
                cert_key => '6',
                data => "-----BEGIN CERTIFICATE-----\nMIIDgjCCAmqgAwIBAgIBBjANBgkqhkiG9w0BAQsFADBbMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGzAZBgNVBAMMEkFMUEhBIFNpZ25pbmcgQ0EgMTAiGA8yMDA2MDEwMTAwMDAwMFoY\nDzIwMDcwMTMxMjM1OTU5WjBbMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZIm\niZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxGzAZBgNVBAMMEkFMUEhB\nIENsaWVudCBCb2IgMTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANf7\nIyoJArg1kjtveMuaY8p+6R9FTz7ZWDVglQvcCCKAY8k6bi96Dt+OdxmmmJIKcP6L\n0av0U8QuuuBqcfAPHFsP9xdBFaNtEpYqxAfMVCZmvjpSjsneoLhxQaRIXWv5/Zna\n+5KpBdoOqFBeV1zzn+uT+g3osOkGFEvvaK/djeo99NMG2c9D0rVnPLT+IuvJXmTS\neFFHMYqQ4V0qYtoLKWBy3UmeG5ASi0DViy7c6QaoVbNs+E1yhQ8JqD1E1srh0Q7y\nzkAvz5ntACPL5/P0EUQp+GRgjhwYYx52UL2v5/X+FHPJJ4wtGuCEojOE7zGoFRXd\n41k0VBSjLCfvNx51lNUCAwEAAaNNMEswCQYDVR0TBAIwADAdBgNVHQ4EFgQUWiMG\nsi8AmtVISH0VaIENSEIQydIwHwYDVR0jBBgwFoAUk9MVLOaUwdE5qSjcLQv2becv\n38swDQYJKoZIhvcNAQELBQADggEBAAtv5IAgn5HNa3TSw33QvfsaOAywnJsbCKcw\naJeSl/M/0nLrCoaNklbcQq/iMGfo6Ml5nukYqIw4oZmLOS8/TmEhz/jGLUlewbOw\nbbMpOsuKbKHzWf730gyiQbmKTAk4XqsWS+vfZh56Rf4nRJsN33muMSWlmhB8XCrW\niNdW6/dANwXD1VmJN4cOKf99EX3PkYBa5eC6TqkfxmySD3BsOD6K8fIbMcolF4oU\nydI95SprTEpL3rBjsX2i+i+Rw5Lo8zKHuU1Weg2bPErCSnHA5eDJ+/FKxinOT7/9\nUPC0qeP4ISuQfWAwa7CMPi9gJLse2YBq66x+4u9QtJfEJG8oh3g=\n-----END CERTIFICATE-----",
                hold_instruction_code => undef,
                identifier => '3T7HFMNGMw1qbnlWHMVM6zGQZ8c',
                invalidity_time => undef,
                issuer_dn => 'CN=ALPHA Signing CA 1,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'UDFhlBTPFnXDz_tiXZ_FZ7MuKng',
                notafter => '1170287999', # 2007-01-31T23:59:59
                notbefore => '1136073600', # 2006-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:d7:fb:23:2a:09:02:b8:35:92:3b:6f:78:cb:9a:\n    63:ca:7e:e9:1f:45:4f:3e:d9:58:35:60:95:0b:dc:\n    08:22:80:63:c9:3a:6e:2f:7a:0e:df:8e:77:19:a6:\n    98:92:0a:70:fe:8b:d1:ab:f4:53:c4:2e:ba:e0:6a:\n    71:f0:0f:1c:5b:0f:f7:17:41:15:a3:6d:12:96:2a:\n    c4:07:cc:54:26:66:be:3a:52:8e:c9:de:a0:b8:71:\n    41:a4:48:5d:6b:f9:fd:99:da:fb:92:a9:05:da:0e:\n    a8:50:5e:57:5c:f3:9f:eb:93:fa:0d:e8:b0:e9:06:\n    14:4b:ef:68:af:dd:8d:ea:3d:f4:d3:06:d9:cf:43:\n    d2:b5:67:3c:b4:fe:22:eb:c9:5e:64:d2:78:51:47:\n    31:8a:90:e1:5d:2a:62:da:0b:29:60:72:dd:49:9e:\n    1b:90:12:8b:40:d5:8b:2e:dc:e9:06:a8:55:b3:6c:\n    f8:4d:72:85:0f:09:a8:3d:44:d6:ca:e1:d1:0e:f2:\n    ce:40:2f:cf:99:ed:00:23:cb:e7:f3:f4:11:44:29:\n    f8:64:60:8e:1c:18:63:1e:76:50:bd:af:e7:f5:fe:\n    14:73:c9:27:8c:2d:1a:e0:84:a2:33:84:ef:31:a8:\n    15:15:dd:e3:59:34:54:14:a3:2c:27:ef:37:1e:75:\n    94:d5\nExponent: 65537 (0x10001)\n",
                reason_code => undef,
                req_key => undef,
                revocation_time => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA Client Bob 1,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '5A:23:06:B2:2F:00:9A:D5:48:48:7D:15:68:81:0D:48:42:10:C9:D2',
            },
            db_alias => {
                alias => 'alpha-bob-1',
                generation => undef,
                group_id => undef,
            },
            private_key => "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFDjBABgkqhkiG9w0BBQ0wMzAbBgkqhkiG9w0BBQwwDgQIGRyXV3oSNNUCAggA\nMBQGCCqGSIb3DQMHBAjiSW6uGxAWKASCBMjXIHqX4VeDUg443R8L/692GOAo2/rb\nsJpo6t7UZe1iigvKGCb21zfxsIlAozveZn1Vhvt1A9EZmudLiU18areOB1O6bqA4\nx6DJ8EQ3tK1vzn+S/p4kz2xJ67y3DAO593llCYbKnFyUPRDDyPiuPi087r3KngZc\nvnzkluHQJikZKDLFqIWX+1HOZ1Q3LQQMhsPK46PU/t3EG19aYm0YnSa/rFeYLm+/\nGWPX5v0TUbI5vMjf3weFeQtQe8FclAYL/4LzXD7j6o5mvObggjFUtxye7KurN4gD\nZBEYAF/miDQuysvXHjNEF/0gBvvOMrEhXbdLcHUhp2YcnCJ13IuWhzHeELW0aA5e\nMPh3d+s8havJSfn1pzVx8kJH252PrccZr2FkMLpPXJ6hLeHMo8/LKXPNxM2fpXnb\n6EXWij+5bD73J5ZZkZI1qvM/8Zp8XJ1oCKVVPy59DzXeZoybKDmZsxlGCQ9308Hj\nba0OdCTfHA3b7nO7B7DFkXJRUcwkB/XfQMOtbMdhyLadhQ6j56+70nEAfbtEMjgj\nL0WYFESu+Cih+iA/YgogKb8ZVhA0+AhZym5V1Oj2CHim7MCkX9DAMDC6bOEqzR6d\nzPCCahHIE9+j53fQ5bqme+faoV9JIsN37zKoKYoEaJvC1HIJogtDHxpufDBlhnEH\nOQakXFu17/so4+yFVaLK7SpdIo6cia7OlIITgVmNHkWpARMj8WocWYfLXYQv1bCU\nIwB+HvdFD3ZDJjrbgomJEbEk1/RXJ/Oeg1LEYHrJuQs+ohLaoDXpWZOn29vWzFiP\nEUt5Ms0aydpB9c5gdRDFeZng6fGEyQM+VKZz0bQaL9ywS+BPi9nYzg6XdsshOvNd\nNMfj6qvNTMKq9bYlxUk2vWMJkt3l/4x5rxnk0Sn0kdFRiaZa/nZq8iNa/5/AKl2V\nPIitivfO596boHgwJxLPBtO/3s8rorS9uEYtjI6Wdx+G6MAI1tx6GfM5xt6Ur+GX\n21E0Zvbjr0wlMJ9mvXmCkkHoaKHW0jUtZ/+4setbI1FsTTRtVqEX4e2qB+cXUNye\n/nDeJTzwkNOTiSbq7Y434bwjLWWDsqPjcKSIZr50HvSgwL5+o/DBRGlGwmsT8vDt\nZcFpm0pVwSb3w3OyA/jGfmFs3MGu7z7vYPwfzSjjLAepMankP1tJhAysOiPJZyyt\nxP4AHTkqPCITKpVH1LHec0FWpemZKPCIJ/qEEByfJp9eO+CnqIxByYIApOOZ31pH\nPnbBtNnSzcLXaHrzscbbNMkEI8kp0kd+tA/TXBsBF5DqczpxcPvQYMJFGqLU1XsI\nKA/8K+k8NTiJX0EgLCT4xesnwKixTjqjcZdQifyhWiG5Jl5xIaphpRrbobEfUnjP\niF4zV82cgpM3QfK/yf+DGwQ70VBG+8jGLQv/UajjUmtsApOakCToq9iwFPqKwpoF\nMR/+sNj+5tkW9n4ddVkTwc6UjxQy3lhNRK9zc89riv68QXYT0xCOXO5wx6biS/G5\naNfvRkMARDZS27USZxVa9CPydyQIVSKoObV5TPY4HAwv02FTrnx9ZeLksb/2+/N2\nzn+aovORcCR4PdpZuvz2SAOiF72hAuRnspmwMZpY7FxMk7frW94Z5WYjifLnCQwD\nSQ8=\n-----END ENCRYPTED PRIVATE KEY-----",
        ),

        'alpha-bob-2' => OpenXPKI::Test::CertHelper::Database::Cert->new(
            label => 'ALPHA Client Bob 2',
            name => 'alpha-bob-2',
            db => {
                authority_key_identifier => '25:95:E3:C5:91:78:17:06:C6:36:B4:62:8E:10:69:E3:56:3D:6C:2C',
                cert_key => '12',
                data => "-----BEGIN CERTIFICATE-----\nMIIDgjCCAmqgAwIBAgIBDDANBgkqhkiG9w0BAQsFADBbMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGzAZBgNVBAMMEkFMUEhBIFNpZ25pbmcgQ0EgMjAiGA8yMDA3MDEwMTAwMDAwMFoY\nDzIxMDAwMTMxMjM1OTU5WjBbMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZIm\niZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxGzAZBgNVBAMMEkFMUEhB\nIENsaWVudCBCb2IgMjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANlc\nYeCGZLPSbqdxKWUFgPVGUgjAbSjABXpSbnHIAyINrG9ZktuffzuE9voPO+dCHCof\nXOjo2q3rQkal/2jePMtctP1jldgsaE+K7Hn2B1A++/+zxGUZ4PxNWXZTx8kMgJaX\nSN3qUtLg6tk2jxywMsfTXOGf1wtkdw6edMTKNyG8od9brgrBqjfsC4pYyQGbqWR/\nWK9lwUH45DC8LHgjeKY6JyFUkJGgZO06W/r7yNE8DL37E620qTO9wV9N8o0X0j7g\n8hSaPuYS+rt9U+/lOfvh1c+Gnu5uacNc25FIe85zAPDL2WmTwqJ6+Zl9gh3VRopP\nvjM2AB3nV34RuAq3Og0CAwEAAaNNMEswCQYDVR0TBAIwADAdBgNVHQ4EFgQUd79n\nV7NgoQRnLih0VHi7lveXI9owHwYDVR0jBBgwFoAUJZXjxZF4FwbGNrRijhBp41Y9\nbCwwDQYJKoZIhvcNAQELBQADggEBAGfFmLflLdJvq3mpc9fGU64/FYQAH+DgQ+0k\nvXxyTNrpJ26DCR98x6yFHNrJPVk6Ygi/30USgDJZ5h7X4u44R4mRMbmhS+XHFhRH\nlt7t8JxY5bjmyuvci6nC6R/FTQY9D53VMX6tGk61VckmFpq7QxInrls62lBjJdul\nSZL420Bglbn6+f8AlQslEEG3enmY6mns5OdpETeMgL3clM1j9UwL6DCoeyIK2W8r\nn8XL1PWgLCQ/fqpqRTHnfGEpPnR2+eXoRtl7NQKPComdaIIwgjAROQHBpyLT202n\nT6CrB/cmkRHeocx7zLBxXaBq/5q7iTu6D83ghTULkymjeeRk1UM=\n-----END CERTIFICATE-----",
                hold_instruction_code => undef,
                identifier => 'SpHb2LrYyDN7F1YolXPH8_vgKyA',
                invalidity_time => undef,
                issuer_dn => 'CN=ALPHA Signing CA 2,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'zbwY62EfQRkBZ4bw-gUdZeHsCwE',
                notafter => '4105123199', # 2100-01-31T23:59:59
                notbefore => '1167609600', # 2007-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:d9:5c:61:e0:86:64:b3:d2:6e:a7:71:29:65:05:\n    80:f5:46:52:08:c0:6d:28:c0:05:7a:52:6e:71:c8:\n    03:22:0d:ac:6f:59:92:db:9f:7f:3b:84:f6:fa:0f:\n    3b:e7:42:1c:2a:1f:5c:e8:e8:da:ad:eb:42:46:a5:\n    ff:68:de:3c:cb:5c:b4:fd:63:95:d8:2c:68:4f:8a:\n    ec:79:f6:07:50:3e:fb:ff:b3:c4:65:19:e0:fc:4d:\n    59:76:53:c7:c9:0c:80:96:97:48:dd:ea:52:d2:e0:\n    ea:d9:36:8f:1c:b0:32:c7:d3:5c:e1:9f:d7:0b:64:\n    77:0e:9e:74:c4:ca:37:21:bc:a1:df:5b:ae:0a:c1:\n    aa:37:ec:0b:8a:58:c9:01:9b:a9:64:7f:58:af:65:\n    c1:41:f8:e4:30:bc:2c:78:23:78:a6:3a:27:21:54:\n    90:91:a0:64:ed:3a:5b:fa:fb:c8:d1:3c:0c:bd:fb:\n    13:ad:b4:a9:33:bd:c1:5f:4d:f2:8d:17:d2:3e:e0:\n    f2:14:9a:3e:e6:12:fa:bb:7d:53:ef:e5:39:fb:e1:\n    d5:cf:86:9e:ee:6e:69:c3:5c:db:91:48:7b:ce:73:\n    00:f0:cb:d9:69:93:c2:a2:7a:f9:99:7d:82:1d:d5:\n    46:8a:4f:be:33:36:00:1d:e7:57:7e:11:b8:0a:b7:\n    3a:0d\nExponent: 65537 (0x10001)\n",
                reason_code => undef,
                req_key => undef,
                revocation_time => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA Client Bob 2,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '77:BF:67:57:B3:60:A1:04:67:2E:28:74:54:78:BB:96:F7:97:23:DA',
            },
            db_alias => {
                alias => 'alpha-bob-2',
                generation => undef,
                group_id => undef,
            },
            private_key => "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFDjBABgkqhkiG9w0BBQ0wMzAbBgkqhkiG9w0BBQwwDgQIDWnCeZbOf20CAggA\nMBQGCCqGSIb3DQMHBAghzR1MyMN2wASCBMjE2/HcFxpUP706xUNsPoUS/tT+CiBt\nI/Z5Eb1KyUczRo37D2E0kMduV5BT8EKtSAPM0DW/LJXbeq3txhhFU0kcSCopuVts\nAco2wEvm6dKZKM8O3Hk/fr61s68Yj7GDSFL4T0+gUtTR7m5/lICu5WGHgOxEaYVO\nwt1DbVFI3fCIHQeU4lfo31PKFXPeJ7M/Yx5e3cu2T3kV6/6NLQD02vhfYw96PC9s\nVZx/kon4DByNqu6qbinmd4A+EXegznqe6F7RfbBlLQ/rqal8z8ZNMbSngs3F8l4q\ndhz0d9us8v3y+/qHuljTbfnW7Q+0NYTq+lvpMn1lK4PnPGSsXjVdpUHUr8fFPzW+\nXxlqHhV67xoiEwQXVZCeohxUUDmBr/S8uBhhYNyf/vD2a2nsK/RgV/x4IptqIukz\nQOv/z1QLXbBo7jyDrhAVFzArf0NONIVMq4NUDfGhuDnZsT1nCVgmWTK5FryDt0Gi\nqDdtXtuT8VMV6G1hhSCGUKxiqxIBowIrU+vX5nh81WvdvCksefRs0g+qfhsUElSg\nIX81LVwrVeSnUczFnaxiwKlbK+mREe6l0+gRlElA7zytC5isZWh8pYXu0a7SL+Em\nV2Yu1hNGsREBo0o56YQlWVd+/r1O1YpIKYq4uQs3vwIu6zwXpwY0QP468MUUHX28\nmznta8uVH3ViuvwNt4V4p5C+IfFZzgpSpvCEiZwWnfiL2uy7s7bpitjcA43m1USK\nSHngtPhG9ROiDjWaTZAFgbnOf5acL1VyljgD21WU8kl9l7sKZel48txiAfLK1dF2\nZARtpW5U9BpJALcRWiT79RGjcFcvMtDVYWghxjJc60n7Yo8ZgSz7Byj9ojylVD0B\nrT98Beuj5bVjTkr76JkIlbMHTcK8v+cfGCclIYQNophdWeUbLWePX4wp4gZUv5sb\nJiBEw4gweC/O5stXiP3XryrOCI40YkdpN4pdmcnyBCu2UKGjwOV/gXa05GjlayH7\nT5Oiy+1G35UZEEa+9KVvjwaOYsr2AmJD5j6vLbxpl8AtHqRq4eY37dFfN5Ks0qAe\nHNptnC+8MfwaMd0dJTlwC5M2LFRgR2v4E1I9wD1xONUvJfHsVP6qp4+IDIvGr/2Q\n0J0PYO7CJHIKi/7RuerE76OKaJ7Dc4jY8KEf7kHNKlDCO7RHM4YyMb7LEyRz2VzI\nyoJoVIff0S0Vr92Ui3TokraC+1ZeM08Dl5nTn4/k9zqDxz14iBCGuUzO1K8XG6xj\nxRZPePnjZr1g/kSiQVfk2T9G4xr2PMtgy8WAW9MfSIObr5IjFYDYp5B2Tsna0tZK\neZYBZS4Xer0Ou2ygyRBfDud5iIXowK0EuKSGUmNtR8gdFSQG5LMnc5/igKKcXz7q\nW4LX4AdQ0S2goRIKGV/7+hX/YOashZ0OC+OGGqzSsk8zuWWAwuACfI8tvFQpZ5N8\n2kJStaFmwI/f3GNJKOeBo7vluKqdRKh5UTutejmPSMmtOKZWpSWtYMItsb3MptGY\n9qeSUsWsQedbLn269MTW6CPXEa871dXtMHGwvHcrTZLKetEjg7/jftQrMgnbFAMk\nTpd70cV3EW5hiUbLAOmQjX63KCvbZpjcpHA8FphBWfJt9vTA9MDxElhE9IVSjtkM\npWo=\n-----END ENCRYPTED PRIVATE KEY-----",
        ),

        'alpha-bob-3' => OpenXPKI::Test::CertHelper::Database::Cert->new(
            label => 'ALPHA Client Bob 3',
            name => 'alpha-bob-3',
            db => {
                authority_key_identifier => '7C:C0:F0:D4:83:F9:BF:97:8A:3C:55:F5:4A:F6:89:0F:00:2B:EC:0F',
                cert_key => '20',
                data => "-----BEGIN CERTIFICATE-----\nMIIDgjCCAmqgAwIBAgIBFDANBgkqhkiG9w0BAQsFADBbMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGzAZBgNVBAMMEkFMUEhBIFNpZ25pbmcgQ0EgMzAiGA8yMTAwMDEwMTAwMDAwMFoY\nDzIxMDUwMTMxMjM1OTU5WjBbMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZIm\niZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxGzAZBgNVBAMMEkFMUEhB\nIENsaWVudCBCb2IgMzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANKQ\nsVovuBKlRlT9Qzg6rCaMCm45D/4NwtZP2VqnWZ9Y5m+/ho/iq3U/TWV0JsqcWPFL\nz3bzQf7e18lXqu51RsnE/xEj8t2x9hz8X7MAAY2LOTz7zKyG/nFM9yPDZe96aT2o\nulx+VKueZrWxjvaoxY9SM0BN7fgSf7oTxsdpauylswVrmttPleblssob1e5KVyMk\n5LgO+6pLs1rWdCpsFeWMyAYawAtcSlTtLvb6CEytLAvpP+54495b2CGX2ZQIAMb6\nV3NxOrRdnfs6fSsR7nc3fX9zMCTL++yVqDWwWWA4Cm0dwnV5R/8h1DMBbIftSGaV\naxq46iKTj0H/Z2OmI6MCAwEAAaNNMEswCQYDVR0TBAIwADAdBgNVHQ4EFgQUMYp4\n1835xD17eCRq2HL3nub22sAwHwYDVR0jBBgwFoAUfMDw1IP5v5eKPFX1SvaJDwAr\n7A8wDQYJKoZIhvcNAQELBQADggEBAETKdV8XwL3fN/X7tUnSBT4EqqkzZZUivjxb\nkn9lsffubbYZfdvuQzAdOSmtxNXN3HGP0CeYdE66l92ZWdCJjvEVJnMAzb348+0T\nb5ESzjbh5bADZmf9NJmtbZ3OMt1iENplMVnkUvnyqNiAX9DNPjCeXOR0xFXCXCA5\nbJ0C4DdKFO99Mg6MrZg+Mz4cbPArT+AVBlL4y2vFrgyUdaHmlK76u3okz10dKpeV\nyh7nyAM7teQyGoVXhL5p73F1IYGkBlK76WeVFUTpXUbjjGBgrpsQwbKEmlKsOLgn\n2++S+ds/tbA5ajTf7HOqQmwgAeFAACrjyj4ZJO3U0RwUP146aIA=\n-----END CERTIFICATE-----",
                hold_instruction_code => undef,
                identifier => 'dqCcAJelpwr8e-sxN3ODBy8id_k',
                invalidity_time => undef,
                issuer_dn => 'CN=ALPHA Signing CA 3,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'q-yWkovtKUUH60U0_O-mjr54cBs',
                notafter => '4262889599', # 2105-01-31T23:59:59
                notbefore => '4102444800', # 2100-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:d2:90:b1:5a:2f:b8:12:a5:46:54:fd:43:38:3a:\n    ac:26:8c:0a:6e:39:0f:fe:0d:c2:d6:4f:d9:5a:a7:\n    59:9f:58:e6:6f:bf:86:8f:e2:ab:75:3f:4d:65:74:\n    26:ca:9c:58:f1:4b:cf:76:f3:41:fe:de:d7:c9:57:\n    aa:ee:75:46:c9:c4:ff:11:23:f2:dd:b1:f6:1c:fc:\n    5f:b3:00:01:8d:8b:39:3c:fb:cc:ac:86:fe:71:4c:\n    f7:23:c3:65:ef:7a:69:3d:a8:ba:5c:7e:54:ab:9e:\n    66:b5:b1:8e:f6:a8:c5:8f:52:33:40:4d:ed:f8:12:\n    7f:ba:13:c6:c7:69:6a:ec:a5:b3:05:6b:9a:db:4f:\n    95:e6:e5:b2:ca:1b:d5:ee:4a:57:23:24:e4:b8:0e:\n    fb:aa:4b:b3:5a:d6:74:2a:6c:15:e5:8c:c8:06:1a:\n    c0:0b:5c:4a:54:ed:2e:f6:fa:08:4c:ad:2c:0b:e9:\n    3f:ee:78:e3:de:5b:d8:21:97:d9:94:08:00:c6:fa:\n    57:73:71:3a:b4:5d:9d:fb:3a:7d:2b:11:ee:77:37:\n    7d:7f:73:30:24:cb:fb:ec:95:a8:35:b0:59:60:38:\n    0a:6d:1d:c2:75:79:47:ff:21:d4:33:01:6c:87:ed:\n    48:66:95:6b:1a:b8:ea:22:93:8f:41:ff:67:63:a6:\n    23:a3\nExponent: 65537 (0x10001)\n",
                reason_code => undef,
                req_key => undef,
                revocation_time => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA Client Bob 3,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '31:8A:78:D7:CD:F9:C4:3D:7B:78:24:6A:D8:72:F7:9E:E6:F6:DA:C0',
            },
            db_alias => {
                alias => 'alpha-bob-3',
                generation => undef,
                group_id => undef,
            },
            private_key => "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFDjBABgkqhkiG9w0BBQ0wMzAbBgkqhkiG9w0BBQwwDgQItmCNpYnYAuoCAggA\nMBQGCCqGSIb3DQMHBAhYdr+g2+rQIQSCBMgQqb2tEe5yLbRsMPTnhuHFsVYxW2/O\n1sa7gOWG3YGo/Dgl2LFK3JrP3wxQ0YXR6k/JopYoT8X/23h71Tuvb6NdcsJFvLIa\nG6sk6EsFJG4wZZE3lwor1Ql67evIq0vV6mDLj+FGYJURSYVyLAZIs+f/kcglzdi+\ndPN2xqVa+eSVOK2K2E6hcyu4TznzXj1p8Urps//jMSPw9b/wSY1sUPKSiFLioy+H\nRmSAFbWGzfaNAHl5gbuSdyqaPjfKpQBeKIUtVxuR5ZUa0oBkgmWOs3p9iOCInExq\nBFZAwUA30NYoo45Yv/NaCYauVLP2J+qpaj10oJNy3nfLU+vRpUNooJt5Y4SPf6FK\nbmxPNbco7SHZ6NSP+PefwkjWAt0g7WJL3h2eC1xQO6SZ3Sj6hASMQASeL8aCv4n8\nARA4wUB3dt1N0ypNPpTQUDH0ZMoBkpXSeTnDpN7zuoK+Xodpgzxzmm+tPYaEFU/9\nYdGMBU6yhRYo8xaX9T/1Ym5515NB3KIRP67eq0y43x2neFZUlRHL5ej38RNQ6zaK\njql/8wF8ZmEQs1MhlYokY6vjoZ6C2HTpUKZxvHYjuZDMhOZ2lPrV2aMhBIpkE3lR\n6wAMewvRFbjXeBmZugV15rxPs5DxksVw3lh2tAb06+oo+ZEwHdjmueJ16sQWlp+j\nghBvZK72kGkfqo4IbOHbdffX7tgvrxyqfcznZYwTUwc9Ap9LE1IpyHY0t/+9cR7W\nbDZV7KB949meP03By3tA38aEgzYri+r0MPkJMU3DJkWg8nvjHPs5CGXDgf5QZ2jD\niJ2i28/Xja3HSVYvNYk3/K7MUF4vz2CL5hKpulcQpBlts/zOhypsR+YPqnW8N8tt\nK3dQSRB+qx1+s5CFTEUQVXirA7toANHmMML7d3fbOoqFgttKa/Y64ZI0Tw+NeoDj\nLB4c1aENYTgngtyqrdnSmgRvwO/oZJ2B/gk0RoVzqs0b5cktf3sMLP4P8eZ6bMSS\nWtvpJjkIZkptupAORvLNMPQAtDUAEHVmy+5o/DqM28KYERqaZTdYmS9JWsGj9kPh\no9oLuAOaXPVXHijK/AJXO+08NMpykWSEp0RCXXf8752YjTAtxKaXBfQJiiQj9bTS\nnIiwdCZ56oMb4oMYjyd2Kc7m14BUyILpkAnVefjVUpnHNsR2Z/R07Pvf2aeurKuR\nALWm8pkl8+JVEj7EX84OZ3UDm3w2dO2AVe82duTel7rfN4PNeujRhc8Dl23ORD44\nwNBpNOV9OQrSQh0VlVtzOytSqAdYMcLunJklDQ8fxyK5Yl9E46g+AAoBtO86D1nJ\nF5IgvgCNpEVlaSF56CO9fyiH4krAqz81mR6vhdVJsLO2Iby9WvjRV1inkGwXzfdV\nrvSD/I9yJ7skZtWsKGrRd+9R7xAuIO/p2kzEcozRVEJ++5f+ecAL6vqIrIcjmM6H\ndUNul7tZ5Hj752ZDWdO6ZvM8BLTPXc48zTypb5/BB+KOGEjnT51iyIPd+nYtfQKU\nGVTHyqHaRr63sCSWVphsBEQoK3gtGpZfmYOF6wU4gdnHZ41bKITmzSHo0ZAoY1HW\n800BHzdTwGQsGh7sbdeF2BdJjqFRthxItPmOD6oY6DgCWLhPvAuisZveCLKnNXgO\n29M=\n-----END ENCRYPTED PRIVATE KEY-----",
        ),

        'alpha-christine-2' => OpenXPKI::Test::CertHelper::Database::Cert->new(
            label => 'ALPHA Client Christine 2',
            name => 'alpha-christine-2',
            db => {
                authority_key_identifier => '25:95:E3:C5:91:78:17:06:C6:36:B4:62:8E:10:69:E3:56:3D:6C:2C',
                cert_key => '13',
                data => "-----BEGIN CERTIFICATE-----\nMIIDiDCCAnCgAwIBAgIBDTANBgkqhkiG9w0BAQsFADBbMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGzAZBgNVBAMMEkFMUEhBIFNpZ25pbmcgQ0EgMjAiGA8yMDA3MDEwMTAwMDAwMFoY\nDzIxMDAwMTMxMjM1OTU5WjBhMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZIm\niZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxITAfBgNVBAMMGEFMUEhB\nIENsaWVudCBDaHJpc3RpbmUgMjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoC\nggEBAOPx2f7EGM7IS1A7jJC9lR/oSr/zdrrgZjtDYDnTEX/EP5QF28vaURAv+8Nd\ng0RWP6Tlq0b5n+GviOFlRZSp3o+QVvkitt0c4qry0BYrwGMb9tuliMWmi3MQPQZ0\ni2XTvUbyuB3GnJca1JNFbmgOhiIYsDSL8leyOuPhQX0ZWZr1msm0xPL7Dku5M0Uz\nNVkmkRZbpP/SN2Rrpoxp2BNPGWh+ot5RC7pElELwtJSJRBrX+TrNvuMoB948iJ9+\nzq3yv3PUQtnNDuXfqXpgdhTpszHIBV2JtFW2K4ds+q40gfqwX2pP0JdeJmyFs+tQ\nvLvOM6yFWwcSAat6jPjRRwV4Rl8CAwEAAaNNMEswCQYDVR0TBAIwADAdBgNVHQ4E\nFgQU/B+msQ51pSvmmGw/9bG451/YWyEwHwYDVR0jBBgwFoAUJZXjxZF4FwbGNrRi\njhBp41Y9bCwwDQYJKoZIhvcNAQELBQADggEBAHl2V4gMg9eTwjBNV6ID/AVXIvOr\njHDNaeCRWzAwPlBwOmQrMZOr+JAo0+h9uv6Wyz2qA8p39pzBDQtwFKpewY73XGaA\nf2ZAErx/zj+DEE22Zk6s6o1EKZOWS8tYKPmon3CeT5fLmUwzVLA8AjqlKdlnJMLs\nKdMr2DRAyqieQJWWB7kyjo1rE82GqlN1ICrgsws6Ryr4sddeHjOp8I5EeTenVroT\nq1X62GecI1M2+ssqUEwsBWEsq7g0S3s2rqBakueaoVVLHzDhn1UzXkISSTC7zpWz\nN8VjsHqF1p+e6v3SkUVzQDcXgUNR8FFpb9dYCkVbFuKdeAX22D2G+9dFlK8=\n-----END CERTIFICATE-----",
                hold_instruction_code => undef,
                identifier => 'YJyCewVRD_1LGdMD0_RIY-S_rvc',
                invalidity_time => undef,
                issuer_dn => 'CN=ALPHA Signing CA 2,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'zbwY62EfQRkBZ4bw-gUdZeHsCwE',
                notafter => '4105123199', # 2100-01-31T23:59:59
                notbefore => '1167609600', # 2007-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:e3:f1:d9:fe:c4:18:ce:c8:4b:50:3b:8c:90:bd:\n    95:1f:e8:4a:bf:f3:76:ba:e0:66:3b:43:60:39:d3:\n    11:7f:c4:3f:94:05:db:cb:da:51:10:2f:fb:c3:5d:\n    83:44:56:3f:a4:e5:ab:46:f9:9f:e1:af:88:e1:65:\n    45:94:a9:de:8f:90:56:f9:22:b6:dd:1c:e2:aa:f2:\n    d0:16:2b:c0:63:1b:f6:db:a5:88:c5:a6:8b:73:10:\n    3d:06:74:8b:65:d3:bd:46:f2:b8:1d:c6:9c:97:1a:\n    d4:93:45:6e:68:0e:86:22:18:b0:34:8b:f2:57:b2:\n    3a:e3:e1:41:7d:19:59:9a:f5:9a:c9:b4:c4:f2:fb:\n    0e:4b:b9:33:45:33:35:59:26:91:16:5b:a4:ff:d2:\n    37:64:6b:a6:8c:69:d8:13:4f:19:68:7e:a2:de:51:\n    0b:ba:44:94:42:f0:b4:94:89:44:1a:d7:f9:3a:cd:\n    be:e3:28:07:de:3c:88:9f:7e:ce:ad:f2:bf:73:d4:\n    42:d9:cd:0e:e5:df:a9:7a:60:76:14:e9:b3:31:c8:\n    05:5d:89:b4:55:b6:2b:87:6c:fa:ae:34:81:fa:b0:\n    5f:6a:4f:d0:97:5e:26:6c:85:b3:eb:50:bc:bb:ce:\n    33:ac:85:5b:07:12:01:ab:7a:8c:f8:d1:47:05:78:\n    46:5f\nExponent: 65537 (0x10001)\n",
                reason_code => undef,
                req_key => undef,
                revocation_time => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA Client Christine 2,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => 'FC:1F:A6:B1:0E:75:A5:2B:E6:98:6C:3F:F5:B1:B8:E7:5F:D8:5B:21',
            },
            db_alias => {
                alias => 'alpha-christine-2',
                generation => undef,
                group_id => undef,
            },
            private_key => "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFDjBABgkqhkiG9w0BBQ0wMzAbBgkqhkiG9w0BBQwwDgQIoimgQF8U+BQCAggA\nMBQGCCqGSIb3DQMHBAhFypRjunZ8dgSCBMg/b4uiKNQv+cfxJdV7mP6vfXJxwOhh\nmgqLaysgbp6yUK+sb34vYpU95cb19aoHK/PJ+UWHLGF4vNQeBZv4llVTLn75pZF4\nztsDycz4gBXhSwOTi4KrTptuEy2YYsj6Adn62DYjJLT+PPE2QdASQK0zOvF8vozN\nVyuFUYHjlveKHlwfndyYrEm5nDxfiDcLWd42mjKE7Z5piBKwoXnBqFkSAAnGaC1c\nCcqYRZHfA6c50UEpPq11Df2dgP4TiakbONORKH3N9swRllGbaCKjjlAtIdToPu82\nqBCMs4KCv8DZCn/czMWw6gchgXcrg6NSTSkpeAtO5EJsLmz/V+5gOQQ57srDfTmn\nOqz2jaD7dV9d8WdCmUSbfgrGy8KhTNzMNkcVFFkoGV9nrm6mWBTp0zt8Sq/MLJ5G\nmuF7lWEb3+65FYRKdcbffBvf+0uxKrr+nIJ4Xy+yWlPZ3MGkRVllm3Ry3cXRi8m+\nF90DfL0AnilCykoOU3PngmEUqqPMwUlze2X1a8JQIAIZgvGiJ+7/VQ42jScSn+TD\n7yIk+tTDxobUwsLVoR/6haaum1h3mJrSmL3LsMAUXELPBNVPdvQMcLEF04Ful39F\nNofz9TtmDpbUidNiNK8QsVyYnwXN4GCthdSjvNz7nz3BM6CM/YcVKIfCfFnvxyI6\nfIt/LJzdEh0atuRvQFtDli2B8im1WDHute6d4OGAhlukTf6YKQFBKRHkIeA/rdef\n9nRmmAR/Zo/c1XVvplGi/pDd6juUTJl8b927g4wyhPawSxQYJobQXZ4G3J0k5Mnf\nI+VFmtmOKV6rQHsYgsXRrSG2oMAsm7TD72RrMwcrZknQYjfTAGa6AcIdaah5vX7F\n+mCKyE23kz3cJgrBC8A5RqwaMNuQ/eXcezWufP4ANvBJljWWg+sgjV/t9WTeFw5E\nykBnY89ye+2YG5o+BuIukDvh9yGMPoHfMlRC1Hl+KDTDqS6rM1a1cRgAQGaaBooY\n1ClyxFWHSluS0LGcc6yRHvbGU41bCuRCGU5DcndX4MBQLHvv3pedGEvpbbs6cIkT\nr75MJDZci3604yba03PSaHdBdDdq7woBK5AAyKbSpx8m90lDA0zktb7FgLLDK6IJ\nbpPjLXF2B59uAMQHcaeZaf7pz/zNdkTCD9WnQ7mkP2DpOqHo+CnrYJJbOGcNlPtI\nbqhMaHpD+g2L/2NjeSIvt1SL2mDyS3sbNTvWFbGu0sawuRpNbNjvDh1RV+zEmdtJ\nIb0O/iwmsoGPEx9X5l+Xtqll/M96UQxk4fTIJh00p8rBVGVGmkZz/cYFtDfb8+2c\nfFAp+/VFUboWZemiEU/fJtKeZY5fIXhgUQppjr/nGH92XiTbka5Ns5G8ASX0DS0C\n8GX2Zsu87iXHlVx/L29yk3E9x6qHk1CKjVwg0EFvFsA1IEYyui5tnJgRG+CuHWE+\nbP+6CswjfYypDgS8mgQ0muFrTkrhARxXMWsl1WhdUCsw7VqL0uha3jPYXqP8bFK7\n5ht7K8Ri0aED45qq7a8i4a0pc7KnylNRAtXuazAIdvgx7t/ZooOhTwncfL3wlNbe\nzrpiV/1stU5LrARPAXSxyVJylMioAqLUVF08pxJvpt/ZtwD0QLotDGxKlyLxrYID\n1Fw=\n-----END ENCRYPTED PRIVATE KEY-----",
        ),

        'alpha-datavault-1' => OpenXPKI::Test::CertHelper::Database::Cert->new(
            label => 'ALPHA DataVault 1',
            name => 'alpha-datavault-1',
            db => {
                authority_key_identifier => '9B:23:15:05:EE:8F:19:EB:54:4E:85:22:5B:73:4D:D6:B5:9B:D8:84',
                cert_key => '1',
                data => "-----BEGIN CERTIFICATE-----\nMIIDojCCAoqgAwIBAgIBATANBgkqhkiG9w0BAQsFADBaMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGjAYBgNVBAMMEUFMUEhBIERhdGFWYXVsdCAxMCIYDzIwMDYwMTAxMDAwMDAwWhgP\nMjAwNzAxMzEyMzU5NTlaMFoxEzARBgoJkiaJk/IsZAEZFgNPUkcxGDAWBgoJkiaJ\nk/IsZAEZFghPcGVuWFBLSTENMAsGA1UECwwEQUNNRTEaMBgGA1UEAwwRQUxQSEEg\nRGF0YVZhdWx0IDEwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDNJiUN\nN9On6sksf/o6rfIEVgZVGgup+NouNVkMkmjUDNiujRLC4+T4/qT3BdPozlLeLidl\nhhpi0ThywoUbL2kbDtQeTMcuZTu2/B90Sz3Yy/crhvuHZFyi+QHDhNAK3mR0mhG/\nSP9jvShSa3u5W6OmIGI86YF1LHOKDgnZr8X0XER1kWxPKqyg/GvU++F3ndGDC5sG\nAtvyHwzk3zvHTqjPKcgSNunO73rdCbqq60AKjio5e2VaTUssjldyQfmaiR0pl/cL\ncnUk+9uW843bunpfjyl8QCNPonF8wMPzNqKWBbzUlpbqdIcbsmmfFg/NweagtoJA\nt2FUb5PvptJfTKZnAgMBAAGjbzBtMAkGA1UdEwQCMAAwHQYDVR0OBBYEFJsjFQXu\njxnrVE6FIltzTda1m9iEMB8GA1UdIwQYMBaAFJsjFQXujxnrVE6FIltzTda1m9iE\nMAsGA1UdDwQEAwIFIDATBgNVHSUEDDAKBggrBgEFBQcDBDANBgkqhkiG9w0BAQsF\nAAOCAQEAbfb9YdmxcgHimUg+bzCXUUNE6dA6VrBwzD8eLJDMN5yNzb/X2aS0suGA\n2LXsnZfbN1LrIeA9dHr906bC9cZSIYa6M/n7dAVGBkHl7yKyAUrdrDxpawNreRBO\nPzU9wvGDEivusQEfeYBq0vtC3eUYD3eZFuIXXzQwRwIC91WZzAojmKfUspobVcvN\nZDhD4NzZem4gNEcrVbHOQIMFPRXWZGQOrDNEwKz8lHZ6soDQAaoocNr5VwIZ5rRG\nZtI9fqYBGYdDwIDKuutK8lJNa5GoV1JDZLkvPmDGs09D+SKUegSomx+9TIPb1b+D\nMs36XvJatMeliM9pld52sCYA5Om54g==\n-----END CERTIFICATE-----",
                hold_instruction_code => undef,
                identifier => 'BHX-aODPyQZVGSHK9UUo7tkIIDs',
                invalidity_time => undef,
                issuer_dn => 'CN=ALPHA DataVault 1,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'BHX-aODPyQZVGSHK9UUo7tkIIDs',
                notafter => '1170287999', # 2007-01-31T23:59:59
                notbefore => '1136073600', # 2006-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:cd:26:25:0d:37:d3:a7:ea:c9:2c:7f:fa:3a:ad:\n    f2:04:56:06:55:1a:0b:a9:f8:da:2e:35:59:0c:92:\n    68:d4:0c:d8:ae:8d:12:c2:e3:e4:f8:fe:a4:f7:05:\n    d3:e8:ce:52:de:2e:27:65:86:1a:62:d1:38:72:c2:\n    85:1b:2f:69:1b:0e:d4:1e:4c:c7:2e:65:3b:b6:fc:\n    1f:74:4b:3d:d8:cb:f7:2b:86:fb:87:64:5c:a2:f9:\n    01:c3:84:d0:0a:de:64:74:9a:11:bf:48:ff:63:bd:\n    28:52:6b:7b:b9:5b:a3:a6:20:62:3c:e9:81:75:2c:\n    73:8a:0e:09:d9:af:c5:f4:5c:44:75:91:6c:4f:2a:\n    ac:a0:fc:6b:d4:fb:e1:77:9d:d1:83:0b:9b:06:02:\n    db:f2:1f:0c:e4:df:3b:c7:4e:a8:cf:29:c8:12:36:\n    e9:ce:ef:7a:dd:09:ba:aa:eb:40:0a:8e:2a:39:7b:\n    65:5a:4d:4b:2c:8e:57:72:41:f9:9a:89:1d:29:97:\n    f7:0b:72:75:24:fb:db:96:f3:8d:db:ba:7a:5f:8f:\n    29:7c:40:23:4f:a2:71:7c:c0:c3:f3:36:a2:96:05:\n    bc:d4:96:96:ea:74:87:1b:b2:69:9f:16:0f:cd:c1:\n    e6:a0:b6:82:40:b7:61:54:6f:93:ef:a6:d2:5f:4c:\n    a6:67\nExponent: 65537 (0x10001)\n",
                reason_code => undef,
                req_key => undef,
                revocation_time => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA DataVault 1,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '9B:23:15:05:EE:8F:19:EB:54:4E:85:22:5B:73:4D:D6:B5:9B:D8:84',
            },
            db_alias => {
                alias => 'alpha-datavault-1',
                generation => '1',
                group_id => 'alpha-datavault',
            },
            private_key => "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFBjBABgkqhkiG9w0BBQ0wMzAbBgkqhkiG9w0BBQwwDgQILI/3wcrM9vECAggA\nMBQGCCqGSIb3DQMHBAjnLTYRUQ/9IgSCBMCYVxZjEKAsrDJ8DN2yzPuTZ0L+KKVK\nOZHNKDWTZ/G8isDPre5sp5KSlyPrqZne5zEcM5F4IwYAVagBcVrw6i3pmR3yMA9/\nGwiCM2AxJat4qO55JqlG9M+cVO5iypu4EoM0czT4V9UAtiHaOulPLiIYYfGdAFvk\nsH6oFyQ0s9yV+ZrR8SJoVQB89OtvXDYm3Chsb/WiI5LnVu6zY6p1iGZxxizOts66\nVYutbwMV8UFw3vEbCCt+uNzfKyw7tSEh5AJEPMjkecJIdJ9TBUyRmc5cEcPVIgUK\nKMZjX6vxDGZx3sRK7Zk/auhBijHkS1gyGxB5QBM+eNRY2LS2+mz7U6tBYOTxj3Io\n+2ZyShQjaXq2NobBxF1yURhJ556fFv9WsRVCgycIOxY2AOpzwvQkTikoJfbmqXOH\na0itQ37uBpTsFbu+TyDYGhSv1PxJmJ7i7zvmvJyejAb9+CKhQXIJLkjSxNJMC1CI\nUDS1EeVJfhUr4HgIPwi9kjSnsZvXqKNKgvnTs7D2NtSQYL07MajiltUmrCGThlcm\nVxIEcM//EkXODueXGJV13zj5Kryses2ejzpV5IDWCdJTaEaZW1Aekvgzl6fEhm1r\nJHuRKg2P4sutatDuxv26Ds/A3pIhA/Uo8YvKexL3U0ZITYx4gwOWz3hFD+Gq5/AC\nX4WjLFDPjVCsQFEyUbLAZE1QK8jtA8wGoyKbSc45M55zcr0GdgtzPsaL4mqjLxNe\nRIsMFFNBl6NVeaKEx8D78ibRvZgSs5MXhNwljGEfStvbhz6+6lmH6xNBfuFtQ8a6\nSKxw2dsu6me3gFmHS24SsFKn7/BxPx/VC7oHpnhcS55+uuwn41eFsg1mkyUNxnDb\ndCmemkF3Cp77+PImz86ahAZmlzapnixZVHhGzRwi7J5vo+d0QfrtrQvAN4IhSx70\nIMVfrfQ7iwpbrbIxYNxpIUE4tuZjTkgOC1AAlG5K7XEsq/Y3vrv0FixG5QPUNPsz\nLV8H7nInsNwhxFx1OvEp6DR5zat0TLTp+H540/fAjgLm+pPyJFBoXsmqGny1GI/s\nFpeNh99UGRjLZu6PycyuLUHk02Lqp6S+bEaCH0I8z/SPE5Ks2pHN9BcKGWEDMZre\nw8xA1tEJTuPZW2W9hMWzs+roRnlWSi8KHZUki9dI1JiK927f0p+Pv++8gZrZEFpX\nd+KwO4tgmELSuyqPpYNuUuEoqA7/SyGBzkfXZFvyyEuK97JdtF19CsarqDzRJVM2\nVRo2CdjxMEDM1cZ6brFM5tM08moVubD7M/Fey1n6NQ/XGz/Tz8lwhM41NvtaopQD\nGUzlk8n/HGxc/8GnXuQAS/mffTlXyj+0ymWYZgyq8Lr7OTn2FfjXNOJS8h6eIg8s\nyZIrsTGzedGL5qcKF3Hep1Mxa4i/l0/l3FqRBeHQn0gBQw7aBtQ4FkY/DsEoE0GP\ndVpYv3rs8CWQCp+x2yd0p0WpS3/dR7u1sE9XFxVuSg9sLMoR+1KVESnJ2+w/K86E\nXOh8sWUMdxeOOwSX3exLz5/FgKDaKABK7McW9DQYYq54KE7S269SkY4zN7AM+Irt\nj9edv+O46eQVbPvgQ1Qak/8DUQw+8aML14ue3nn38wUTa6DUCxBhH6iv\n-----END ENCRYPTED PRIVATE KEY-----",
        ),

        'alpha-datavault-2' => OpenXPKI::Test::CertHelper::Database::Cert->new(
            label => 'ALPHA DataVault 2',
            name => 'alpha-datavault-2',
            db => {
                authority_key_identifier => '11:31:75:10:77:E5:13:0D:F9:ED:97:BA:87:F4:6C:42:C8:34:94:D1',
                cert_key => '7',
                data => "-----BEGIN CERTIFICATE-----\nMIIDojCCAoqgAwIBAgIBBzANBgkqhkiG9w0BAQsFADBaMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGjAYBgNVBAMMEUFMUEhBIERhdGFWYXVsdCAyMCIYDzIwMDcwMTAxMDAwMDAwWhgP\nMjEwMDAxMzEyMzU5NTlaMFoxEzARBgoJkiaJk/IsZAEZFgNPUkcxGDAWBgoJkiaJ\nk/IsZAEZFghPcGVuWFBLSTENMAsGA1UECwwEQUNNRTEaMBgGA1UEAwwRQUxQSEEg\nRGF0YVZhdWx0IDIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCw3FPC\nKbInXrMvFKDBGCeZp6wTMBNpEQxIEWRSSds7mSjgRkNduMmjIJb8PypsVp/74lQS\nAJk7BwDTDvG0BKEHk6C50igEP6RZdbpVgOMhYYi2pXabKiiifYfXn/GSEDWNTrfC\nz+j7th4y9hNfM586cpPdJZa1iNZiyRvnJk/mOY32uk4B4STQoLV6hiRp/wl5K4JM\nrypM42fF5//O1u1nb46tClw89k5RGdMAQigY6P1iaXIq2NguqPeuvFNGA8WnbfMn\n3UEnuZVcpCiedgMV0+p71QAIC+QuBc2BlxFRHE9w6JTfqttCvpud9hxQaEsiCvmN\nwTHsJZrggKQC6567AgMBAAGjbzBtMAkGA1UdEwQCMAAwHQYDVR0OBBYEFBExdRB3\n5RMN+e2Xuof0bELINJTRMB8GA1UdIwQYMBaAFBExdRB35RMN+e2Xuof0bELINJTR\nMAsGA1UdDwQEAwIFIDATBgNVHSUEDDAKBggrBgEFBQcDBDANBgkqhkiG9w0BAQsF\nAAOCAQEAZ8AeNZdMmhNjXDLTbZQVbDjWndB7Bd2xTzcU8xGEfVL8sON5j8FlY9Ae\nU0j03BFNu9t3ZYXyAgPPh30qcZEcukkjFrbR9WRlp+lM4AZNzim7ae/0F6WhEXv/\nnzBbUizOfXGKLT4WdPN70zx7MuOCuSO6avkxRnizBBfNxsP5MfGS+pOTp6kXdtss\n/SIg55tOm9njMCNa9js5U07tl4bU3z5uHtIZrZiCoH7r5HsYQ/gfdoZCIFJkrv84\npif3zHA/hdES0A9Ptp4YfqWENtWkAiPwj56zpvqw/KsphjDkD7v3XaknIwqYanVZ\n0viQTipZeHAs27b1nyI/ntZ8HtUWiA==\n-----END CERTIFICATE-----",
                hold_instruction_code => undef,
                identifier => '8W2g-IdAeC1TUzgDi3_pz8x96RY',
                invalidity_time => undef,
                issuer_dn => 'CN=ALPHA DataVault 2,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => '8W2g-IdAeC1TUzgDi3_pz8x96RY',
                notafter => '4105123199', # 2100-01-31T23:59:59
                notbefore => '1167609600', # 2007-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:b0:dc:53:c2:29:b2:27:5e:b3:2f:14:a0:c1:18:\n    27:99:a7:ac:13:30:13:69:11:0c:48:11:64:52:49:\n    db:3b:99:28:e0:46:43:5d:b8:c9:a3:20:96:fc:3f:\n    2a:6c:56:9f:fb:e2:54:12:00:99:3b:07:00:d3:0e:\n    f1:b4:04:a1:07:93:a0:b9:d2:28:04:3f:a4:59:75:\n    ba:55:80:e3:21:61:88:b6:a5:76:9b:2a:28:a2:7d:\n    87:d7:9f:f1:92:10:35:8d:4e:b7:c2:cf:e8:fb:b6:\n    1e:32:f6:13:5f:33:9f:3a:72:93:dd:25:96:b5:88:\n    d6:62:c9:1b:e7:26:4f:e6:39:8d:f6:ba:4e:01:e1:\n    24:d0:a0:b5:7a:86:24:69:ff:09:79:2b:82:4c:af:\n    2a:4c:e3:67:c5:e7:ff:ce:d6:ed:67:6f:8e:ad:0a:\n    5c:3c:f6:4e:51:19:d3:00:42:28:18:e8:fd:62:69:\n    72:2a:d8:d8:2e:a8:f7:ae:bc:53:46:03:c5:a7:6d:\n    f3:27:dd:41:27:b9:95:5c:a4:28:9e:76:03:15:d3:\n    ea:7b:d5:00:08:0b:e4:2e:05:cd:81:97:11:51:1c:\n    4f:70:e8:94:df:aa:db:42:be:9b:9d:f6:1c:50:68:\n    4b:22:0a:f9:8d:c1:31:ec:25:9a:e0:80:a4:02:eb:\n    9e:bb\nExponent: 65537 (0x10001)\n",
                reason_code => undef,
                req_key => undef,
                revocation_time => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA DataVault 2,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '11:31:75:10:77:E5:13:0D:F9:ED:97:BA:87:F4:6C:42:C8:34:94:D1',
            },
            db_alias => {
                alias => 'alpha-datavault-2',
                generation => '2',
                group_id => 'alpha-datavault',
            },
            private_key => "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFDjBABgkqhkiG9w0BBQ0wMzAbBgkqhkiG9w0BBQwwDgQIFmeob7h5CTACAggA\nMBQGCCqGSIb3DQMHBAiL/WkMZKlOiQSCBMhYBKZQ1un8C1GL/iDP+VAYwLQ86her\nBlrdyDutfo/Mto7pXaabPKHAmAmQH89amC61nyOjlcSEwwdzePQCngw7RUA9ci/z\nCna8enNoQ9p+yXpGxllNedmfm27jCK9b7T9Q8jD55CHr+Eq5vcTnBaEDu6eE6bQC\nN0c3AzpQpXI7XHvhHjFKcCbENe6rYrA4rzpUaeEL8T/jZljDd7p2Y6qDLU3SAcDW\nv4a+tk52MQA6CgihGXKPBVG2c5iPQkXHWq3XMaepkRrfM9p1ii4LFyAUntKhimd+\nstN7ED9IuqO8Wk7mIBHYopxLgwFHktV7G7g7cnz7iQqXigm+Fry3Zd/PFy6e69/0\n6KcRxDf9QOR9ZJ3kTt5HBYM3ahOKwa+MNmqPKUvin9s9M4rBX9EE0+PCPqnSWIAG\neDj3NwauGGSW9OALxP18ETkvaKclvI/YnoH4hq6WnvQNMXdHKp3kR41jBnEAWKOH\nINcKe/glNYzbqP50dnylliMELL2TMozh/vtz8deNeV2Lp2e6CXKn0oWa1SwtG6yU\nicmn2IrUDqQEaiueh1D44PTqroTVWiPte59qx3giPkRAYC8w8NFUta5p1vgIpY5W\nVHoeGRgMHlQpAj+m66LFbjRjQMAeOqWIQNpZoFdmfHo8/8vMPS/nMdLzHw54wqQH\ngMD2RqaV4uvVIetG3oXlcSySAdLbPnnHGr7WdkZxf52XN9fM9BLC4LP+9Ym3zcvM\nt1uaUebJgHgn7KYDViiYjl/8RmfuCU6ZxO86RwL2wW3c2DbuQuUtUR3Ht5dxwARv\nTjFMO7qhpuXllsXWgg/yKU5UUuLG0CRQAxBQDAXWRgGBo0bvwxiaJ0gPdkmeHXZa\nDSXCg4xaBmFP5vs4Yx+u39xu6o8VxN0sHbbIZuZKwh/XeSLmBZRvjSez8Mrhi0iS\nAzh8czxyrao9wDh5SMTPySvz9CVOcJAfJKI4RuyjPOUc+lkUNQIGym8LlV8Yc03W\nUdnjBqElf59bI1iKiR8mieKRrB29BVzQyMfzufLBPsxTD01WgRemFF60QtLWNhp6\nyls4RGqRTc5HGv8rbGFWKZZWFOgmFTZWijOnPvQkKvwWeiFLyw6mD5ab2FyI8B2M\n1KgCzPO46PRhFePbMmiByMljuudzuZJ8OSqgFhFox/0dviWDIJarhl9nzL/ty/Pg\nm2Ab1//37Y7PzjRGjkTMX0ajeQ7wF9VFwUTydfy+7u3Zt3lXszQjihmE/GIvBU0E\nKh8pvRg9zLTuTGcfKPdtHtbz6kySFHOHHO/sRJVPuoRtoTw0/wwhBSwcwLhGmvxS\nf8ajiKT7yvUu8tpYRovxHQcaWmJlfBHkge3c01HiUv91jqSP3vTFmUlbLaRWNGw9\nV/GxfP+TURMg7pauDfdvNvA2GjeCan7vpYrNAHIKjO3Kprf+ozfN3+jAwcHqNww5\nH4r/uqsV7ykz/etBjOthsGICdced8BUzAXLt9uqkpPszRSkuCRwaS6iqc1EHZ7gu\nM03Gkqr3sbcYK2tqq6koo6uBt839CpcWgKy4ZwXOwUdqI82Jj/YjaXl8fJHJRedX\nlWFWCuD2/ge7Wm39esQjNx2P4UcmcTUYrVO1bum9lQCDYyDCrjdncM3ccL2KkAiH\nB9E=\n-----END ENCRYPTED PRIVATE KEY-----",
        ),

        'alpha-datavault-3' => OpenXPKI::Test::CertHelper::Database::Cert->new(
            label => 'ALPHA DataVault 3',
            name => 'alpha-datavault-3',
            db => {
                authority_key_identifier => '14:D3:A1:FF:DD:55:5D:E2:CD:29:5F:64:C5:79:CD:4D:13:62:1E:10',
                cert_key => '15',
                data => "-----BEGIN CERTIFICATE-----\nMIIDojCCAoqgAwIBAgIBDzANBgkqhkiG9w0BAQsFADBaMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGjAYBgNVBAMMEUFMUEhBIERhdGFWYXVsdCAzMCIYDzIxMDAwMTAxMDAwMDAwWhgP\nMjEwNTAxMzEyMzU5NTlaMFoxEzARBgoJkiaJk/IsZAEZFgNPUkcxGDAWBgoJkiaJ\nk/IsZAEZFghPcGVuWFBLSTENMAsGA1UECwwEQUNNRTEaMBgGA1UEAwwRQUxQSEEg\nRGF0YVZhdWx0IDMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDTGkgW\n924D3NJYppl5Zfgk5WmjeOBKaNs3kmhnNnHVq40+BmsvHCaTHlnATLwmqORZcdPm\nU3Saw+dvVhs3DIjwtwZW4IoyYw/3Xuu5QAb1wl68kT3xifMS1tRySteIBHgmX8lO\n3wUdV7RXn0jP6E0QLecb3lrckyw7jAsSCoC0/1ESuy7bAZ34QAwkHDnkldXV9070\nSGm+O9T+vxSBrTQmkk8x2jimfB3zYlr08YvEBkYgPDFnrTYmfnHvcjN1z1kjOL9v\nJUZUjHWKWgGPQOBLZwt+IAT2ZVtzWog1ngVqNhCf1cVeo65XSlc4AlLMtZ1DgVtY\n7JV4JFRe8lVPNABtAgMBAAGjbzBtMAkGA1UdEwQCMAAwHQYDVR0OBBYEFBTTof/d\nVV3izSlfZMV5zU0TYh4QMB8GA1UdIwQYMBaAFBTTof/dVV3izSlfZMV5zU0TYh4Q\nMAsGA1UdDwQEAwIFIDATBgNVHSUEDDAKBggrBgEFBQcDBDANBgkqhkiG9w0BAQsF\nAAOCAQEAkj/K4/XGW4/3cgQi6bB6FYMljsjyjo2lced0Zmpt21xGB5WBFMVQnUBQ\nqekJ572/3N9rpEiPq1nr7mucvJWf+cclz7zlaScfcusfeP738AUJPjin/DkS5HHW\nu+j446vtmJFITUtGsyQ14pbSjpo9hGZPgKmt7rXRcnHWvWFZQqt/Fp7ln4RVjI+L\nuY5VWm9tBJL3FfADTY6hMHFKqRBmy9hqb8ntzRuj/D5gg94EKMZaEj/5KrXOD30W\nsItwIJxMVQm0ZNvIukRLXMaB3i2i99oZXuNOcHdjgEprfErrUSNvv1H6oSVJ//ef\nbbcPQG0wQfHDjsGWI+zLQXXOfUa1kw==\n-----END CERTIFICATE-----",
                hold_instruction_code => undef,
                identifier => 'lpHA10JuE1366pv3nI7wicHvt3o',
                invalidity_time => undef,
                issuer_dn => 'CN=ALPHA DataVault 3,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'lpHA10JuE1366pv3nI7wicHvt3o',
                notafter => '4262889599', # 2105-01-31T23:59:59
                notbefore => '4102444800', # 2100-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:d3:1a:48:16:f7:6e:03:dc:d2:58:a6:99:79:65:\n    f8:24:e5:69:a3:78:e0:4a:68:db:37:92:68:67:36:\n    71:d5:ab:8d:3e:06:6b:2f:1c:26:93:1e:59:c0:4c:\n    bc:26:a8:e4:59:71:d3:e6:53:74:9a:c3:e7:6f:56:\n    1b:37:0c:88:f0:b7:06:56:e0:8a:32:63:0f:f7:5e:\n    eb:b9:40:06:f5:c2:5e:bc:91:3d:f1:89:f3:12:d6:\n    d4:72:4a:d7:88:04:78:26:5f:c9:4e:df:05:1d:57:\n    b4:57:9f:48:cf:e8:4d:10:2d:e7:1b:de:5a:dc:93:\n    2c:3b:8c:0b:12:0a:80:b4:ff:51:12:bb:2e:db:01:\n    9d:f8:40:0c:24:1c:39:e4:95:d5:d5:f7:4e:f4:48:\n    69:be:3b:d4:fe:bf:14:81:ad:34:26:92:4f:31:da:\n    38:a6:7c:1d:f3:62:5a:f4:f1:8b:c4:06:46:20:3c:\n    31:67:ad:36:26:7e:71:ef:72:33:75:cf:59:23:38:\n    bf:6f:25:46:54:8c:75:8a:5a:01:8f:40:e0:4b:67:\n    0b:7e:20:04:f6:65:5b:73:5a:88:35:9e:05:6a:36:\n    10:9f:d5:c5:5e:a3:ae:57:4a:57:38:02:52:cc:b5:\n    9d:43:81:5b:58:ec:95:78:24:54:5e:f2:55:4f:34:\n    00:6d\nExponent: 65537 (0x10001)\n",
                reason_code => undef,
                req_key => undef,
                revocation_time => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA DataVault 3,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '14:D3:A1:FF:DD:55:5D:E2:CD:29:5F:64:C5:79:CD:4D:13:62:1E:10',
            },
            db_alias => {
                alias => 'alpha-datavault-3',
                generation => '3',
                group_id => 'alpha-datavault',
            },
            private_key => "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFDjBABgkqhkiG9w0BBQ0wMzAbBgkqhkiG9w0BBQwwDgQIdOFfTwYIJqMCAggA\nMBQGCCqGSIb3DQMHBAjJPLSiXc5bWgSCBMj2fV3K6a+pSI6b4/kxVjrTzB3ZvVMv\n7/5iT+jd4zeocnLIyfZFW204a9DHy/JMlySZlo3zo2aCp5fYJxouhoOBCg1gAPKh\nIeszl7XP0Cbn2/L0FKrfNTsYTw6nTR38LlOUVqqzOhhImgfvKBzLW28+k4/HGlOe\nvwi7UymEjE0vSq0df7iI7N7SLT/XQnuXuOPKmLS0ObANQ1rUmOB4qNkeXIkTatP1\nWlpELaO95k+JIBBTurVMCEK7/QnwoaF5iBZz/tOcRnlc535J5uUwB1+0+fDjFNvY\n2XdohMzvU95db3LH+NtPivZejs/obopofP2fCVtBdnr9JSAR4Jp+5XwrKwkFqKd0\nk4xOnWd7JmyPlPvYmfJu6bMwfA0nry8MysCPWm7nIFeUod9G0bZyck2JPO6jg1WZ\nzTFtFI/I1AG0U5sjENyCUaY2KEW8ZBfDTi7hICCPJnOAFKLtSS+IkJTeXEefRIma\ndDQpU2vEW6YyuOclVFK4PEr4kvCgK1/Lz2yMY95ftZckZGUfG1l/SRMQtvHkwFfP\napSyW0klfnREjfJKRAsWgl8915jiLmG8kEHljeFM/5HbTT8edhkMch2ENzMumxQS\nDmu0JerEs8abjNsBhm37r1dPrpNmjuXBeMyjXxu6pIjHOc9FECafXOeR4XEu7Ayh\n5cqt4fD3E5meu8T8Y9YB+Tl96qvlsfYSj0J3Ekz6mVdnzAN6ckdugtpr1mV2WG17\nWM15w/7cJNZblCer8jYoG+UkXjjbtu9IKdvpVvYoOH70AZiNmZZjmKyiVU1L44HU\no48QD3i6PrfQOrshYcjBALXM1pLEoBjYZ0A9LTGA/mwUJ2gd6eWHWJtAeMlTxUE9\n5/DEKZKB0xhHRxrOyImrva/FqEgi+c8J3mW2LMyZvWT3IvjIJkjYSNF6pPNK+Ei1\n/U8lfghQnDlTg74hi0lNZHPNodANem0WvvvKWDcC9c7n04iyVIOQdAl+3dBFCI3V\nqxrzoG/r6jr/XNTb83uhvfleT4W1Og4OEtHbLZtGoRMGwuw42DjXsQKL/rjA+Lg5\nlHWzgRTdeKyIVihrzFn0dO1QVxa3fdQAW7Daklw1dQGiOBJy0an0drR6YP/1K6N1\nSCfffekM0DPJIdAbxW3IINafXonVim+Tq7qXBhHtRdcK7SJ9K9+yy6+rlNpXFE1W\n2m12/xbH9/QNCcRW+zWvEXXnQ10yS6TTn5M/w4DTWFI1zRZG5aFsgzo8geXz5KUG\n3+j2+GRTEVQVvZavPtAvTLxGc5nU2VmVU9i44f5kh0IeCvufxzQ+dLHnm26Zy60b\npFyArLtDD2eFwPgvAUstywz457EbzKhvnuef76+PDSyESIgo1OSp/LuqrqSITrS+\nKOCDg+t5V51+cGSVPq8OYCzQjBo7oWxvhIUzTT34EBs4oxcm/Z6NeZZzV+vn3r6w\npKrwUKtG7o9Bp5k9KmIkH+2J+XcLlih0MC55JgTek6LkKaQUuZHOtCbo7Lvr3B+h\nT6JbSLvrkE1hWIjzxKb7yI624T6B1uJJaHKt8CVLs1R76CgU7q9SXxxDudxqvSev\nrI5mNqD6/OpSVKyk0udFqW7bRGSNKCVBUBsZwDki0FwYhzhWvSo5dRZZXukNf4Bz\nqYY=\n-----END ENCRYPTED PRIVATE KEY-----",
        ),

        'alpha-don-2' => OpenXPKI::Test::CertHelper::Database::Cert->new(
            label => 'ALPHA Client Don 2',
            name => 'alpha-don-2',
            db => {
                authority_key_identifier => '25:95:E3:C5:91:78:17:06:C6:36:B4:62:8E:10:69:E3:56:3D:6C:2C',
                cert_key => '14',
                data => "-----BEGIN CERTIFICATE-----\nMIIDgjCCAmqgAwIBAgIBDjANBgkqhkiG9w0BAQsFADBbMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGzAZBgNVBAMMEkFMUEhBIFNpZ25pbmcgQ0EgMjAiGA8yMDA3MDEwMTAwMDAwMFoY\nDzIxMDAwMTMxMjM1OTU5WjBbMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZIm\niZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxGzAZBgNVBAMMEkFMUEhB\nIENsaWVudCBEb24gMjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMIb\nY3EOxgAnG9DITjP/OOxE67QFYFlDS/+JL2DIAiLm4+R6p04OEshtD6gz4vNbdI9W\nZJkRaz/WMFA+tQY16nn5oC3YzbZLn/fpn/bCKAY0Je2CT8AcguxxkjFYHL7Jk0Rl\nXtHcdnjcFJBvU51V7oe9LilKduGe2GCwsrTOA51gqa3rc1omce0yVw/jSgF86BcV\nABHDcAG1YybACU05URs/pm6aeqxGv5l5AV1VEZHgCtJiQ0yDnywNdmqW5EPC6SvW\ngHX/OUxXVh8+1Y+1AdJPl+3xeHKW8UyxOZ7DuxwkapaZMDCFTzxwg8Y38S93KQHs\nnjq+FT2Wv4hyAMDJqk0CAwEAAaNNMEswCQYDVR0TBAIwADAdBgNVHQ4EFgQUaCwX\nuSSUU+TqsE+WC99ek8CefCkwHwYDVR0jBBgwFoAUJZXjxZF4FwbGNrRijhBp41Y9\nbCwwDQYJKoZIhvcNAQELBQADggEBALHlQ3e5fJBmBS+E+UtJMTM6YAFoHibHJ6zX\n40Gi1GQeH5xamzU+DegeETSezC7WFWT/kR7LgsfcBy0fiqnFbaTRPOjjW9oVDC54\ne10hBR7AR4arOlaanymkZINYoMjFrJPRps6qVwMsWLqry6g3D07xDrXnhduZR7oH\n/MYFgZuvfQ9DMgOFUVg2kScM6uHkekBv1yEUGMlIyqJQ3JGD8/nZUfHDgEIgjB/i\nrLXrmyyxr1t2R5I8QJITANght8iS6VGsErkmuQDWXZyF32giajBweCl704fQfNzu\niCCNGM+EE346wM9G/tkP5EpaZBrUf6bzoyFYDDpKe0sdicUwRN8=\n-----END CERTIFICATE-----",
                hold_instruction_code => undef,
                identifier => 'qI77FvXeE1tS6KBS9fjtJ2P0EaI',
                invalidity_time => undef,
                issuer_dn => 'CN=ALPHA Signing CA 2,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'zbwY62EfQRkBZ4bw-gUdZeHsCwE',
                notafter => '4105123199', # 2100-01-31T23:59:59
                notbefore => '1167609600', # 2007-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:c2:1b:63:71:0e:c6:00:27:1b:d0:c8:4e:33:ff:\n    38:ec:44:eb:b4:05:60:59:43:4b:ff:89:2f:60:c8:\n    02:22:e6:e3:e4:7a:a7:4e:0e:12:c8:6d:0f:a8:33:\n    e2:f3:5b:74:8f:56:64:99:11:6b:3f:d6:30:50:3e:\n    b5:06:35:ea:79:f9:a0:2d:d8:cd:b6:4b:9f:f7:e9:\n    9f:f6:c2:28:06:34:25:ed:82:4f:c0:1c:82:ec:71:\n    92:31:58:1c:be:c9:93:44:65:5e:d1:dc:76:78:dc:\n    14:90:6f:53:9d:55:ee:87:bd:2e:29:4a:76:e1:9e:\n    d8:60:b0:b2:b4:ce:03:9d:60:a9:ad:eb:73:5a:26:\n    71:ed:32:57:0f:e3:4a:01:7c:e8:17:15:00:11:c3:\n    70:01:b5:63:26:c0:09:4d:39:51:1b:3f:a6:6e:9a:\n    7a:ac:46:bf:99:79:01:5d:55:11:91:e0:0a:d2:62:\n    43:4c:83:9f:2c:0d:76:6a:96:e4:43:c2:e9:2b:d6:\n    80:75:ff:39:4c:57:56:1f:3e:d5:8f:b5:01:d2:4f:\n    97:ed:f1:78:72:96:f1:4c:b1:39:9e:c3:bb:1c:24:\n    6a:96:99:30:30:85:4f:3c:70:83:c6:37:f1:2f:77:\n    29:01:ec:9e:3a:be:15:3d:96:bf:88:72:00:c0:c9:\n    aa:4d\nExponent: 65537 (0x10001)\n",
                reason_code => undef,
                req_key => undef,
                revocation_time => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA Client Don 2,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '68:2C:17:B9:24:94:53:E4:EA:B0:4F:96:0B:DF:5E:93:C0:9E:7C:29',
            },
            db_alias => {
                alias => 'alpha-don-2',
                generation => undef,
                group_id => undef,
            },
            private_key => "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFDjBABgkqhkiG9w0BBQ0wMzAbBgkqhkiG9w0BBQwwDgQIjmy0I8yvZgsCAggA\nMBQGCCqGSIb3DQMHBAjsiKOSxz8crASCBMhuxw9zMlsev08TayutKlavXD0GNciN\nUIUtR/64nxvPSp9bZFbeshvUzS2KxRak1B//775lye67l/RUSC49n7yoCfgfli8f\nuXC45DtgMfJFyz5RcaeoFYMOCWedcPY5ZMMuqAUGZ/QETan5onftIcQFE7YNWQnS\nm27VB+n3oDSl87wzzLPvo3HmhS9nMDKrhXUhXVumz2vOSYamq6dUXcTxXZc66dF5\nWHLS/hXdQLMJcGib7ucm0phI+l7xBsHiTVBFkOM4ktPjERp5hxX4STZjeK5PLsm5\nD89yOWlfgHezA1kdeHooEK3kescvc0gUZeMV+OLWKE7aXnXlP7kTWMRrt4kk8wto\nOU8Fd6LDVBZTnoLLmAvQ5tj14iBOdNR7WSuKixfyF5BVb30QXuTiJHFxlF8nJKIW\nT2T8KBFQybs3P/wsxY2TraDyyOgTiTQbY0y5rukFGBI1PBCvp1LeurJ0VMtltzLK\n3RwJAh4ZJ42ETkd37MZ+AKSw+fJWNXe69cZ15U50tgpHSpBA9TDJXLLmL4EPXHfm\nqYHpl6BtdYHYVwKRxUmkw3q21gpMYjo3rGWzPdmLqJ0YleiCiVPzUpQUl3146nSJ\nOId3eGT/MPM7u/4VTQ9VPCBuYxzrOS5ybIwI+n2XXLcXJmD0lnL7O3Qvvh+irYN0\ncv1YSlnpWOlBM+PABgrMrmq/xJ24ipJsIZTIP+tKkLPUwMsW0Tlc4bgmj/p88OYg\nknfnwYLH/JZP4NTDPtqLFzEkiWlrA4abLXYxwrO2Rci2+zcKZz5JGbMmV6KAHX7k\nqVvszpiql1CkQhgkLIK/mLf9ZCELXub54sGHKfdtujrICb1Ybgu99UtSz29MyGRt\naI/2Ik2tdcq2pFlZxx6hb9wsB4FQYBQX5vo971FJERAw4aISNLlenjmkexSzCRUO\nGE4og3BK6iiYKH98WRnONzBgmbtxG42iZDN4KbHNCXd++BCc0ASalzZ44AIkXHzB\nsI/BQl0W5sQAhhgpN3cMnHwaP7oW8uxwxbFFgKJmZYFgReVXP+HUs3uZgbNcse8J\nmJbCLKClrBBkMrpsc/v9GUBAekqQeyXvhut7LpIJwWflYdM6fHPZeF8u8thqtP7d\n9aR6Ro5s1aA23Ru+qRe7LNpVoau25/7IbSImxz4rqGrAmQiFQlRjjlfKDIN+uUbj\nt/jXhu9+BydyNuJEoDkbZTcrSed/8MaHuq0lvOaECchkMK0Bpy1/0mmNFzE4KW++\nj1i2C7e6cnc5+/sJTUW1eKy2sVd4OmHHeRweEhIgCHPGgImVsocYiv7D3EPg4twH\n+VP2Z28qLt6A7+AKl4+Ri99wppVML9HLDXwacQ5j7j2xaRczW9buv5HdcEyR9TQq\nW+YtE2h0igBcfFAY8MxzgBmIQP03Rz9an2n7nreZouhxhCU0g98+0I5DfIMPwUtF\nUikl3LVRPhvTeZgqzNca2t1GZtJtlRBQI9FIfpvx98gP0U3UFhkWc6I58mVcVW6W\nm/HasT2YMCMl2oxftCWgVaIOyZmlMz4Jb6iwz2RCIBd9aNEwB+w+B3EyMpsOJRKQ\nBMSUdYyLptJJ+75tCWhuyIHMgv+KdS4v+pzrgbNCREOfSR53xLno7gE5MbObO3fy\nqSk=\n-----END ENCRYPTED PRIVATE KEY-----",
        ),

        'alpha-scep-1' => OpenXPKI::Test::CertHelper::Database::Cert->new(
            label => 'ALPHA SCEP 1',
            name => 'alpha-scep-1',
            db => {
                authority_key_identifier => '01:05:8E:56:D4:90:A1:3F:28:99:28:9E:8A:57:CB:C5:7D:C5:FF:09',
                cert_key => '4',
                data => "-----BEGIN CERTIFICATE-----\nMIIDeTCCAmGgAwIBAgIBBDANBgkqhkiG9w0BAQsFADBYMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGDAWBgNVBAMMD0FMUEhBIFJvb3QgQ0EgMTAiGA8yMDA2MDEwMTAwMDAwMFoYDzIw\nMDcwMTMxMjM1OTU5WjBVMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZImiZPy\nLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxFTATBgNVBAMMDEFMUEhBIFND\nRVAgMTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAOkGeopA0pKQF5lI\ny+oCsm+NTbRHGyGB7V31fIcXFFOBg/TeSEgeXuXiRbBW5Pu9JsoKhEM1O1OBdHSh\neTaWesr2MIQ8fVS3Ta/oELo8tSJ2uI5Ju38RwjuAIwGtxMI3lJSk8mUIu7e2IZCN\nOCSo43WZ/F5Sn3Fs9V8ViDD7GALYjkUuYGfGGyZrwFMEERzYagi8ifqRHtUjeH4u\n72uP7tyPvEPl4Eu0M15h4E3fAgVJkGZIB5BjlPUuzVJeu+NeZudhwtxb4VtN3wAA\ni8tqhRSl2Td5JO4MiOZjm7JXMbEY+Yj0YsTUPgRDV+p8jicLZ3+92aLAaQQtn9un\nAt0tNN8CAwEAAaNNMEswCQYDVR0TBAIwADAdBgNVHQ4EFgQUhUoo0CvdwmEg8vW1\n2a1jnIWFhOgwHwYDVR0jBBgwFoAUAQWOVtSQoT8omSieilfLxX3F/wkwDQYJKoZI\nhvcNAQELBQADggEBAFFl/OWE8rM5Eq9VbgyZaJ4RF8qf+CLCCpHaJfVxKKxYiX/J\nD1d7NddXsFqPu9Eefu1iUdTNA8TT3Ig4lHaajsJe4ak/cLNTdojhiTnIuufEbEAG\nk7+Yf5G1aMd84fYdKLWWb5MVG20JKWeyslGy57tB7yMpiWOOqvBQW9KVvgUAv9yd\nPSnBPVsLgbiYkAtu4taCOBLgYvbB4uGgoZgFZPKAQ58HJKxMpKcETd5jyxswXkot\nlRulN3iG4Q9uh6//mhj9CZOBYJFFcM0XrR33oQDMvOd8y5Y6Ucrb09uc/LCQaUq6\naxmh1DTPiUKRvYZtOjFDiGXkWDxLOSnkdNaki+s=\n-----END CERTIFICATE-----",
                hold_instruction_code => undef,
                identifier => '3FRGU7iskL_bgcfGqcuL1pDtbDw',
                invalidity_time => undef,
                issuer_dn => 'CN=ALPHA Root CA 1,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'U2wfk3NTE0dLNL1QjM7VxPFgfiM',
                notafter => '1170287999', # 2007-01-31T23:59:59
                notbefore => '1136073600', # 2006-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:e9:06:7a:8a:40:d2:92:90:17:99:48:cb:ea:02:\n    b2:6f:8d:4d:b4:47:1b:21:81:ed:5d:f5:7c:87:17:\n    14:53:81:83:f4:de:48:48:1e:5e:e5:e2:45:b0:56:\n    e4:fb:bd:26:ca:0a:84:43:35:3b:53:81:74:74:a1:\n    79:36:96:7a:ca:f6:30:84:3c:7d:54:b7:4d:af:e8:\n    10:ba:3c:b5:22:76:b8:8e:49:bb:7f:11:c2:3b:80:\n    23:01:ad:c4:c2:37:94:94:a4:f2:65:08:bb:b7:b6:\n    21:90:8d:38:24:a8:e3:75:99:fc:5e:52:9f:71:6c:\n    f5:5f:15:88:30:fb:18:02:d8:8e:45:2e:60:67:c6:\n    1b:26:6b:c0:53:04:11:1c:d8:6a:08:bc:89:fa:91:\n    1e:d5:23:78:7e:2e:ef:6b:8f:ee:dc:8f:bc:43:e5:\n    e0:4b:b4:33:5e:61:e0:4d:df:02:05:49:90:66:48:\n    07:90:63:94:f5:2e:cd:52:5e:bb:e3:5e:66:e7:61:\n    c2:dc:5b:e1:5b:4d:df:00:00:8b:cb:6a:85:14:a5:\n    d9:37:79:24:ee:0c:88:e6:63:9b:b2:57:31:b1:18:\n    f9:88:f4:62:c4:d4:3e:04:43:57:ea:7c:8e:27:0b:\n    67:7f:bd:d9:a2:c0:69:04:2d:9f:db:a7:02:dd:2d:\n    34:df\nExponent: 65537 (0x10001)\n",
                reason_code => undef,
                req_key => undef,
                revocation_time => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA SCEP 1,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '85:4A:28:D0:2B:DD:C2:61:20:F2:F5:B5:D9:AD:63:9C:85:85:84:E8',
            },
            db_alias => {
                alias => 'alpha-scep-1',
                generation => '1',
                group_id => 'alpha-scep',
            },
            private_key => "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFDjBABgkqhkiG9w0BBQ0wMzAbBgkqhkiG9w0BBQwwDgQIr1rpEqxh5BMCAggA\nMBQGCCqGSIb3DQMHBAiryS17LfEXZgSCBMg3VbBcL921eC1hdCdwdnG6qykfySwo\n9mbLOFUoXFlCjVK/5XkdOGbURxnlF1pEq96ayqbA4P+MLwfW8OX1XMjyrYe8b3zQ\ne/Q6GMf9pdzPVXNjgqup9Qg2cfuQRg/38oCzBdAnIgcuCVkv5PYw5b/I2R49XKHB\nrdmuXo7McUCjbnkgpd7Gd5GucoTg/1kFaO07QI0OkzR7N8MTIHy0Y7pigT+FmR7Y\nhnevCJGkUQWcLo1W7x+EhZQ2leQi7nfUQ2lGrbMv+VoV9yfgvsC+1E3slm0h/ZYc\n5/Sg1Cs7zhE0l/lWnY5WjxALBvVI1ytaDN2kqoBkXmhj3e7MoKsnWEoEfj75/NkE\nVxSaa/PQgGmrGgFYtcFbwZ/nNP8sv+1mT5nxiHYBC3Qzm5+hvbzSzEaay6BC1cns\nEuSHxf+RvR5suc70F2xHtbYgwKwVm9k8ZOyXCeYh7q2V8Y1En4yr8gAFDsTTIXnK\nvj3xJu1XIjyuH2Ac6fLHXYlUCo/NYedv4Lf+NSQkvEgOq0d+Jt3XBA6egJ44KaoM\n4d+lAP+2NYH/rrHirwrBaW8VS3nkcMxQdW1v5ngEZN2eDxriM277IGzd0BEJQquN\nIJcrjs5aemcl+LR3Glxf7+jtJHReC1sAWTeACs94O7OeS5gh3knVWZ83aKdJpbyv\nRBK/YGAcxH+FF1GXswGJxlLgOJQZY0LwbnP9VRckDy2+ojfR5FzMCHOcSe2+w6v/\nhWuTe7xtPi/qlRc+yHW/uS4jBVnbZZNu2RzM1PPZ3iR1/XN4kk+SXqklu57urUh1\nF+Tec92kSoKBAgNIMPmA2icKdhyXIwZ3eiRThuHvQLZIEalwt1UE8qy6GtvalvMM\nOdXh/C9Ur/PnV0TgJFbVxjieG5JGnqoOyJ6nJ5dN2Wg7FubMfShcsMD1rLPg9NAc\nutadienD5Wb1PTYFWpKcBVpDZxfaP/0pJZPbTJVV7ZKK8j9GVipZKVhbBzndnxPf\nwGqfl4RBU311xcdbyTff9ZqChpGPMMym+jhiMF3r5pJms4K7NH5lHunau7VCnsCH\nikTubsvJbjw9xQ/rqTBTx2yWick3hRja71Bns+DpNE8Z5XiWBxItakoMddqEuw2l\nAeeisdYPxx+MADEOZ/idArWEHrjgieoWJ4/NZiWvjkntZBzn3PrRqIVUZRiNIc3v\nl8IMN5SdIViKUJzm3NhxF4BHS8idcTpIvok+21Ix2nj/+cDGTpV1JZIqEJbdehh3\nC9u0dtNh8nkQOmjIh0kgjmMLqtrPHb2K6u4iOIVHtX7Typjoz1CirqG90FH5mow1\nZ+h659KUzagtcZcIEddd7WXhOXRNpanq5J1JFFbivN9ni1OPzG+d3SYbzYaLczSp\njI27aqYJbWZlvEO7B+6IfBoquhVwKPm0DW6fPA3HgOjf4IqO1JAtItkXp3nGUIpl\nPjhFF1T8tAYxHL2oKa0uJifr8lTvgx6Qdh8dIkOKkiSgdizCanFzTzOK8DfUTygC\nYAnzwB928pJJZwnL9dfIua9pVZEUv2tCSY85IvWhYRiTCuk0ifE6Cej5oZZCWSDv\noAc2hvNU89PpLWcr5XabcRGQ9nAWBC+SYbhbb2UxfPuzt3JJUamcP8nyVzLB6L35\nOa8=\n-----END ENCRYPTED PRIVATE KEY-----",
        ),

        'alpha-scep-2' => OpenXPKI::Test::CertHelper::Database::Cert->new(
            label => 'ALPHA SCEP 2',
            name => 'alpha-scep-2',
            db => {
                authority_key_identifier => '8C:D5:B9:85:26:93:8D:F2:BA:46:71:BF:6D:85:2B:BD:5F:2D:41:95',
                cert_key => '10',
                data => "-----BEGIN CERTIFICATE-----\nMIIDeTCCAmGgAwIBAgIBCjANBgkqhkiG9w0BAQsFADBYMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGDAWBgNVBAMMD0FMUEhBIFJvb3QgQ0EgMjAiGA8yMDA3MDEwMTAwMDAwMFoYDzIx\nMDAwMTMxMjM1OTU5WjBVMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZImiZPy\nLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxFTATBgNVBAMMDEFMUEhBIFND\nRVAgMjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMANi3HQzbK8wRcR\ny9FdiargBGA5TQwXxpyGFbPyn23BDndStbSOd28uNVBTk8gV7DMZcqVG5O98vFj5\ntNvUEycf9V09rRaFZATGeumRiYeQprmGONDZRL5xS4VnyrSqUet+CQVEaHwIU52Y\nGCuO+JVod25YaM7DAWSOfePz4ROS+XABh7y151kx9xxGtCYqocFbNdt2fM0Jm/0I\ngUT2xdzceEcjQvZZUzPRPdA88qoIb3FKKb4Cl2xFTJcXCTrsRKVbcSJdAtoug+z/\nrtDaZFb80IoPOr/PkLuBylQmHsStnjwUNWTs0sIU4wpfZ/izWhTdYLQMXvJD719/\ngH4fSJcCAwEAAaNNMEswCQYDVR0TBAIwADAdBgNVHQ4EFgQUoNifO5f/3+mxkwTB\nBYgQh8vADPgwHwYDVR0jBBgwFoAUjNW5hSaTjfK6RnG/bYUrvV8tQZUwDQYJKoZI\nhvcNAQELBQADggEBADOrXaytwbOXW2V2ZKwwszghhRGoi6KUqtTeLE50VQFNqHNR\n8DuIirtOj5BaAP4nJNagkPE5/YWPfL1jRStXyIVvGUOCyREZOAo7KZB3fk4EaX1H\nxjdr1re5WFd5/pGNGJ3GTl6Uegp+3Ta5Gd60JM0KJVfd2kU0xvkRBkOEjnhWbH5v\n00Hed5yjCB5OQDI4uLpuluUQCIZE/x4c/fLoLvogVFFsv3bOqCUKt0iPDwqgdrNj\nFZhbk3+bMEptL0fnJcthVtjBHfIGrmxFJ0pRosCuy1h0hx4dSwH1CsfjhzoQrzCH\nm5+QVeu9kBviLDama7dSwO9Uj3nUvxEVQAQF4XI=\n-----END CERTIFICATE-----",
                hold_instruction_code => undef,
                identifier => '2vYrIj8UoxVZHFgoLUJSIc2kdS8',
                invalidity_time => undef,
                issuer_dn => 'CN=ALPHA Root CA 2,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'vNeMl9bFa8p1-cHcGaDjfSiX_NA',
                notafter => '4105123199', # 2100-01-31T23:59:59
                notbefore => '1167609600', # 2007-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:c0:0d:8b:71:d0:cd:b2:bc:c1:17:11:cb:d1:5d:\n    89:aa:e0:04:60:39:4d:0c:17:c6:9c:86:15:b3:f2:\n    9f:6d:c1:0e:77:52:b5:b4:8e:77:6f:2e:35:50:53:\n    93:c8:15:ec:33:19:72:a5:46:e4:ef:7c:bc:58:f9:\n    b4:db:d4:13:27:1f:f5:5d:3d:ad:16:85:64:04:c6:\n    7a:e9:91:89:87:90:a6:b9:86:38:d0:d9:44:be:71:\n    4b:85:67:ca:b4:aa:51:eb:7e:09:05:44:68:7c:08:\n    53:9d:98:18:2b:8e:f8:95:68:77:6e:58:68:ce:c3:\n    01:64:8e:7d:e3:f3:e1:13:92:f9:70:01:87:bc:b5:\n    e7:59:31:f7:1c:46:b4:26:2a:a1:c1:5b:35:db:76:\n    7c:cd:09:9b:fd:08:81:44:f6:c5:dc:dc:78:47:23:\n    42:f6:59:53:33:d1:3d:d0:3c:f2:aa:08:6f:71:4a:\n    29:be:02:97:6c:45:4c:97:17:09:3a:ec:44:a5:5b:\n    71:22:5d:02:da:2e:83:ec:ff:ae:d0:da:64:56:fc:\n    d0:8a:0f:3a:bf:cf:90:bb:81:ca:54:26:1e:c4:ad:\n    9e:3c:14:35:64:ec:d2:c2:14:e3:0a:5f:67:f8:b3:\n    5a:14:dd:60:b4:0c:5e:f2:43:ef:5f:7f:80:7e:1f:\n    48:97\nExponent: 65537 (0x10001)\n",
                reason_code => undef,
                req_key => undef,
                revocation_time => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA SCEP 2,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => 'A0:D8:9F:3B:97:FF:DF:E9:B1:93:04:C1:05:88:10:87:CB:C0:0C:F8',
            },
            db_alias => {
                alias => 'alpha-scep-2',
                generation => '2',
                group_id => 'alpha-scep',
            },
            private_key => "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFDjBABgkqhkiG9w0BBQ0wMzAbBgkqhkiG9w0BBQwwDgQINFcW1AtTt+ICAggA\nMBQGCCqGSIb3DQMHBAh3VtmWxZtXjwSCBMh0SL6ll11KTFNJwe2p5+D3pn2Re2yc\nMWUShEAucoxNHsCMIcibBr6QSdtxOPCrq2v6VRG1l5VkeeuzBmJZly5XQtNXCwv7\nEjjRS6HHqzxKC5SpGB9paxPHbJ9OAf4bS0UvvPEkJDt38fDGCfyb5eMJTPV28/PK\nST+BawzZ+1f/UNxfC2Qe1v/cMPKVPtuj8MZmvI6A/Rx2S1c7FqWKvHCpFaSooOJL\nQ8D6e/D+fN1U006Hux8QxMLfAtMQCxFcfggcYtDiygdclC9q0C3Oe37YUmj3Bs/s\nGjPYJDfN6CwVNU63X4VOT2HzETf0s/wsfZqTPeekQJcUrWRJVF+0uVvqnLaGWSPz\nIKEOqcJa3sP33ibUjlXL6vn7Q+xPGVSN8RMdggZunByzkKEV3CGfPEBUJJpS/KPb\nK9JsbzXZCZ6cxECtiJGafz+clW7Id17g2XleWERTI9SzKyvpcOw+DCoMZMRDvWsA\nyfYicmEDd9CudihkXKcocmPLYYpcIFKKxfeeDJR50a3hR6vkXt39UMPz7wvJPMs0\nrWZuoe8rk6WPjWpqllOsAwi1niUbSHbT/LXdV8ej+vKrJVaur2HC02o/rtN2lwTR\n5mH6nu0dH/rWlTunyir3yYgLsEDVKihYTfQh5C9401DpK3rrzYGCECvDbVXK3nOh\ne1bargS39fT4a9KHEmRRB9wrBV+ykDzKql5Un/fVsCWJHt3QJ9lLGcG79ZEV0y4s\n4iMr097Uq9ngtdOrLViaPJo2Ad86eoqMR9/NyFl7rr+zcm0IVPbdELQk3EW6gnBd\nLEQzMRX/nF6WUP2vwMUPYHx9rKp67ieG85cIr04JqaQwwtDXH3/1U6p9FP0DK1k9\nm3juOpZd0NcPPKPOF31UxTp5r3EeuR444YU2dheikXBbO2OCwoLR1tIsjqEws5Rh\nO0oM3UqAwbjNRcTgjJIhYXhuupS561R2ptoZTS1/0pSdon2bfUQYmujvqUm8cWP9\nvAbKXqU6W2UkfM05QIIAkoZ+dH4IkeIScw3V2Ihab4R1mZRnMahWu9ZasqnksMEv\nNLgW5c0Q+J4ml7I4qFgpNl5kr22aiFvjvFq9yNnZHVJ8cbLUL3NN5D5Vbgl9WlD6\nHD5FTH6VLCkcgkkVmlOygN2D75S9oWXyAKw5synITMUmyQHIdrQizu1wOPMWI9zM\nFwYvR+A4HrSGWMy0wycaJiDtGaLk5QT/bqE0Fy6jJSkiUxv/2sg+sL3A/l6uESPL\nkFfxKcl6DoH9RGekCCh/OYpTP4rl/XREF+xSLlctYgpWnOuK3xElhCA0vQ+Rql9W\nwPM3LVtjgjNL4Mn/MqgzP5y9YUbIG4zPcL6dZqobulV5pY0qb6PJ1xTJ8DWvZ21V\nnkq9hv9/FAOy0iiUmf5LKtN7iH25Hq3cRUysjRP0oPCWZuOg1k0B38w/XKjcGZU0\nSLHtFsAhJsDRKPXn3v3CmgMBDTaV2Bqc1hLOF8llS0I2w4WZbihJyp30M0vr4gJ5\nCiebirNEJ1IQ6V9zhFhzDVjNxYKkrDQM+gw+bY+iFwZDjROYMp90bhVFepJon6cK\nHwL5fsbywYRErYlWgdxB+g9hY6QnvEboeYVvDQkwtGhjSpHMV1gwjnXZTg7bsh/V\nVtU=\n-----END ENCRYPTED PRIVATE KEY-----",
        ),

        'alpha-scep-3' => OpenXPKI::Test::CertHelper::Database::Cert->new(
            label => 'ALPHA SCEP 3',
            name => 'alpha-scep-3',
            db => {
                authority_key_identifier => '77:B2:F9:12:4B:EF:BE:E0:AC:48:41:67:0B:C5:E1:15:32:FF:3D:0D',
                cert_key => '18',
                data => "-----BEGIN CERTIFICATE-----\nMIIDeTCCAmGgAwIBAgIBEjANBgkqhkiG9w0BAQsFADBYMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGDAWBgNVBAMMD0FMUEhBIFJvb3QgQ0EgMzAiGA8yMTAwMDEwMTAwMDAwMFoYDzIx\nMDUwMTMxMjM1OTU5WjBVMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZImiZPy\nLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxFTATBgNVBAMMDEFMUEhBIFND\nRVAgMzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJ4gXnajROQkdo3E\nuw6gNlTx6MbFgUvWGkWIUyrnLI1k09qmr14CNa3qljozUa0LpcYNkA7CsqWVj0/H\nKi61BewiA+LI7CvsHtCwh7rycCikiS6pUc6Z/OAY7JUjyMAYaKsTvJCLqKJWyaAV\nvmbT6xuT3A3Av2OFWuAZwQk63Vyr92eQN41Xn1DOKBRyss32WMBlseIaP5leNWy8\n/cXIwtTsf+Zd3Q2E/9Qll4/HbFk3j2q6JG3VZoHqdDH16wptjGg9oiNbo9k2chnk\nw+WVWH23wPdJXAVUSflieS80BgzeofosrbcZ/bYlrEl1QFNyW51QFdnJ6WGl2M4k\n92ciP1kCAwEAAaNNMEswCQYDVR0TBAIwADAdBgNVHQ4EFgQUCsqVKax155htZJKS\nYBjNJEbUyG4wHwYDVR0jBBgwFoAUd7L5EkvvvuCsSEFnC8XhFTL/PQ0wDQYJKoZI\nhvcNAQELBQADggEBADv7WlQyIpS04v+cpx5LCQKhkTSR2wFU83DIiS6sJ53pZpL0\n8ELwq2Pfvpw3bRgnn+tS30CsQSsShNt2s41HzsIA72Y/ozW17+IZuIqoqPosp8w/\nAi6zQe+r0dOqqadwctTHrZnhhjAJLibwh46mp9mEZhmYrPL3s03jiwTcQJZ3XVWb\n/oTbDwy0m7Rgm/CKvxkjRkZEbJc5eERyAAAIcExzXiSt5B3ZDkfflMY5rFlD1oPf\nyhKQQnTbvaYvZcNpclhufQt9XCiQ7H9TOq1zlDKYRpAjja7K0dROG1Fk0DNiyOIN\n38dAR+lH+dhpGLz4FZO/Z+rphFoR+9pcoXUjVJE=\n-----END CERTIFICATE-----",
                hold_instruction_code => undef,
                identifier => 'wtwh1dz6-tIkt4sOy3q234ugHJI',
                invalidity_time => undef,
                issuer_dn => 'CN=ALPHA Root CA 3,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'wXBasWhcc4eGcYLGdFWjeci7w8E',
                notafter => '4262889599', # 2105-01-31T23:59:59
                notbefore => '4102444800', # 2100-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:9e:20:5e:76:a3:44:e4:24:76:8d:c4:bb:0e:a0:\n    36:54:f1:e8:c6:c5:81:4b:d6:1a:45:88:53:2a:e7:\n    2c:8d:64:d3:da:a6:af:5e:02:35:ad:ea:96:3a:33:\n    51:ad:0b:a5:c6:0d:90:0e:c2:b2:a5:95:8f:4f:c7:\n    2a:2e:b5:05:ec:22:03:e2:c8:ec:2b:ec:1e:d0:b0:\n    87:ba:f2:70:28:a4:89:2e:a9:51:ce:99:fc:e0:18:\n    ec:95:23:c8:c0:18:68:ab:13:bc:90:8b:a8:a2:56:\n    c9:a0:15:be:66:d3:eb:1b:93:dc:0d:c0:bf:63:85:\n    5a:e0:19:c1:09:3a:dd:5c:ab:f7:67:90:37:8d:57:\n    9f:50:ce:28:14:72:b2:cd:f6:58:c0:65:b1:e2:1a:\n    3f:99:5e:35:6c:bc:fd:c5:c8:c2:d4:ec:7f:e6:5d:\n    dd:0d:84:ff:d4:25:97:8f:c7:6c:59:37:8f:6a:ba:\n    24:6d:d5:66:81:ea:74:31:f5:eb:0a:6d:8c:68:3d:\n    a2:23:5b:a3:d9:36:72:19:e4:c3:e5:95:58:7d:b7:\n    c0:f7:49:5c:05:54:49:f9:62:79:2f:34:06:0c:de:\n    a1:fa:2c:ad:b7:19:fd:b6:25:ac:49:75:40:53:72:\n    5b:9d:50:15:d9:c9:e9:61:a5:d8:ce:24:f7:67:22:\n    3f:59\nExponent: 65537 (0x10001)\n",
                reason_code => undef,
                req_key => undef,
                revocation_time => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA SCEP 3,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '0A:CA:95:29:AC:75:E7:98:6D:64:92:92:60:18:CD:24:46:D4:C8:6E',
            },
            db_alias => {
                alias => 'alpha-scep-3',
                generation => '3',
                group_id => 'alpha-scep',
            },
            private_key => "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFDjBABgkqhkiG9w0BBQ0wMzAbBgkqhkiG9w0BBQwwDgQIlwCEkopbhugCAggA\nMBQGCCqGSIb3DQMHBAjHqTG8SGx7lASCBMhNnyAdcoxbwqQZqnKGMu18KTjDlTL/\nILaPXa8Nromo50bve7Q13vC0CSWy9emPticVYGwYmcAiIPdWId7mnW1vMJ6VDJp5\nOPE4WAb3HJO1HwJsxVDx2fhVx3lg7sqge4bDYyT4SUXgUx8gyD8w4qvkcIm5BtaE\ndmeeEhrx2CFSTqCUYpN5w/PGWdugmPGBYXUh6FMlqiD9mN/EoQVB2/tO+qby/2as\nKn9TJbIlm01GwwRr2nwFiZ2jMR6ZE53BvOVIQ9KF7xq/szNlEouAJpawrioosX/X\n3EJkMXZuhO5r97zLGNsyCuhpbWMoRySFQ2hUlGVEzO3IUTqFZS3w98tZCrDEAf5I\nCz07Nnpx8UQ1xcC9+JM3h+Pn6Sa4+FwUudQ+XUWK23Wx7TDw8wm1vU6doKXCsd1t\noGwnRbsGvufYt+UvdbrR2h6T7++89WpTubeQqVgOuywOue8MEEq5twjP+3X8Nsrk\nkW2TQTyQlphLxSXi/BH3WCexuTBMZWvTDShNKeElDn26IXWX8KnhqYfJZko4wx/z\np1QZuraGA0ZQu522jlD/e5TTjfwZNhDi9MZI8MpMOgOP37rW9PRUtt+HnmSuN2Z5\nw8hcP/FL8IVmUNjtNBjhWW5BPrweZxWicw8FBnMVr+zc7QUNRwuB76xtABdq+VDW\nvOK+5C1sM7ft3MXWbpdKxKMYS0cLTHb8bgbKrGgGIarUQdJTtZgVSDTbVjoQKMpD\nOeShyXyT3tpVnQb38EEH+ePyDJBsAoH9VViplbgIIYGYc2mtdzqFBamtqn1iE60P\n4AqmTpqn7i9tEd/s0y7jIP7zDz3LQnnwUFYK7AF13Zd3RuLEr8dwdFB7DmkYFuJ3\nnE1YkdwviUD+6YEbufZDyh9+JMIq4csJkIbv6xLxl3hrWqweK1es31DWqfEnuNd9\ngYEgDptDVTfjKd743ypkRTtMhxuHhX6y1XK3lH0P6eAWNSsGnRrsOgIpKDt8htJN\ne7yTwZjVpgJU/pWbwQj+FG9t7zqHiGTjGZvkspVzxEGDpkIO8cVM+HaaBTj/yJ67\nj2llm0NncWNxiq3Q/jusNG4INKs4E00FbrQBNdCV9NGlHxKcmtSi+3WfLC/eOhQk\ncytyFwkTIrsNPYrquA40MPVKBCUzCi95N4oh7f3dqbIjid5T9bFyTkNHhqfHUMPy\nj4RWcvDIfBNrjLLMafOxdwJuSQ3j73gzR2t4NPVg0uQR8NWpAd/o9oEqWr/CanpL\nvBXKz5CuPf5/v1FV2vYK3pRabwWCt4aqNbuF22XkX5X9V5ow08RpZ+kLr7Ln6WTA\nPsbEeuXmF31CYztPXMODDCF0PswVJS30f0bUmEIL9uf7rl/hk7T9K/CzKzdSMOx1\n2xiY69lagSBR+XmGL0oj9pq1QHLuYMZPPWnaffy6yDItquPhIr3n469edv1KKH81\nEm5Ps+IBtxg5lHIXTi27SD8qwZk5UUjWWB/f2vssoaVdy0cJpV/Tc29cMUyk3tzZ\n45zxaPS66Abqw51+WNZmpfrPKEo17+bhcb5SjgdB9Wk2yuR0lbRln7A9s2hkENj7\nerIEdQYnM84YJLcosCUa3IanU5lm9imnlkDAfopRXQ6530Fvau7Bk2+eCQDKzOWY\njSE=\n-----END ENCRYPTED PRIVATE KEY-----",
        ),

        'alpha-signer-1' => OpenXPKI::Test::CertHelper::Database::Cert->new(
            label => 'ALPHA Signing CA 1',
            name => 'alpha-signer-1',
            db => {
                authority_key_identifier => '01:05:8E:56:D4:90:A1:3F:28:99:28:9E:8A:57:CB:C5:7D:C5:FF:09',
                cert_key => '3',
                data => "-----BEGIN CERTIFICATE-----\nMIIDkjCCAnqgAwIBAgIBAzANBgkqhkiG9w0BAQsFADBYMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGDAWBgNVBAMMD0FMUEhBIFJvb3QgQ0EgMTAiGA8yMDA2MDEwMTAwMDAwMFoYDzIw\nMDcwMTMxMjM1OTU5WjBbMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZImiZPy\nLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxGzAZBgNVBAMMEkFMUEhBIFNp\nZ25pbmcgQ0EgMTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJgkBelO\naUhZBxclTQgKr+5FIPI43dDl0Ev7f/E6FOquUfDHft92uy4317ptYCk+uV6zSZyU\nOD6nDUWnyO3d9JXpXQJLnAgrIQLl80UP1qSEiC+NIJj0SuJM6545T5/rDVdVJEUC\nuYtspzlGAcSrf9uaThK8rwigUp5SWKNnZr7KZE8fTxffLTImNx4Xghj820ocQGdG\nfHOsiBh5pnto9UVupGh9lJaQypTJB0FM1Xq/zrxaAngulTZhqJXCEzJvSYWSAoqW\n4svTOgAG9m+kipgbChUDPyEwX6ZC0Cb2r4em0T+j9rQ7RSKsuHkhG97PLIuNiGfE\nLVACjNEldRCoVmkCAwEAAaNgMF4wDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU\nk9MVLOaUwdE5qSjcLQv2becv38swHwYDVR0jBBgwFoAUAQWOVtSQoT8omSieilfL\nxX3F/wkwCwYDVR0PBAQDAgEGMA0GCSqGSIb3DQEBCwUAA4IBAQB0Zfsl3YfypKzo\nGZZenMZQlP0ZiB9ih7p4ZbqCdhujml74ZIA1lmkp7HPKlx9Kmvm2ct+HGEGgWjS9\n7FHHreIuUTP7meioQ8HTvpOtsayfeCkxbE3IBYeFeyb5GsiOl1XcCinSP2XuA+c8\nA9gUd7EmEc1+4HqU/B6bANJ4hFM2pqPNclL2mcfZ5t5v0O7ZX9D861wUF8JHl62T\ng6qxMODKBGapxReev0Goy8p6fJh6VUavd+jPcpqRNdMeT7dxXRqiLNIDJO/tAWhZ\nUmP79SEv78DGhMPiQ12EXK3PPJFmpsgEqmZQTGW/3H8SnNp5+1ZWBd4fjpTMBWs5\nuBNDuXlA\n-----END CERTIFICATE-----",
                hold_instruction_code => undef,
                identifier => 'UDFhlBTPFnXDz_tiXZ_FZ7MuKng',
                invalidity_time => undef,
                issuer_dn => 'CN=ALPHA Root CA 1,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'U2wfk3NTE0dLNL1QjM7VxPFgfiM',
                notafter => '1170287999', # 2007-01-31T23:59:59
                notbefore => '1136073600', # 2006-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:98:24:05:e9:4e:69:48:59:07:17:25:4d:08:0a:\n    af:ee:45:20:f2:38:dd:d0:e5:d0:4b:fb:7f:f1:3a:\n    14:ea:ae:51:f0:c7:7e:df:76:bb:2e:37:d7:ba:6d:\n    60:29:3e:b9:5e:b3:49:9c:94:38:3e:a7:0d:45:a7:\n    c8:ed:dd:f4:95:e9:5d:02:4b:9c:08:2b:21:02:e5:\n    f3:45:0f:d6:a4:84:88:2f:8d:20:98:f4:4a:e2:4c:\n    eb:9e:39:4f:9f:eb:0d:57:55:24:45:02:b9:8b:6c:\n    a7:39:46:01:c4:ab:7f:db:9a:4e:12:bc:af:08:a0:\n    52:9e:52:58:a3:67:66:be:ca:64:4f:1f:4f:17:df:\n    2d:32:26:37:1e:17:82:18:fc:db:4a:1c:40:67:46:\n    7c:73:ac:88:18:79:a6:7b:68:f5:45:6e:a4:68:7d:\n    94:96:90:ca:94:c9:07:41:4c:d5:7a:bf:ce:bc:5a:\n    02:78:2e:95:36:61:a8:95:c2:13:32:6f:49:85:92:\n    02:8a:96:e2:cb:d3:3a:00:06:f6:6f:a4:8a:98:1b:\n    0a:15:03:3f:21:30:5f:a6:42:d0:26:f6:af:87:a6:\n    d1:3f:a3:f6:b4:3b:45:22:ac:b8:79:21:1b:de:cf:\n    2c:8b:8d:88:67:c4:2d:50:02:8c:d1:25:75:10:a8:\n    56:69\nExponent: 65537 (0x10001)\n",
                reason_code => undef,
                req_key => undef,
                revocation_time => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA Signing CA 1,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '93:D3:15:2C:E6:94:C1:D1:39:A9:28:DC:2D:0B:F6:6D:E7:2F:DF:CB',
            },
            db_alias => {
                alias => 'alpha-signer-1',
                generation => '1',
                group_id => 'alpha-signer',
            },
            private_key => "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFDjBABgkqhkiG9w0BBQ0wMzAbBgkqhkiG9w0BBQwwDgQIBjTncAD9k34CAggA\nMBQGCCqGSIb3DQMHBAggNOsn7iTHfQSCBMjTWH0pjyYtC0e/h/iKILpTxkvpyUDO\nWDe7ItU82GcXncI/8GKyOvfATdgHq64yVpmRftNvkIntCi0iEz8gC1px8XAXpCqJ\nn5QBunX/QEs9fBEmyfaxn/9rbp9w62FUxofxT0uH5ffhJnzkmhDXjXni30T2c4du\nE/0Isw4eBJ6TAj8HYR3Tw67JsDivpO/YFfT2JqCRhum5z3FWOlvV/1XirXdhnBt7\nTkBJH1nm45qcH73MAWEuc7c+32wKkB1gtnn2/EkDxf3kJ2Zhm8J4WhEZfIwhiusf\nf1d0aRtJLVoZt2ci38/f2IhV1OxOBYExEJf3LWeQru9i4zP1/S72NJbcJq/R4wx7\n96e08KWjAu3L376XGKy5cpYOe7Fi3os6LpiCouqvYrAJtCnrYvf6KUcf4a0+fQOJ\nPZG9aXvlovdEGNDtuU2HS9eIALxrslyuP+pN0EFxpciq01IHP+anGe5gqHLeW8pV\nkVJt/Ci8wZqG/V8+uq94wum2QGu4mKW47YtKMbC+2CYKrp/sKQrnLK4EwKSC9FXZ\nUaQ8T7dUvWUeFR2IZmtKSCTj8cSOpkewmpZYGIRBg2seH/6inuZYMsairO6MJ66c\nza2L0H8/8+pWyqgbwkxkTjuCz6U7vdb5TwJCAUtirjqbiaqbXGYRUgm7dHiV8upg\nkaJ9gtAYP6ZnjNVsu1lTjYsFmFbp+XIlCWD5/DwH1fAlNZ3dBWMRxZqU4YaEID8C\nw3PjcfoYJjonmuJ2RGMlvmdNXalXVBSSljTK8ryuY/zUieOXbjjkngCriyKxAUVC\n7wJkmQ5sh47mXvGjq6cXPSI4vtbFuQk88rYIXmffjvphx0Rf9VF1gD/qgTsFz9nU\nPEUAUvodu6Wm7OfIsXfRcvPhKv4PalL+gt+EUU2uGUwN/gJxjzVmtgo2nzvghzXG\nZXt79ug2jDoE6ZfbU2C9UBZaGQBEiH9UDfXIM7djtxbBgx6hshigEOq0lAtyIi/P\nbpIdWxFXLvGq6e7Oabknq3HyARkBl0OCbMsB63GQU6cROSoLTdfUBdHG2o8DiwuX\nVVAtUJhURp0GTEwvcqU22YDkLQNRTu0E0GgFxEKqGEapI38uuEST3LLc2OAEzb2b\nFSjpagVyKBAv0b2qX0X8amRLIxuTWceT2SoNScTnVcTmQRXefW1hIZGOZr8Qsa/E\nFnyZY+0ibHGvhj4f4NoTne6eTUx3uRQU/Kb/nwhiFOCLbfirVEBqFpwUd44yUZox\nm2sUv8OWCcGiAfTUdBJEH4fqAo3SlO1fRTR2MZA907xK00E0/nxKLWxaiRYIA9Rd\nMP5+qSokbpuvuGBs77A/U6rkjfbKVsL+Lf/NCz5zQ4RF7QuXJIn16MEQrzovhxSS\nZOpxvvxBMZt7kmVKc7I9g5ApAsX8QaqsHQnoa2gabXF7vbtuHodgKeUaWNPALh+e\n1M+blUOm1Z8sEJFY9FnBRIFXbXvu2Om+DGrNBKrZM0XT4A+6DvKF8zI7vM0ktFqD\nKh4NIoz41OsDqVJLgp17aLo7ZbkP3Nkgg3MfOX1uTC5vhQX3qOewLCMqGMp33tue\nyx0ZC7xH+OEcJ44NmrruGHiL08eDECARtREGQEMSRzKccCh18raaqxXt+Hm2wQwL\n8ps=\n-----END ENCRYPTED PRIVATE KEY-----",
        ),

        'alpha-signer-2' => OpenXPKI::Test::CertHelper::Database::Cert->new(
            label => 'ALPHA Signing CA 2',
            name => 'alpha-signer-2',
            db => {
                authority_key_identifier => '8C:D5:B9:85:26:93:8D:F2:BA:46:71:BF:6D:85:2B:BD:5F:2D:41:95',
                cert_key => '9',
                data => "-----BEGIN CERTIFICATE-----\nMIIDkjCCAnqgAwIBAgIBCTANBgkqhkiG9w0BAQsFADBYMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGDAWBgNVBAMMD0FMUEhBIFJvb3QgQ0EgMjAiGA8yMDA3MDEwMTAwMDAwMFoYDzIx\nMDAwMTMxMjM1OTU5WjBbMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZImiZPy\nLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxGzAZBgNVBAMMEkFMUEhBIFNp\nZ25pbmcgQ0EgMjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMiovn8+\ndjhIOADUUtE7mgSXlYJoPjjRinGzCRtHy8YdM+uzgKXiyYODEpK8YpRROsuBpEPO\n6nkdilI6ONdz2IkwHHJSx9d8SPvW/pKSshBQ27wl5bHqihY32AdqdkUH8YFCCheD\nSBV9IfGRd4RVNITNEmXPIDN2LDHmNwRURbzEjM7rZwkIwJy3ksiW6PCXRmwCt7F+\nHAj8afn4niTyni3BU4SQGuszzoO6jzvrmTxIhZ6PGJ0uzxHyS3u61lkAEF2a+pnV\nVuUnVQ9QsWleVbaWIsxbcF9BRNMc1OaBnJKGlGzcqWRhJx6fzuyzcclJBgcsniTK\n5jl43BLhRAC4pikCAwEAAaNgMF4wDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU\nJZXjxZF4FwbGNrRijhBp41Y9bCwwHwYDVR0jBBgwFoAUjNW5hSaTjfK6RnG/bYUr\nvV8tQZUwCwYDVR0PBAQDAgEGMA0GCSqGSIb3DQEBCwUAA4IBAQCFX+bll/CC4hJe\nRMkmFWsq3UcvNkp84NROYsZejdub/tkn4C8YLi/elgIU360Wam8WpnY+qvNBMk86\nZoj6K3R8nmaHUdRFoRp8wqwKbCDgyb1QwXwsm7bDwg5DstOoL0Ol8OBasG5YSX+B\nLSF/3EpSHUUW5s9JXiAOMo382CmsZY+/J8yF/L+TqSs4CObXjzbrrTftj4El0Ih/\nlnJyKhkvhfI5YSInPwByg0m9mpOhd2gdk15WFM5D+RIGjb7QAuSY+mvZJ38rzU2y\nNDjL+w3olKW/wD1FI6yn0/QmJGHhCAblXQmF7yJsIeFQEWGm43tOqx9SVuzhxfdP\nGihYtVw3\n-----END CERTIFICATE-----",
                hold_instruction_code => undef,
                identifier => 'zbwY62EfQRkBZ4bw-gUdZeHsCwE',
                invalidity_time => undef,
                issuer_dn => 'CN=ALPHA Root CA 2,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'vNeMl9bFa8p1-cHcGaDjfSiX_NA',
                notafter => '4105123199', # 2100-01-31T23:59:59
                notbefore => '1167609600', # 2007-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:c8:a8:be:7f:3e:76:38:48:38:00:d4:52:d1:3b:\n    9a:04:97:95:82:68:3e:38:d1:8a:71:b3:09:1b:47:\n    cb:c6:1d:33:eb:b3:80:a5:e2:c9:83:83:12:92:bc:\n    62:94:51:3a:cb:81:a4:43:ce:ea:79:1d:8a:52:3a:\n    38:d7:73:d8:89:30:1c:72:52:c7:d7:7c:48:fb:d6:\n    fe:92:92:b2:10:50:db:bc:25:e5:b1:ea:8a:16:37:\n    d8:07:6a:76:45:07:f1:81:42:0a:17:83:48:15:7d:\n    21:f1:91:77:84:55:34:84:cd:12:65:cf:20:33:76:\n    2c:31:e6:37:04:54:45:bc:c4:8c:ce:eb:67:09:08:\n    c0:9c:b7:92:c8:96:e8:f0:97:46:6c:02:b7:b1:7e:\n    1c:08:fc:69:f9:f8:9e:24:f2:9e:2d:c1:53:84:90:\n    1a:eb:33:ce:83:ba:8f:3b:eb:99:3c:48:85:9e:8f:\n    18:9d:2e:cf:11:f2:4b:7b:ba:d6:59:00:10:5d:9a:\n    fa:99:d5:56:e5:27:55:0f:50:b1:69:5e:55:b6:96:\n    22:cc:5b:70:5f:41:44:d3:1c:d4:e6:81:9c:92:86:\n    94:6c:dc:a9:64:61:27:1e:9f:ce:ec:b3:71:c9:49:\n    06:07:2c:9e:24:ca:e6:39:78:dc:12:e1:44:00:b8:\n    a6:29\nExponent: 65537 (0x10001)\n",
                reason_code => undef,
                req_key => undef,
                revocation_time => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA Signing CA 2,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '25:95:E3:C5:91:78:17:06:C6:36:B4:62:8E:10:69:E3:56:3D:6C:2C',
            },
            db_alias => {
                alias => 'alpha-signer-2',
                generation => '2',
                group_id => 'alpha-signer',
            },
            private_key => "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFDjBABgkqhkiG9w0BBQ0wMzAbBgkqhkiG9w0BBQwwDgQIzcuKtapTEmwCAggA\nMBQGCCqGSIb3DQMHBAjo6dPN2D3jpASCBMgkuEzL2utjux6GvLreFrUIpoG95yzs\nIGUXTSpm/zh00pVAuOxljq50K+YXtfAQibRiQRGFKcbVg8f5pCpOHMVeFu3x1HVi\nXB+RSR4xdVbjRv/517zLwAbfgQDdo/UhxlKa4c4fNUwXEMyjTgriKL4MftlVUJLM\nPs2FjY093PdKGl8eU/UAd3SxvLJuzvIBvSxdk58w84PyldCzomD0HOiO/DeDrWyL\nRQMVk5VXAUAssk3IYyYClY6VQGu9+0Dquiq7jYz5Vhtx9hnuM+IxTXO9PNIlHUVW\nFkTPIgdWHnBLzk8cfN4Ne8Fl+1lxahWNsIL9vVpVtxGSmZTDjonIJ8Ww1Sgbrxd0\nND2ixzqVk1lSG7DLWuH1V4uBuI0pEDnWZ5bUXHEtgqBnwJcyKx63DZMgaDot078L\nEUwo3oGzdyBQVhf9EG02HbO35i8/pv/UZAN3/XLQHaFfDE5wUqyLfCFCQmfvCkKi\nS+MSRcUXQUoJ6pUr5xzq92TFjQAnhKac1NOKb5xVPyR+Y0RfIFxZ3cWxBJRrAQI7\nTucDL7G647dsgoM9ii3G6k5XqpOH82YYlGIfksx+r/OAINEO5+AhG2oMN2sXeEBa\nJPMgOkTeXVWGGZnAnqiwfF+YfrqJZPvpFXWX8u5tSuRCFzXCa0yNsKs0L4MtEIc5\nvkFxd+PUksv/jEaOMB2adtk0wTgCMqsFIaxlfCRJ8wZBRXxtScQdq0pkzTYZilj6\n3gS+ovnRnxVQ+PxGKpzau0QC+KInQXnPPJYpJGh6jbQGcEqdIdkoGchGrqG6XhNx\nPQw7vWBMTenXTh23KlYMM4kYCewmw0iAc4Q6nWXsCRCnq7sIC9DQtR1oAHgxSgP4\n2f+LIZZY2fDyi6+dFO3wgnK6wLKf6NKFFYwi35usGgVG+BwpRxUVXSBzXy61ni1Q\nzuhjd0nErzjJVRDWg0/CK0U8FUJ9gCW2oAumb4Zg/sGewdRNhXMnUgC1/C3I32Lz\nrYVfwm2DXKp2EdebS4ZoCkPT8gowDh1mNVf6wOMMPh5minoDOze6M8Nog2hp58fr\nWxcUFnKU5Cehh6inECmjoj0TWh/++ghZCbK8brVg4lCsv06z0+esUG38riPdWBmG\noS3M/cqgaMiDuivqHL1DCa0A1b29Oi5ZKBdmzD3T7I3f4zqUTmQUg+FSjOmPSw0X\nrUi/28Din4ZQxovovzSXkX1LDILW/JY+Nja8yVLrzP9xDiCrawlRh7WCQcrx+f5j\naCQEh91cMP+U9mQz0QG6dsDqj4UXUBcydbtQLXPlPFNhxkOmXTnznDFTH2ntb2bN\nrRWqygT46gA+2A/5/H5slCWt1xK7jdFZ/ytsSRDtpnrmJf9Oj7c98diWDmKeIUj5\nejtOCi+T7XsZbwzQaAYJqGsAOQWa5jeNWQhl53VuGER9akkHHvM4fWBevYS4ZyBS\nQlhQnsdWeUjNdIhsBo8/Wb7dDYIkLCQr73NLtuvjzHwtWMk0wLY+sx0b1qWMJpv8\nS6wqGPl8POMbKI77jDdQoUsbkzOPh4AqGClIiS5ZTFHSnXUD1HaRnKTCRvtWGOcT\nmbRGckj47BFiVAJ+TF6ZCXF15SUqQfKNjGu4lFLsLD707XFRBdyjwBlqFTVOmA0Q\n6J8=\n-----END ENCRYPTED PRIVATE KEY-----",
        ),

        'alpha-signer-3' => OpenXPKI::Test::CertHelper::Database::Cert->new(
            label => 'ALPHA Signing CA 3',
            name => 'alpha-signer-3',
            db => {
                authority_key_identifier => '77:B2:F9:12:4B:EF:BE:E0:AC:48:41:67:0B:C5:E1:15:32:FF:3D:0D',
                cert_key => '17',
                data => "-----BEGIN CERTIFICATE-----\nMIIDkjCCAnqgAwIBAgIBETANBgkqhkiG9w0BAQsFADBYMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGDAWBgNVBAMMD0FMUEhBIFJvb3QgQ0EgMzAiGA8yMTAwMDEwMTAwMDAwMFoYDzIx\nMDUwMTMxMjM1OTU5WjBbMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZImiZPy\nLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxGzAZBgNVBAMMEkFMUEhBIFNp\nZ25pbmcgQ0EgMzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMvLMb/g\npZaNsX+3+nJ+1yoCtrsDg1QtofNltZ4wRKYQqcarQx5pXoGNwiHMgoAjGH85EVw3\nCglv2H7xzoHAV2olSzmvkuIvP4jadrVk8XCn9FuKba5c3yqBTDwbcnA1wIhrmGRZ\n0m0GlrSCU5nDcDE6Tf2cmxurnZ+i1PceOctruPh5S47i3pKw3JR4FVa/lS4GnKeN\nKyLQRwufzx9EiePpRy8O1KZnC2dwC3yYYCPGifBRVV1f2DomRS/zTuudCewosPRg\ngYu9tPRFTN8WqxuCEHg1PjtedSwjYSFq8psbr6kk5O85wZVoLw8y0dZSeT6fDs5E\nplOndAPUAFlnKwcCAwEAAaNgMF4wDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU\nfMDw1IP5v5eKPFX1SvaJDwAr7A8wHwYDVR0jBBgwFoAUd7L5EkvvvuCsSEFnC8Xh\nFTL/PQ0wCwYDVR0PBAQDAgEGMA0GCSqGSIb3DQEBCwUAA4IBAQBp5PhpwB2GJMHC\nHr6VyKgCLmO24ThsSct/4D67HbtQemfaZaAvjO/SfpHBVv6qzOl6ePBWf4HQZ86n\n+20Epb/mvzAFUF6u8vJM49A6Rq36OEPkW0CxV1GJdvP2iSku3uf+qFbp/vnaOfF1\n9LiRGbP0cOUlbaOpxzP5BmYSHm8Bssrn+lX8hez24AKlNiw2OFVaMv9mwWymLcg/\nhuocp6CPhvA5X+8IXU3eQsRH4p3b0atNXB6TZ9lCawMMgPk/XYcNsGrBagrE3bIa\nQwSs0ORNbaf5pzLmxUCa/xmrd2L0fi7Npm4FMRiIfVqqJjZTMR++wkNDFalQe8P6\nZyrZYcVJ\n-----END CERTIFICATE-----",
                hold_instruction_code => undef,
                identifier => 'q-yWkovtKUUH60U0_O-mjr54cBs',
                invalidity_time => undef,
                issuer_dn => 'CN=ALPHA Root CA 3,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'wXBasWhcc4eGcYLGdFWjeci7w8E',
                notafter => '4262889599', # 2105-01-31T23:59:59
                notbefore => '4102444800', # 2100-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:cb:cb:31:bf:e0:a5:96:8d:b1:7f:b7:fa:72:7e:\n    d7:2a:02:b6:bb:03:83:54:2d:a1:f3:65:b5:9e:30:\n    44:a6:10:a9:c6:ab:43:1e:69:5e:81:8d:c2:21:cc:\n    82:80:23:18:7f:39:11:5c:37:0a:09:6f:d8:7e:f1:\n    ce:81:c0:57:6a:25:4b:39:af:92:e2:2f:3f:88:da:\n    76:b5:64:f1:70:a7:f4:5b:8a:6d:ae:5c:df:2a:81:\n    4c:3c:1b:72:70:35:c0:88:6b:98:64:59:d2:6d:06:\n    96:b4:82:53:99:c3:70:31:3a:4d:fd:9c:9b:1b:ab:\n    9d:9f:a2:d4:f7:1e:39:cb:6b:b8:f8:79:4b:8e:e2:\n    de:92:b0:dc:94:78:15:56:bf:95:2e:06:9c:a7:8d:\n    2b:22:d0:47:0b:9f:cf:1f:44:89:e3:e9:47:2f:0e:\n    d4:a6:67:0b:67:70:0b:7c:98:60:23:c6:89:f0:51:\n    55:5d:5f:d8:3a:26:45:2f:f3:4e:eb:9d:09:ec:28:\n    b0:f4:60:81:8b:bd:b4:f4:45:4c:df:16:ab:1b:82:\n    10:78:35:3e:3b:5e:75:2c:23:61:21:6a:f2:9b:1b:\n    af:a9:24:e4:ef:39:c1:95:68:2f:0f:32:d1:d6:52:\n    79:3e:9f:0e:ce:44:a6:53:a7:74:03:d4:00:59:67:\n    2b:07\nExponent: 65537 (0x10001)\n",
                reason_code => undef,
                req_key => undef,
                revocation_time => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA Signing CA 3,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '7C:C0:F0:D4:83:F9:BF:97:8A:3C:55:F5:4A:F6:89:0F:00:2B:EC:0F',
            },
            db_alias => {
                alias => 'alpha-signer-3',
                generation => '3',
                group_id => 'alpha-signer',
            },
            private_key => "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFDjBABgkqhkiG9w0BBQ0wMzAbBgkqhkiG9w0BBQwwDgQI//VVZRRaD/wCAggA\nMBQGCCqGSIb3DQMHBAgfrXerqAgKVwSCBMiWoJ37Acy/2ZTUNxqSo2tBuzI0CYxU\nQ0RZU8gaadYhkwA+Pb3rBWeXABEKzgZg/UdUqBqWq8kTaSPWfFZeeG8dt+ivzE21\nGBlZYV2IVwBttGGVfrhNbVk0tLGbVOlBwFOaJ7sEK6j3rHqAi/0qZXpui2bcxrZr\nVJkPgz1byldmSUMuhcDmqMgN/8xcoDtMMw3tHxf+f1z2qc0hqca2d9nNuwG2TTsd\nJTPZXcOBMW7kmmD5VvGm957s4eAU9mdmeB8Cyu6FdlVUu4eXR7foBxlywNdBAe3r\nsOEkq9D8YHlhUbZtK7Fo4mOxqUC+1NquZ/08tPilChgmaLF495ZSPbEB6XiV0pwa\nf2i9Y6Laq4X3V3lGgehB0SN1h9NERl2omS7NclFH9C+Gceg8DOECfNx/bFVXE+Yn\nCgvyQNTwYovuysZz7bMghAS8lY8Hc17RARK75NnB7O6voLWBFXWnMsDuhFyasKnK\nqc9MXBBFAAOK4AqHBgJkcR93scfauKLap7extfcBoejHGsuS/OceF0y8m3ADvNrV\nUoKBjTDxxgEsiDc+ySjJ6F30XWuMShbm+ur9QuSRAFqKMcKOo1lra+1iaaOSRhf/\nIGyPgdNGBBHC78F7HdUJEuLarHs3h82phfO/EKSuFlD8C8ZU4HbcZwVNqOAkRcr5\n8Sib9hlbVIxHamxWn0NgOMXWhE4yWdePbfoLqQN3VMy36OQv2IQZ9YWfgcMQfaQ6\naAC26WGohhEXaZvI9caj7U/knlJsKhAxj0d2DvlWIkRSKFvSyzk1n1hAgSrybZpf\neq3a2BuGlW1UIDhoKM+gXDWpAE3ic9p7dufCrHCp20nK5bLzYwFo8jN3CbWNrMZY\nJgHEcAUt8DmJcRV739an/FdFW9Pgfk/jEc04datg+kGRP6u+4yJhgE0rkxi8GDiK\n3Ia6vzW/aCRw5cPp8TrZ/MNlvnDKtLmUu14C/Udrdi6lGUQMqs67Q6qzLOKvwHKT\nIkUYF27N+H62YD4baSQ6EuyJV2RYF8di/8nhm7ks+ZN6yZVkZwBB78BxZpE1rb0q\nEZH0TyTeaSG9HHAwtdAkDj8FdU7xXqCish1nLKTQbQYW1A3CdnUtNUMiK8rt8NRR\nHWngd+G1zxuqwmTr6AVPxa175ESThOm2wX9t/kj5QstuNvl0LXGl/QqQpuAWIN5N\nh398Rjh4h6OIONBt7TpE0sU2SzPOGeUuUsanHAFeUOFaqpmYm/HaS9CIre46zhSg\nnWvDrRieto9iUziXyHpU5yS5l/ugYHpj6zff+L7IJUDgT/Xmb8kVs/2QvIUqcsFf\nElYzEChdtuZNTe4Rpk80T5igCY+GdfC+3rfWVSpbaQ3UeMFPZdK01nZ3StvZYC0p\nTCzm4m7REBxonJ67z1/OqliNevU2Uh8tHS1Y7XUQ3v0vzX5+HXl95waim8+saYoY\n85Um+em7RZ8iGDu4ScBRAqrn0V+iAjYyEwldBx6UqalkGO7fqdDwcmw8mpEm5lXw\ni2FM/IH+LoxylbEQLgUuhzv3XM8ncW0jlj+ibgYteDSxxhpHkAbImpRV6XYw6ouM\nKYsRmh5RsvuJ/sf61wLRFcG3rQihvf/NAZs40qGaTbFIxYr0DLkbMkCVilPIaW86\nzFM=\n-----END ENCRYPTED PRIVATE KEY-----",
        ),

        'alpha-root-1' => OpenXPKI::Test::CertHelper::Database::Cert->new(
            label => 'ALPHA Root CA 1',
            name => 'alpha-root-1',
            db => {
                authority_key_identifier => '01:05:8E:56:D4:90:A1:3F:28:99:28:9E:8A:57:CB:C5:7D:C5:FF:09',
                cert_key => '2',
                data => "-----BEGIN CERTIFICATE-----\nMIIDjzCCAnegAwIBAgIBAjANBgkqhkiG9w0BAQsFADBYMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGDAWBgNVBAMMD0FMUEhBIFJvb3QgQ0EgMTAiGA8yMDA2MDEwMTAwMDAwMFoYDzIw\nMDcwMTMxMjM1OTU5WjBYMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZImiZPy\nLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxGDAWBgNVBAMMD0FMUEhBIFJv\nb3QgQ0EgMTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKUNCn56ksG3\nxJszHJNDH9ZiYB9q1ftkhbqhT4+0mlQ9IxMLCfiwM/2niYPBiM+whwO81/AVeUI7\nBg0KA9qh9r02o0Y5MrrrPqq2VmFVf9o8TdTTeQh3JmjWFkAiPFoeEmgVVGBB0MkO\nRhbV9jaBmdM1kZIHmE7D5lN7dv3LS64DLgnsxGdULe8XX1bRMggh5X77fRaDJiol\noVrDspQgxM9ZaQhNb4OTr5mZN9vRRasHO4LuSFmJ1ML13azdXkAyriOvYuKM2PgH\nepclvdWlTW8TJ7eBe5l+TKC34QZ3G1bzA2kJhn9UtaKeFNUjK3xqXaj8TgMJYqT0\nxn5Ph1hGkUMCAwEAAaNgMF4wDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUAQWO\nVtSQoT8omSieilfLxX3F/wkwHwYDVR0jBBgwFoAUAQWOVtSQoT8omSieilfLxX3F\n/wkwCwYDVR0PBAQDAgEGMA0GCSqGSIb3DQEBCwUAA4IBAQACmeh+dHzEiFCym0Ps\nnXdeOfTgxDrGJ82MdrjAvKq8XzziOgg9HTO31KZkHO30pj9gCXEiUu2sq09HT9xB\nOtoSkoHEMpA77ySox0QrrW6SRKrEwlw2/IZasxh+16YMNgAS57jwuvCK8aB3hmTO\n0VMOMbyXNND6IZSqB/cQOlxdwbjsLDXlQUYBdTAgLwOJAmvSwCGnQaNFk9NRqWOJ\nXFGhzI9liAJk8OMySedOiczoPGIlC4h6Mibr+DDMmPg21pCnPELaTeIH9lUoZ4Hd\nBMy+bcjhriUlnwUBYdXYPxkxIOn31747z0SZc9IiGYkL3kSsoQ6sNeURlulR8w1y\nEoN3\n-----END CERTIFICATE-----",
                hold_instruction_code => undef,
                identifier => 'U2wfk3NTE0dLNL1QjM7VxPFgfiM',
                invalidity_time => undef,
                issuer_dn => 'CN=ALPHA Root CA 1,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'U2wfk3NTE0dLNL1QjM7VxPFgfiM',
                notafter => '1170287999', # 2007-01-31T23:59:59
                notbefore => '1136073600', # 2006-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:a5:0d:0a:7e:7a:92:c1:b7:c4:9b:33:1c:93:43:\n    1f:d6:62:60:1f:6a:d5:fb:64:85:ba:a1:4f:8f:b4:\n    9a:54:3d:23:13:0b:09:f8:b0:33:fd:a7:89:83:c1:\n    88:cf:b0:87:03:bc:d7:f0:15:79:42:3b:06:0d:0a:\n    03:da:a1:f6:bd:36:a3:46:39:32:ba:eb:3e:aa:b6:\n    56:61:55:7f:da:3c:4d:d4:d3:79:08:77:26:68:d6:\n    16:40:22:3c:5a:1e:12:68:15:54:60:41:d0:c9:0e:\n    46:16:d5:f6:36:81:99:d3:35:91:92:07:98:4e:c3:\n    e6:53:7b:76:fd:cb:4b:ae:03:2e:09:ec:c4:67:54:\n    2d:ef:17:5f:56:d1:32:08:21:e5:7e:fb:7d:16:83:\n    26:2a:25:a1:5a:c3:b2:94:20:c4:cf:59:69:08:4d:\n    6f:83:93:af:99:99:37:db:d1:45:ab:07:3b:82:ee:\n    48:59:89:d4:c2:f5:dd:ac:dd:5e:40:32:ae:23:af:\n    62:e2:8c:d8:f8:07:7a:97:25:bd:d5:a5:4d:6f:13:\n    27:b7:81:7b:99:7e:4c:a0:b7:e1:06:77:1b:56:f3:\n    03:69:09:86:7f:54:b5:a2:9e:14:d5:23:2b:7c:6a:\n    5d:a8:fc:4e:03:09:62:a4:f4:c6:7e:4f:87:58:46:\n    91:43\nExponent: 65537 (0x10001)\n",
                reason_code => undef,
                req_key => undef,
                revocation_time => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA Root CA 1,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '01:05:8E:56:D4:90:A1:3F:28:99:28:9E:8A:57:CB:C5:7D:C5:FF:09',
            },
            db_alias => {
                alias => 'root-1',
                generation => '1',
                group_id => 'root',
            },
            private_key => "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFDjBABgkqhkiG9w0BBQ0wMzAbBgkqhkiG9w0BBQwwDgQI+j4h/wM9Do4CAggA\nMBQGCCqGSIb3DQMHBAh4TdBv7jm/2gSCBMgkoDKbhuBSEK/gWu0t/O++oQggzeFX\nMWXaEBdftGsDajR3zkMhoTseMZKki/2cKri/ghnsafEwx9198DYL6wVfY79X3IpJ\ngnvyQMf+1BXICCbl0BoAJgkasoRn320g4qOA3Wcxwiy4OwEJ8WPpKhDaSX27FRRG\nH+UyjcU5h3Z1FG9fzxj+Tw2kw/4S7vNxxd4JAIXiP6yd7TgH9EzQBACib+yK3M4T\nd0+zjYSH37laKai8DDsfg/zIf9a/qX2KPc2x1JvhCE+gfxMhNXMqX0bqfSJS7qNB\ntpo4dtfgmXo7DUNtYViLUD38W+q1+oj/lc/JAq01jzWJIJYbCvMxH5GhzfybL2Bm\nvAYzCs0dNCeBDmNMhpnyXXhKoSVNMQVn8PQzCmja3GSkqO7KYKBgkjKLCqToCBWy\npwAVE4pl1zQ4dG+plnb751qAIbXggWTO/ruanYgBU6A3dd6vajdr87GjbWI+KYp5\nN6pmrHP5kVffcfg4Npwj848GBKlpac/884lhke9Cz41PFQgADa9v+K3ABDLNyX2x\nQ0EcUINYEGziaheRqCn5GDomiaivSfzKeOA7Xzk+CgLL8UJCxCoDjoYXYMXkh77J\nWwR1U8fQgm/1IoaKjsFayL0XXn3vPqGsKT+SjTvnmoXCTS9G3OQ0PVudexIRaUjy\nqz91B/df3eVW+PDyI/qeKUByTCmuB6Vg98+2nigHi4kL6uI19xvLgKMoWShJuoO8\nXg6AleTjN8uAsqP01s5hitWUpkdKAvsN7WtWNceEjKr2HCKGbBGKse6Uj8ZuVeiI\npZGPR6pOsX5P7iIH/s3DEyepbilXV24oEpl/KRSuchhHjnNCOdCn5ETdU8+2zqhJ\n8przqvGvyZSfD8F6TZG9UVyFFv9H69zcyTdOgUFHxKuuDL5LT3eM7pDA4pJC3lAz\nft37H4/CWHzChwqyEDBUNklcUQEBcr9I3W4OhxAG/VpVYFpQLfVCEdM4V9G6s45c\niShvQmDsxXGds0iEIMoXM9+xsVJHPncxHMRSBSo6H7xiElsZpdiJQYluvMI+XNju\nbv99Ut7SWnCRQEif3Sbx6eHAg/hCg8qwHsk10TlyC0i/njFcaU011pUjohgF4oLQ\nnhnaqsypJD8cHx1gFy3kB7Fcb00t5hVWCgKOj6fY/2HeE6u4zHH79cUU5CugiYTR\nz09IHwTLpMDNd3ksrOyUUY3BAn+ykGAwWRL1JjmZZi0zO2a+PZ7PKyVy8EfkiPc1\nUdJjqivhoEIANXIutkUlZ+Bds9Gu5BNM7qebrJmpdZfRncXZIndEylOgwlq1+oDi\nrqpyqUfUcyUr2mrR+6zxeUUSudlN8r+aiceLhVEPeA8djRssYs/hTZ76TebNYbea\n1WGa+pwtGxCspuGr//B1IITx3GBip36b7nOzasIk2o0/dWqS2w5Y0q/ZHoQV4kQc\n2mkSkh+1dGg462TYg52/UDMHGhnZ+inn3pjPvFnPDqtScTEecf+AnI7VEP+MNOEf\nWb4750BB8ynNt36V+iWYM8BCZ0rbMPd2luhN/3d7/JdAZzBA6UVrJoQM/NRKnavy\n+vU1G+Uod78lrOIhtVaT6xueBDSdSdWepPHTMjLxjJrPDTS7PYgT+VIrwoC72qO5\nhp8=\n-----END ENCRYPTED PRIVATE KEY-----",
        ),

        'alpha-root-2' => OpenXPKI::Test::CertHelper::Database::Cert->new(
            label => 'ALPHA Root CA 2',
            name => 'alpha-root-2',
            db => {
                authority_key_identifier => '8C:D5:B9:85:26:93:8D:F2:BA:46:71:BF:6D:85:2B:BD:5F:2D:41:95',
                cert_key => '8',
                data => "-----BEGIN CERTIFICATE-----\nMIIDjzCCAnegAwIBAgIBCDANBgkqhkiG9w0BAQsFADBYMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGDAWBgNVBAMMD0FMUEhBIFJvb3QgQ0EgMjAiGA8yMDA3MDEwMTAwMDAwMFoYDzIx\nMDAwMTMxMjM1OTU5WjBYMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZImiZPy\nLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxGDAWBgNVBAMMD0FMUEhBIFJv\nb3QgQ0EgMjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANziBj72oup2\nX3QNFhZEQW5aZqv/4Q0jp8bA6mdNYC0ZFVHyE3OP0E3myc7IJfGW1mJH2ojtJ1ms\ngB0Z3DlAgec76kwo0Q36MLNmuB/DAN5+4P3wYhW3eCRgfLWcdzkYTRYxAL8O7XuK\nBVOPVt34CRnYct9pPojpLL/goi70bxQ153+ZgO3zJPdmT7vPMNU7pTBFRYUIpHRF\njwo6qerCV2AvveXp4kjJe2AHvbL0JCN+pdm0lFG7WY0sQN2PLei+qplRWkM8eOjH\nrPMv/C0/Saqly37QapyIqq/7jvxz6jv0F0uBbc5tQmT4Oidl/KNnBZAdNpKx4xoB\n3swjYPMYPysCAwEAAaNgMF4wDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUjNW5\nhSaTjfK6RnG/bYUrvV8tQZUwHwYDVR0jBBgwFoAUjNW5hSaTjfK6RnG/bYUrvV8t\nQZUwCwYDVR0PBAQDAgEGMA0GCSqGSIb3DQEBCwUAA4IBAQCoqYzWPbowgJxmR1Mb\nIMhyyg7VdF44P8e8Sv2h+i2LaWBY6HwUVkDByqCEDysWfvH4RNzjNNiWQ10yoiFp\n59NQcNjXC5GMZZYdLjB/+OkVUAT8KwV+GMeB9LTSju4yMxmvtjj+auVZmadADh1b\n7/atPtRSAH/O9CJTXupoceh/AXeYV9Vx2J7Y4cujHIH3H326QidnR9zeUyha8wqF\n1/nwFOwt5CFZ89PjyAl/D2g0IowNNHRGdm7oLvQAR8HDwFvlS+Qpc2PLYiqGG8eo\nK7jxPAQWCvdQU5b3xFYUehK35E58DTGA0wnKrAxeB47ZrZF11jc9xrMCGg2BLm8R\n+UwW\n-----END CERTIFICATE-----",
                hold_instruction_code => undef,
                identifier => 'vNeMl9bFa8p1-cHcGaDjfSiX_NA',
                invalidity_time => undef,
                issuer_dn => 'CN=ALPHA Root CA 2,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'vNeMl9bFa8p1-cHcGaDjfSiX_NA',
                notafter => '4105123199', # 2100-01-31T23:59:59
                notbefore => '1167609600', # 2007-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:dc:e2:06:3e:f6:a2:ea:76:5f:74:0d:16:16:44:\n    41:6e:5a:66:ab:ff:e1:0d:23:a7:c6:c0:ea:67:4d:\n    60:2d:19:15:51:f2:13:73:8f:d0:4d:e6:c9:ce:c8:\n    25:f1:96:d6:62:47:da:88:ed:27:59:ac:80:1d:19:\n    dc:39:40:81:e7:3b:ea:4c:28:d1:0d:fa:30:b3:66:\n    b8:1f:c3:00:de:7e:e0:fd:f0:62:15:b7:78:24:60:\n    7c:b5:9c:77:39:18:4d:16:31:00:bf:0e:ed:7b:8a:\n    05:53:8f:56:dd:f8:09:19:d8:72:df:69:3e:88:e9:\n    2c:bf:e0:a2:2e:f4:6f:14:35:e7:7f:99:80:ed:f3:\n    24:f7:66:4f:bb:cf:30:d5:3b:a5:30:45:45:85:08:\n    a4:74:45:8f:0a:3a:a9:ea:c2:57:60:2f:bd:e5:e9:\n    e2:48:c9:7b:60:07:bd:b2:f4:24:23:7e:a5:d9:b4:\n    94:51:bb:59:8d:2c:40:dd:8f:2d:e8:be:aa:99:51:\n    5a:43:3c:78:e8:c7:ac:f3:2f:fc:2d:3f:49:aa:a5:\n    cb:7e:d0:6a:9c:88:aa:af:fb:8e:fc:73:ea:3b:f4:\n    17:4b:81:6d:ce:6d:42:64:f8:3a:27:65:fc:a3:67:\n    05:90:1d:36:92:b1:e3:1a:01:de:cc:23:60:f3:18:\n    3f:2b\nExponent: 65537 (0x10001)\n",
                reason_code => undef,
                req_key => undef,
                revocation_time => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA Root CA 2,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '8C:D5:B9:85:26:93:8D:F2:BA:46:71:BF:6D:85:2B:BD:5F:2D:41:95',
            },
            db_alias => {
                alias => 'root-2',
                generation => '2',
                group_id => 'root',
            },
            private_key => "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFDjBABgkqhkiG9w0BBQ0wMzAbBgkqhkiG9w0BBQwwDgQIEnI8j/VpMrwCAggA\nMBQGCCqGSIb3DQMHBAjOB9BwxNB5EwSCBMg04NszE3X0wi5M1i0RogK8t+aj6fSy\n4ZA/AREIAgnrtBrpDHA0m5ZY+Sl8TAOXH6INtTe0ZaOYbLWQ2ykKViQoC41U5Q/i\ncM+qGJBeVTk58OOsVDZ8yzktxA769hHrfE5tEw/pf+oD0kDtGI3qkBIfTTMzSIfI\n+Lrou/81DBSqohLQsfBX/xnsOO7uOVZzHUIVTfaOK6K5DUjpmTNuBx0WeOy9iQWD\nfaDwLenCefi8mJ+Mlg1gLeM3KODcQ1XYVpfAmyzm5y93dq3dwOOqZ6gi63CqaFwD\nisXtXwV8eBVx0P1XM+J0tkwRpeGz4gFPfwrXfHmhvxcfrC4frWrH8q42xF8v9l+B\nP+pWM94y2oVjeE4KOnh9aRWSShrcrQt5n3JUVWjsdVRhgwU4TGrH1pzCJYgtKENc\nitQYlKkikS5t7VbGuCdjyhhNU3BrXux1vpbo+l5O/071udUnSoA/ZLlAA5hpnkNh\n5T1N6a7cINW+3ulLQFyCeqqx5xSaPr1do7PWOwpoxt/z7SCyTSuf06NZ97HlZcNR\nhtwLjb40Wkm6RhkkucxmceXIgjrHC15b5zMQpseZT7NJ++nY6MsOBaLRon+V0CSW\nUir/HpiQD28fJieNKKRUGL099kmk8dWUCtuEUh1+vPwIhKomLbA2pngTqiFhEov7\nUWfk0+G9yL2x/maLzowyc9WyLcx2JxVV+Ie/ZJJLzsbs62fyjaRNkHxW/dYcEs8j\nDLEThLTq8mg0BChol8Z7zGceAu6rlCu2S19dYSIRV57gQNn2ttso6ubGqJxSZcsl\nKIIpo9seJTMGFaM8ztXmPEazX8G/+oIIe2kjC2Dm+HmvxXktdzASZCoCmvbSVORn\nHKQV2zZFbfRtnb9Gk8Hh5IJp/xgzvCterG4JqJQAnS3GUAjo9WN75pJoGp3E5mMr\nIoFbqH9OHFWDvIGK3ps2s8DLR67njeu2z+3bseabnr3Ay/qaiqIYkh3zLdpKxmIF\nWZrYzlJBLPd3HFuxOd6XWJTOP89u3qnwBjzvINTOQjLaTBFBlcxOk3mpB2amNmIt\nCCy/DuPjsv1kgoriVk6Dxm102IB1TxnSvvY1KhxAx3LtJYHooKoKW3HUO+/rkOUN\nx0+/Q0pf/bOaItsqOez817onQJswXkaMAnG9Ln2G90FZmBmk7kDpS4RaLFFvFvjC\ngR2NamklQI3q0m83+mks0PJYNY2geQQJDHqzZRRqC1f0nHTnw77aFcevHdz8HHXd\nE8uvYbRyBy4Wfc9gWf1/vX7mECI6U50CtjX5ArlZFwP2PjbY9eVIp595d/4a2xOP\npDwhwZl6SBKlx6EIS7V3iAdsxdfjAbv2xpIvqDRzDl9nqJMmJc2W4JMalEtpZLzd\nByzMwUVFsHyKrHEaOiXm3JlDyhVy9DpmrQbcBjaofnN/Y5wlIsY49B+Ff1G94Iwq\nZD9oFBr0/QJ7blbjisuwjW6nb6s8fMGa5xP2lfpEyBqze4bDnVyQXNFR9TzNYSTh\nTwN6m0GJ3bdHhOzCLSUFg5DX3sBKGDS6M1hi4YBceqJjm4Ii0b6nwtu0S+qQEdiG\nGHxJSC6gC2QVo0cJxGiOZrOQndNBqje3MRfJVmnWr5jXuLz24f4Zpg029TWyk1Ew\nQs8=\n-----END ENCRYPTED PRIVATE KEY-----",
        ),

        'alpha-root-3' => OpenXPKI::Test::CertHelper::Database::Cert->new(
            label => 'ALPHA Root CA 3',
            name => 'alpha-root-3',
            db => {
                authority_key_identifier => '77:B2:F9:12:4B:EF:BE:E0:AC:48:41:67:0B:C5:E1:15:32:FF:3D:0D',
                cert_key => '16',
                data => "-----BEGIN CERTIFICATE-----\nMIIDjzCCAnegAwIBAgIBEDANBgkqhkiG9w0BAQsFADBYMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGDAWBgNVBAMMD0FMUEhBIFJvb3QgQ0EgMzAiGA8yMTAwMDEwMTAwMDAwMFoYDzIx\nMDUwMTMxMjM1OTU5WjBYMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZImiZPy\nLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxGDAWBgNVBAMMD0FMUEhBIFJv\nb3QgQ0EgMzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAM/nJLUrmqUZ\n5XhzBu1w7GGYJy1ojZ0qNnVunPF0vZcij3N/ao9zxTdFtw8y4frguMk+fUXpwSnQ\nMdpX8YlwkIAK0wtdVJWxgyQyrxnLFDWS4db4mllSHQ3o+TCBmtSzNzHE0yI5I9JS\nSPasUSsNfnb+H3lczv87GrXdHF0gWHJLSjfatMl757M+sTGrlARtPWXHTMcdDTzM\nQd6N8+ZpViIhOB1s3tSlN6KeHBLl2PCLjT5QniTBBD6AyxiaeVD8UcSH0vgc6Mys\nbBeFmHxHg0NxpwLgflPQyp+f5lY/bH1wMwrg0D8ahg2DavaW+jAyqdKKlRbLm3G3\nDaZd8nUNs20CAwEAAaNgMF4wDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUd7L5\nEkvvvuCsSEFnC8XhFTL/PQ0wHwYDVR0jBBgwFoAUd7L5EkvvvuCsSEFnC8XhFTL/\nPQ0wCwYDVR0PBAQDAgEGMA0GCSqGSIb3DQEBCwUAA4IBAQAzvPfFqmQTaqVMf5Vp\nbwHkRz0m5azKlRIX2Scj7SfGEy5orCp0i/5CBJoeKpqlzB8OABOgcgVIrsTCLn4N\nEyyJU2bIu+5FQAAu3tKgT/kTQIl/ft5hDseZ4IUoviS4kGoxiMeoO2fChIgRoT30\nmwGuKKh7S19Dj/F1YTFj6NqgmQd9W0+09aOrFSFHnmyaPRfxG/9nS9YkeiT42gYh\nLv6BkfmtDu/gZfyixlYUKcozpvsLodsmGatZj1xehp8PmqhbMMjejprWIjkPkQTL\n/gVPk78dYHbcMyqzyT02wNRtE8J5oqEDrXVrgN4sfVC3rZKnf2T7Nl3hDA+I+O/b\nFQ+n\n-----END CERTIFICATE-----",
                hold_instruction_code => undef,
                identifier => 'wXBasWhcc4eGcYLGdFWjeci7w8E',
                invalidity_time => undef,
                issuer_dn => 'CN=ALPHA Root CA 3,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'wXBasWhcc4eGcYLGdFWjeci7w8E',
                notafter => '4262889599', # 2105-01-31T23:59:59
                notbefore => '4102444800', # 2100-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:cf:e7:24:b5:2b:9a:a5:19:e5:78:73:06:ed:70:\n    ec:61:98:27:2d:68:8d:9d:2a:36:75:6e:9c:f1:74:\n    bd:97:22:8f:73:7f:6a:8f:73:c5:37:45:b7:0f:32:\n    e1:fa:e0:b8:c9:3e:7d:45:e9:c1:29:d0:31:da:57:\n    f1:89:70:90:80:0a:d3:0b:5d:54:95:b1:83:24:32:\n    af:19:cb:14:35:92:e1:d6:f8:9a:59:52:1d:0d:e8:\n    f9:30:81:9a:d4:b3:37:31:c4:d3:22:39:23:d2:52:\n    48:f6:ac:51:2b:0d:7e:76:fe:1f:79:5c:ce:ff:3b:\n    1a:b5:dd:1c:5d:20:58:72:4b:4a:37:da:b4:c9:7b:\n    e7:b3:3e:b1:31:ab:94:04:6d:3d:65:c7:4c:c7:1d:\n    0d:3c:cc:41:de:8d:f3:e6:69:56:22:21:38:1d:6c:\n    de:d4:a5:37:a2:9e:1c:12:e5:d8:f0:8b:8d:3e:50:\n    9e:24:c1:04:3e:80:cb:18:9a:79:50:fc:51:c4:87:\n    d2:f8:1c:e8:cc:ac:6c:17:85:98:7c:47:83:43:71:\n    a7:02:e0:7e:53:d0:ca:9f:9f:e6:56:3f:6c:7d:70:\n    33:0a:e0:d0:3f:1a:86:0d:83:6a:f6:96:fa:30:32:\n    a9:d2:8a:95:16:cb:9b:71:b7:0d:a6:5d:f2:75:0d:\n    b3:6d\nExponent: 65537 (0x10001)\n",
                reason_code => undef,
                req_key => undef,
                revocation_time => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA Root CA 3,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '77:B2:F9:12:4B:EF:BE:E0:AC:48:41:67:0B:C5:E1:15:32:FF:3D:0D',
            },
            db_alias => {
                alias => 'root-3',
                generation => '3',
                group_id => 'root',
            },
            private_key => "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFDjBABgkqhkiG9w0BBQ0wMzAbBgkqhkiG9w0BBQwwDgQIpsRjPx7RJ1oCAggA\nMBQGCCqGSIb3DQMHBAhqqkwywBY8bQSCBMj0UBNbCKok+l5iuw1h08o3Uz4GVIDm\nd5QH+bkIjiBNiaQJktTikQdskID5Xk4sixG9VUD6TWz0IrYE290zZRkxtLc/P7rC\nF+5EGtzw00BM0jdNhc+H9XvYgwj8w9+SpEnzlsO/PJ9a8RYqmyb1NZ+/lr7V/lez\nV7XRHXAcgEsyYIQS2U84EAnfv76UgGoELicAAhWEedZr2CPlqJHXcq3eSs9W5e28\ni82IfwfnlOjuUpv2z2hg7wfTmqHMdM0dogayAwa734mQ3mQlFeP3LnN+OWlQs6KN\nfqf1edQnZoGxMWAvcjww9tgMB02m6XVaxR0y9BkLwGpgqiELlyoYGK5ZZEl5ROTP\ndappvYomO0t14F83H1tOf2i+FJc19xjvTvg3jiWG+NIQtaAlj3cxKovCumQRf5Yp\nMgWDJSekbdDhWZtcXbFx4DFL4+Ch/rL1yO0S3y6aQ18UUkZUdZ7jTBObxcjgaXaW\nkB+UUOJDw8evD63QgtayaOCsmQ3VI8HbjPMHipWW+N31g21IYfWusF1S4OFDOL3p\nHjGO5ZOMEM5RleO2CeakctAWYxjk634F1KItKAOLM2SHBx5N3vMyDXmhqy4lbMZM\ne9rgv5ypOdt0ifhqaa5Z7nCtfCu0L8hpeuJansgNYfDOSXaSX7w/j7NgLlnvy6PY\nU+LASN77WJuDAOPa0A1hLLKzDlNGmSp1kyQF4J4xitM2wUKWHtSMJovmb/7qaiur\nOwaBThMb1IfYpnDrkUT/X6fb2ziLnI3XofUZ+TvIE5LqnN+mHlQpsWgtvkgZYtK8\nS5k5Zg4djHakb8ddQUBD1mfmrFn7k7Vxlt59BAc+XXnWKw2+iocxwrICnrXXb43C\n4Y+TnEKlZGSADnnC3HbZ5JluXvdZoEqKy2FszMwvjl3TdOw++QR6CLuBIgSFbNlM\nffc+M5aUGGzAt7HQGyxw+OmFNaYZk7oShHLt25veta3mcJjojuFKt4qzDaBks4uM\nAxqeDsWL4EBultUXPAChYl6q6KpTak2v0a+38e6QMdJbJYAcwsRLWYsbU8Tmg1Br\nEFAUomP6iR3G2G+ig9YLv7MadqeMbUcoXfnU/vSZNNmBQEU4hRegKWhLXfu6i3xW\niY8roJJxqRVJThjHKouPht5wA9Y+TwFPXnTDSs9fk6DyeQreUlNQUMKIlJFOGuF4\nJAKYzjR+VRfNEZLtxOpKNDccuwFgilGL5HGEu4lRYCm4McSk/TUdE/NuCBkHzhHi\nF8XJoAbFdbXWQJaoi5EfErpoJzBcPUkrKrqbsM/h0YB41Nkekmr5KwPVoYfE6u4m\nidUO2X1qWAFEjXJhptN5KOgmP4tPFn/axz4gs4ns/Xq4INjGy+RKWwklkZ31I1mN\n7rQK+1SGFeq+jhOWzugt5217mutZb78+4SY7nd4A0njw/Px7zbu/5Ob4Th8067Dz\nDEiPSp3+4B6OTXb8PSnzyKVnEWJwR1Tj4VtgdRqmu0eHOVMQJWfuYHrJvPsOFwBk\nAYv7qZYYMY243OehTkwNPYmSrQ/ifZEkddELZBs/KjOetUK2jxjM0daX3GlVZnoR\nJlIKJKpdpnlizrBgTccPIT1rHn9QRUXOIcz+p4oWMia6RwGxXkcfRA10mGWNQnCv\nQ30=\n-----END ENCRYPTED PRIVATE KEY-----",
        ),

        'beta-alice-1' => OpenXPKI::Test::CertHelper::Database::Cert->new(
            label => 'BETA Client Alice 1',
            name => 'beta-alice-1',
            db => {
                authority_key_identifier => '13:0A:CC:77:DE:8E:E7:9B:37:D0:E5:4D:8C:26:72:F7:D5:5C:6D:4D',
                cert_key => '25',
                data => "-----BEGIN CERTIFICATE-----\nMIIDgjCCAmqgAwIBAgIBGTANBgkqhkiG9w0BAQsFADBaMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGjAYBgNVBAMMEUJFVEEgU2lnbmluZyBDQSAxMCIYDzIwMTcwMTAxMDAwMDAwWhgP\nMjEwNTAxMzEyMzU5NTlaMFwxEzARBgoJkiaJk/IsZAEZFgNPUkcxGDAWBgoJkiaJ\nk/IsZAEZFghPcGVuWFBLSTENMAsGA1UECwwEQUNNRTEcMBoGA1UEAwwTQkVUQSBD\nbGllbnQgQWxpY2UgMTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAN/8\n8V/ini5h+lbLpWO2BCdcrXs5eFoalFqojI2spZSR5+RDXgYtSL/yAgd7++du9s7O\n0oMZ2G2LrjsNELE0L7rpawGOE4XJ8So5vt63xHA37T23j+u2auu2hLAEKqg/nBJB\nk2/zdrX6KCAdvicnRuDFoTNW/xeC2KhPTzpP1ZkBdhiBuywuVIMXTB5+gMXrqU01\nChOQoiH6iLVjZiczgQD+m09IriSbQ9w06z1b0w18IEW/arsrD3c93DjPP8b//xYE\nBFTd4vTRo1fTf/l5PnCA7fDRFGMPdRccjI/5HneAriCTalAXIX9jYQ2tu4KnNw2v\nVD4aHFMzSVp7KUYAmkcCAwEAAaNNMEswCQYDVR0TBAIwADAdBgNVHQ4EFgQUaFwc\nLaVMq7euXRuvCpMqOgw4oLwwHwYDVR0jBBgwFoAUEwrMd96O55s30OVNjCZy99Vc\nbU0wDQYJKoZIhvcNAQELBQADggEBAONDE04LgcsqQZ95YkOUVkYFguGl3EChPNdz\nDwj3kxScQD8WCEhrgKB6cAkVFyzf3mV0Rtt73waCAnVHnixL40KePJogZiG71nNV\nd1Ayw3mfm9bvP5McLzG+Hfjt6NYHCuchKUftbJMj0IYmloaOXo8OKFm0Jcol4aTo\nH6J1MxGg7pg8YIHU8h05AUApGOlcA+qb13L9twV1zTe8mI3pVj2AlUzPVVYtdlVN\nYBilQ1mMF6GGUpzO/RfLJwOp4KqtPB7eaOOW2CmuVblDdWZYBGQ2agmC8ampso7m\naf/KcKdyPgBFfh41HVMRrd5aftjoC5lj+O2REJMneoUciI+ZmTo=\n-----END CERTIFICATE-----",
                hold_instruction_code => undef,
                identifier => 'l2ajTRh4IM4Xuqt06roUxMtdZEE',
                invalidity_time => undef,
                issuer_dn => 'CN=BETA Signing CA 1,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => '3z1luFO6vA0chsdpSm5CiDv12xA',
                notafter => '4262889599', # 2105-01-31T23:59:59
                notbefore => '1483228800', # 2017-01-01T00:00:00
                pki_realm => 'beta',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:df:fc:f1:5f:e2:9e:2e:61:fa:56:cb:a5:63:b6:\n    04:27:5c:ad:7b:39:78:5a:1a:94:5a:a8:8c:8d:ac:\n    a5:94:91:e7:e4:43:5e:06:2d:48:bf:f2:02:07:7b:\n    fb:e7:6e:f6:ce:ce:d2:83:19:d8:6d:8b:ae:3b:0d:\n    10:b1:34:2f:ba:e9:6b:01:8e:13:85:c9:f1:2a:39:\n    be:de:b7:c4:70:37:ed:3d:b7:8f:eb:b6:6a:eb:b6:\n    84:b0:04:2a:a8:3f:9c:12:41:93:6f:f3:76:b5:fa:\n    28:20:1d:be:27:27:46:e0:c5:a1:33:56:ff:17:82:\n    d8:a8:4f:4f:3a:4f:d5:99:01:76:18:81:bb:2c:2e:\n    54:83:17:4c:1e:7e:80:c5:eb:a9:4d:35:0a:13:90:\n    a2:21:fa:88:b5:63:66:27:33:81:00:fe:9b:4f:48:\n    ae:24:9b:43:dc:34:eb:3d:5b:d3:0d:7c:20:45:bf:\n    6a:bb:2b:0f:77:3d:dc:38:cf:3f:c6:ff:ff:16:04:\n    04:54:dd:e2:f4:d1:a3:57:d3:7f:f9:79:3e:70:80:\n    ed:f0:d1:14:63:0f:75:17:1c:8c:8f:f9:1e:77:80:\n    ae:20:93:6a:50:17:21:7f:63:61:0d:ad:bb:82:a7:\n    37:0d:af:54:3e:1a:1c:53:33:49:5a:7b:29:46:00:\n    9a:47\nExponent: 65537 (0x10001)\n",
                reason_code => undef,
                req_key => undef,
                revocation_time => undef,
                status => 'ISSUED',
                subject => 'CN=BETA Client Alice 1,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '68:5C:1C:2D:A5:4C:AB:B7:AE:5D:1B:AF:0A:93:2A:3A:0C:38:A0:BC',
            },
            db_alias => {
                alias => 'beta-alice-1',
                generation => undef,
                group_id => undef,
            },
            private_key => "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFDjBABgkqhkiG9w0BBQ0wMzAbBgkqhkiG9w0BBQwwDgQI7wCOp0/4A54CAggA\nMBQGCCqGSIb3DQMHBAjJfxFDafCgRASCBMivjolg1pPj5Tyo/LJpAxqqv2xmXuhd\nfBwQIHSyxztC26Z5k/nZTRkZH8PrAtfIfvWJUan/zNECYAo8YyuzKLtBxdF9jRNE\nZfaV+JdoEnLledBtjNe4AWIt3h4OpJ04mLUtLpmOsQS+hEgQkL4NlUnR3e92cAcP\nXNC5t518JEOk582CDTQH2K2MzTlvCMuYRm2FFRr02MviSR1Y0ip1CyJg5HPzFUEB\n1hqjVfCNnWf891aKuMt6S4tMRPz/uY1uEW2zBnmV9ItqIef9WiBY6T0veQe08Wyl\ncYkMBxmMjjpBBzC8WjUc6TQw8IF2yaGAyH+HmuRRj09CZEHpb8eajN09iJVFXLzc\nqN4e/E8UDFAWqTtLJbt/QPh8UgUUIit2RO0ujwbxYnXNj+/vCSODlZ/PL1pbiQwh\nlLIxbUKTbxutzH46JBm5ecfOk2PezUQQzsmfbFG//Cs+Vfi063AowxL1kTtqF6T2\nMkL00YlFxNOMP8PFArTwVFxA7RgpXhXD9od/8ifoQshyhwkoGbc9yXjic7wbuPWP\nd2eb0LP0FEfeE7zkkjDtvBfFFzIQ0GzBn+nyPiCDaTrtCQ5mDkqOwb2Mu9BLYauT\nUAsAXqR6N6kKVEqnMO2w/MpxCXFLbulw8yHRVKVg+PEugkOARUq7B4Ju3bQ371IJ\nMx5IYiliQPDnD+RgP4FWqLSvIa4QpkQPrTlcSvB4kUMIAZyNxxFHX2wegBkNiFWA\nyL5rV5c2PhNsTILyaI6frWWj6Y3QuvK0+sTDs6EezRQ4HTxShvr39Wtx7fPYT/Lt\nFSr6pb0kq73vdYKURq2oZj0CU8iDQTPp0ZGlCwjSNs7wDiyYw7m/hg4UYHhVhzls\nkVA8zZscvZJ3bnX4gSAHMCviyNIIFgB5RzQQZZq4/kwm1phrwmWGk1jeF3djHbDU\n4/7YU1WPcgQ/tuZ9+X3lNl+UISu//P+sEizQ/76g/YlnidQ3XwhAIGZtvA9alev4\nCK+8akBO19tfGkOGRKPRATJflRNiM453gLGA2gCj0DeNgAwyHKV/NjOxeIdsj+Ib\nx5EEP+M34494pTkfVBO/MjKOGQDJIlYAo/AK2TKtvxPcSVOW5g8IDb3Ha77lfzbA\nQo/HYK2hX6XQXbnwdptlKJMx4LtsgyCt4ABAdp1vjgZ+zjQw8bGRG/JQUpnbBpuH\n8A47QNi5xJVOZfi7uXsgufcmrcIoOdVWhxmKVsFWpT7UAc7PuYQ980oHzf3p39C2\nEJt13VrHxTrBOufWcL4co/ulAkyTakrdL2Eiq0EWuYxCfGErPiybpahDe7WjRmy9\ndgu2aiXVvUV7Rql8ox4aCfTzuZ1qpoeqKBaFLrmECivGnfoXjf2RW+o/lJShus+r\nhpr7v8JiOibCN+4mj/l35f8+pQww3irRInaDAX16QvwAl+/8AsSGmDRdKH5atBnb\n+b1TRJSnLvvB7v2ByvFvhqOdTV9Pq7NGRpeEnkrKFU4V3O4/94MuvVI1V7mHNYph\nWo41uY3nrP+Qg3Ljlrs7BUbkjDQBi+slOoy3tDQMBWF5OEpf3Ob/BHSGV4CA5MTk\nGV9IClZaFWZHiL64dM6syeWMBkkRpsv+3FEJMHUX5uDdBjq8DQh2Ssu+ztvro1ch\nUWE=\n-----END ENCRYPTED PRIVATE KEY-----",
        ),

        'beta-bob-1' => OpenXPKI::Test::CertHelper::Database::Cert->new(
            label => 'BETA Client Bob 1',
            name => 'beta-bob-1',
            db => {
                authority_key_identifier => '13:0A:CC:77:DE:8E:E7:9B:37:D0:E5:4D:8C:26:72:F7:D5:5C:6D:4D',
                cert_key => '26',
                data => "-----BEGIN CERTIFICATE-----\nMIIDgDCCAmigAwIBAgIBGjANBgkqhkiG9w0BAQsFADBaMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGjAYBgNVBAMMEUJFVEEgU2lnbmluZyBDQSAxMCIYDzIwMTcwMTAxMDAwMDAwWhgP\nMjEwNTAxMzEyMzU5NTlaMFoxEzARBgoJkiaJk/IsZAEZFgNPUkcxGDAWBgoJkiaJ\nk/IsZAEZFghPcGVuWFBLSTENMAsGA1UECwwEQUNNRTEaMBgGA1UEAwwRQkVUQSBD\nbGllbnQgQm9iIDEwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDOnd0g\nmCgfS5bapVcHd2HYQ3OgFvihOVTQzU7RRXUI9dXlG2aNvIjcBhWYCbAGei1dVlJC\neMcB9yGkbEFlv5YB9jUsf28MOtbINLJrqtUN39vSWoEUpN7c58/8Pi4J4MmXg446\nO2LEee4P+CpOnQBSCT34rOxo1pQaHuhRyEtbS9TxCIfunubdVc/lu0UhWovK3olL\nRs80UV5BgykdJ2s70WnNAd3rSEvxar9ctt86+Hw+dJ98YA0gdkfu2HOjBMvIp/Zj\n/rBpdDPcdS9Q6LP/6rG/+zqzw6bYrCOQOO9CknleUoklfMdeBclwXsI5GJ4Vtiz6\nx/8kqzmEAFW8YihRAgMBAAGjTTBLMAkGA1UdEwQCMAAwHQYDVR0OBBYEFOdlMia9\nr18f+2H/SaSEfVRlmHh0MB8GA1UdIwQYMBaAFBMKzHfejuebN9DlTYwmcvfVXG1N\nMA0GCSqGSIb3DQEBCwUAA4IBAQA6JL6x8eliQTVa4mHGAV0n3FcZDx5zk+ctCiLg\nvHAUP+QDk6ogLXp3220KVrD8iRO+lecSJqVT5FV5LW/FEPbIpkUHlUUCrcQDPVb3\nxh+dIFvzS2W7np9oIUGMK0pzFF7pHPg1SWaE7oEnh3JZM1zG4ESjKDqCJvASKGOj\n54g+06aU9i+8DMv40+ExzSEp+O3YoDvgxMM7r/RVm845FrCqcUH0lr09R3o2+Qel\nl/9xhFPM/kinQgOYc3Tyu7fZErcdsS05H0WZvlFMtLrFpGiHmExzU/ywj92c0doj\nWMbULF4W4V57zUTRuzjznAC+rmQ+bE/DF12oh3/7VUuuwan1\n-----END CERTIFICATE-----",
                hold_instruction_code => undef,
                identifier => 'p7hiAKvh9r33ZoHUr7S-JbACFA0',
                invalidity_time => undef,
                issuer_dn => 'CN=BETA Signing CA 1,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => '3z1luFO6vA0chsdpSm5CiDv12xA',
                notafter => '4262889599', # 2105-01-31T23:59:59
                notbefore => '1483228800', # 2017-01-01T00:00:00
                pki_realm => 'beta',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:ce:9d:dd:20:98:28:1f:4b:96:da:a5:57:07:77:\n    61:d8:43:73:a0:16:f8:a1:39:54:d0:cd:4e:d1:45:\n    75:08:f5:d5:e5:1b:66:8d:bc:88:dc:06:15:98:09:\n    b0:06:7a:2d:5d:56:52:42:78:c7:01:f7:21:a4:6c:\n    41:65:bf:96:01:f6:35:2c:7f:6f:0c:3a:d6:c8:34:\n    b2:6b:aa:d5:0d:df:db:d2:5a:81:14:a4:de:dc:e7:\n    cf:fc:3e:2e:09:e0:c9:97:83:8e:3a:3b:62:c4:79:\n    ee:0f:f8:2a:4e:9d:00:52:09:3d:f8:ac:ec:68:d6:\n    94:1a:1e:e8:51:c8:4b:5b:4b:d4:f1:08:87:ee:9e:\n    e6:dd:55:cf:e5:bb:45:21:5a:8b:ca:de:89:4b:46:\n    cf:34:51:5e:41:83:29:1d:27:6b:3b:d1:69:cd:01:\n    dd:eb:48:4b:f1:6a:bf:5c:b6:df:3a:f8:7c:3e:74:\n    9f:7c:60:0d:20:76:47:ee:d8:73:a3:04:cb:c8:a7:\n    f6:63:fe:b0:69:74:33:dc:75:2f:50:e8:b3:ff:ea:\n    b1:bf:fb:3a:b3:c3:a6:d8:ac:23:90:38:ef:42:92:\n    79:5e:52:89:25:7c:c7:5e:05:c9:70:5e:c2:39:18:\n    9e:15:b6:2c:fa:c7:ff:24:ab:39:84:00:55:bc:62:\n    28:51\nExponent: 65537 (0x10001)\n",
                reason_code => undef,
                req_key => undef,
                revocation_time => undef,
                status => 'ISSUED',
                subject => 'CN=BETA Client Bob 1,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => 'E7:65:32:26:BD:AF:5F:1F:FB:61:FF:49:A4:84:7D:54:65:98:78:74',
            },
            db_alias => {
                alias => 'beta-bob-1',
                generation => undef,
                group_id => undef,
            },
            private_key => "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFDjBABgkqhkiG9w0BBQ0wMzAbBgkqhkiG9w0BBQwwDgQIg+R81lOCLEoCAggA\nMBQGCCqGSIb3DQMHBAjlV8kKK7npiASCBMiglDo1au4Ziu6VyC8nzFXvtdjeef0f\n2mvmjKTUlOE+iMCLrMa7UXjRxkmJZ+BB58S4Lyzx3MaMD5ZeMVb8HwAjlIMC3PQ2\ny7+sP0eIIX943huMRIQ6OduzoRgYNE+5Q6MYaI7x+dYzDlaTrqrhihNMHwQvH1jK\nEhXm1JXb1fyuEC5zv++4N4/17kzSfrWEOu1gao35KP3zweCpbOxrhs+DIW8Xa1po\nfcrjNT83VBAcUxtAJrrldie+Fw8zxGAfTP3ZBhPCNasiTXkqjmNNvjNReor8RRtp\njpjM5OLiN82ur19CViShmBhS3gdXDRmS0dLJc2a5++hSGNcm0Q8chfbhsPV0pT9F\nsfvrMw0Cr+tOcxfWM+8xdgInrtcgWRET4ay4hWi+tbYUTG74O3JiRlUd01C+ojwU\nzawJzT4iDlXyMfIWPXSkR0oN6gwy9ENDP7+6s5TrE31t9U0UghtwlnZMB8JQyurv\nvOjyYWnIzoPUEdTMtdnvxxDlGpRVAts4bp5pdqwFQN8ermkVwkMd7KT/cUC53tlv\nNg7VYKJR2/akbFe5wpFAmoRAO5ynYJ8mSWYSJi7aLkWCCH08zpDQgIVLKfBsbo6S\num/7/lFubW7PoN9zCq+mlZ9XO9k1XMwPYETlQNUc4FOexpdX1zUPKub+l3W3klY7\nWG213/KiQN+ZXpEi5n6yp3EL36C15zNk5U0ZSoTm5WP957raKjnxNJ+U+gmAE3DX\nPbcGAnkUme0y2uM1PvpobgbKM1f5B4uEKCtbzI5WMMTnsAojWzAJ0y0nFOSvXDwW\nvIH2c7GHrheW6Id/kVrAlw2YTY+tUexv5Yn+l/oqaR07RrKTIVJvCZdMYQTiIGAo\n/k9A38+lN52NWX6ZBaLR2CgK+v0l0mQ+vdSiH+rzcvjvMizBl/VG9pcTqZ1fYKXF\nF5SVr06Pv0wGaAZarqpeYje6IfG8J4ShW0WN1x18uJr4xcbTHGIVwNOAorm084O1\nSZSB4JsZojBcPYVQc0y/U2a+rGBPpawO5+R31xnbrAAgY7iPJ4CCMkqGcf1YF4Ck\nQDpBkcSn0q5g9rpdi55wnrj+VYypdZEepH2BhuOsz+r6NxSmIun2jBBQNSVrCfKn\n7CPQy+7Vb+OF5mHW5jtb6RWTYBi2X7UeT6DQNSAvRK81Gijw9HaO1YV+6j8yMxAa\nGSAjNTT/4m6KcUQWfh3BFi0KPcq3yZ8Dy886lPtDeG8VmYI7TO5+OatxIfYz36iU\nZirxpTSr91B/lmGWh4JSfKs5BEiGivx9vPXiaXePn3Sr9ZC0MXTf4DAekmymmzv7\nsQn6tsmIrUUDG+7BB4p5KalZQIwRDzcdW/G2sAtc4xynX0nZr0Hi8Uu0aLZHARqb\n0azk4qDBJ8xYhBJja4GHRM+Ef6SDrgJVOVS4p3038AUHB8doB310ZX3ZXFiTv5+e\nX5qkdIjrd2tM5lVLRTh60pq9u6dpyq8WB/3XNStgJk+cWh4dr14+Epc7bwErvnrp\nyF1HJCbWFinP5m6EnGldPf8cgTSPqBj4dNoyc9qs2AKd44ZNyT3hCH2wyonUNyxl\nf3zxHfR+iv0nC4oCl6LRtzTWljiXMnSXEjIP2nuaaZ6Or23ZsqvIjXf9h1/Hs0BV\niJ4=\n-----END ENCRYPTED PRIVATE KEY-----",
        ),

        'beta-datavault-1' => OpenXPKI::Test::CertHelper::Database::Cert->new(
            label => 'BETA DataVault 1',
            name => 'beta-datavault-1',
            db => {
                authority_key_identifier => 'BC:D8:05:7F:63:A7:7D:E3:4E:F5:5C:ED:77:DC:F3:C2:39:D4:34:A0',
                cert_key => '21',
                data => "-----BEGIN CERTIFICATE-----\nMIIDoDCCAoigAwIBAgIBFTANBgkqhkiG9w0BAQsFADBZMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGTAXBgNVBAMMEEJFVEEgRGF0YVZhdWx0IDEwIhgPMjAxNzAxMDEwMDAwMDBaGA8y\nMTA1MDEzMTIzNTk1OVowWTETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmSJomT\n8ixkARkWCE9wZW5YUEtJMQ0wCwYDVQQLDARBQ01FMRkwFwYDVQQDDBBCRVRBIERh\ndGFWYXVsdCAxMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA5pOLHaQQ\nyWTOOEqHvxPbJBbUt0Go8v9YQ3ZyCdd/8CwEZOrbWSa/FHf+/3DqBfX9RjyBrs2z\nNjCzbVC9aqGx8v3ReOatGJFs7MFjZskLkATRkQDU42e5UYBbHM4QupTjscZ5OhLB\nolvpVbRrctSW/prTnXpcJp6Wccz9uoC9F23FiQIgkWMySnPfL/c2l/5PXLd5XyfD\nflu5YrpUBnD4Lc9/J63a1m2xkWlqeCVHEYWGKWWTgcJYcW+5VirmifTlEeJX4uWi\nml+Ft3NnmkXmED7uVcnDCNu95kEcVTvrm4LDXyx9/m8gs4eE2v+T+x7k27vhxiVr\n9z7Kwvc8BWHGEwIDAQABo28wbTAJBgNVHRMEAjAAMB0GA1UdDgQWBBS82AV/Y6d9\n4071XO133PPCOdQ0oDAfBgNVHSMEGDAWgBS82AV/Y6d94071XO133PPCOdQ0oDAL\nBgNVHQ8EBAMCBSAwEwYDVR0lBAwwCgYIKwYBBQUHAwQwDQYJKoZIhvcNAQELBQAD\nggEBAAcOw9Hi28c9F+/2KTged4NGQdrJlOF5sHSEMchtSL8TVkoWrSzdQAGxb9fZ\ng5uMOh6vOB9gy+VQ7+kQaM1j1Yt6gqAmZSE4aXAyldWZq3guOtSRG0HXAVb7Ym8/\nvkeRbDuRaURKVBjrAU8uJ67oaEsuq+SEKQ2C/nuHIPb3OkAQNCwDk0jA33ngOW8m\nZZBGqBzxGXgJ4cq8EC7kK6jbR2ylB1Pj06LZIEKjFrhB4u3CHf6F/FSHUjhRtAki\ng0aBRUVBZQm/wmy2sfvyI8fHJLKeTDd97IfVelzwG4RtEv1i+UASBq7bIxlvvltP\n1oOfXUfnts3Qnt1uBBi7NLj2I1I=\n-----END CERTIFICATE-----",
                hold_instruction_code => undef,
                identifier => 'vjT_fiY-uh5XeCkudb_mocfSsxg',
                invalidity_time => undef,
                issuer_dn => 'CN=BETA DataVault 1,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'vjT_fiY-uh5XeCkudb_mocfSsxg',
                notafter => '4262889599', # 2105-01-31T23:59:59
                notbefore => '1483228800', # 2017-01-01T00:00:00
                pki_realm => 'beta',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:e6:93:8b:1d:a4:10:c9:64:ce:38:4a:87:bf:13:\n    db:24:16:d4:b7:41:a8:f2:ff:58:43:76:72:09:d7:\n    7f:f0:2c:04:64:ea:db:59:26:bf:14:77:fe:ff:70:\n    ea:05:f5:fd:46:3c:81:ae:cd:b3:36:30:b3:6d:50:\n    bd:6a:a1:b1:f2:fd:d1:78:e6:ad:18:91:6c:ec:c1:\n    63:66:c9:0b:90:04:d1:91:00:d4:e3:67:b9:51:80:\n    5b:1c:ce:10:ba:94:e3:b1:c6:79:3a:12:c1:a2:5b:\n    e9:55:b4:6b:72:d4:96:fe:9a:d3:9d:7a:5c:26:9e:\n    96:71:cc:fd:ba:80:bd:17:6d:c5:89:02:20:91:63:\n    32:4a:73:df:2f:f7:36:97:fe:4f:5c:b7:79:5f:27:\n    c3:7e:5b:b9:62:ba:54:06:70:f8:2d:cf:7f:27:ad:\n    da:d6:6d:b1:91:69:6a:78:25:47:11:85:86:29:65:\n    93:81:c2:58:71:6f:b9:56:2a:e6:89:f4:e5:11:e2:\n    57:e2:e5:a2:9a:5f:85:b7:73:67:9a:45:e6:10:3e:\n    ee:55:c9:c3:08:db:bd:e6:41:1c:55:3b:eb:9b:82:\n    c3:5f:2c:7d:fe:6f:20:b3:87:84:da:ff:93:fb:1e:\n    e4:db:bb:e1:c6:25:6b:f7:3e:ca:c2:f7:3c:05:61:\n    c6:13\nExponent: 65537 (0x10001)\n",
                reason_code => undef,
                req_key => undef,
                revocation_time => undef,
                status => 'ISSUED',
                subject => 'CN=BETA DataVault 1,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => 'BC:D8:05:7F:63:A7:7D:E3:4E:F5:5C:ED:77:DC:F3:C2:39:D4:34:A0',
            },
            db_alias => {
                alias => 'beta-datavault-1',
                generation => '1',
                group_id => 'beta-datavault',
            },
            private_key => "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFDjBABgkqhkiG9w0BBQ0wMzAbBgkqhkiG9w0BBQwwDgQIu6T/WtGP2WcCAggA\nMBQGCCqGSIb3DQMHBAi1+7wmSfc9XASCBMggmMqv7FL3EBvw98evz1UdAddzWrBE\ndNnVWwdObe433vWRbYbC03WNt2YHIoS/V1wTdX/V/mvDHw8bz6IIt3mRQo9gL5Kb\nQdYmaDiNXgtB5mwQD0YpV2Uirip8sSb4xVMDir2utTO/kp5k2kKorpPNe0hkcmBo\nAO8EKAeBHgvhw1ulihWw/LjhjoSRu8YMGQZkkfEhaa+nElgtGCyLn/5ZPLzAZVhf\n5OdEr5VOu+Ag3zavp839Hj0Tp/IB4LJQHB2CGeO+ZG3zZwHWK5bzbiLrp5VRHuZh\nw22cdBqAmaHYT5MclIYCbnw/3dL6NBLT9asEvEEH+QoeiCigdd7Ope2m+Fb4MyS3\nMtu/fRTOiBWEHo6es8OOexu/n47PIaRl14oxPhZxNDHOmVFWqsgPYepkEYxgp4JL\nzgUKJH3BXiSdG5PQ368ropNjgHQ7w3MxY3YalsAYgviE2pX1dN7w32VC2KvanKpB\n/i2lQhf0fs2qYPpH2vRzIkrdQO3dmzKfNJF3EFtGbSwkTPDEgBhRn4zN5ef35rTG\nsa4FzmrVa54Iv6mLDGeQPM2xAHBTdEx2tHG5dIasKjanEbJ3k3+Ocmn3m75O5wp8\nl0V7W3VeDZSAAaC4TV2O5lT38Fan6oH7ucQmTRN7juxp/meZcz7FtwMhb4ae6hEr\nlKVBZ6LPuxcfEMRxXSTW/39gKdUCxVskHGF2fi7oHpMJEnk+I18RJIuPU08F4Mg2\nRCOjTwdovSTBc9+gdGaFnMSEjhElpNgp6uPvPfARgpqH8tB3nWu2naoOOpkZ4Xey\nUS6Yu9PbXfItu96lsPGIaB48PHUrzv/supZAqWyaG/1FXlLs+qoNCAYZqZLZJh22\nXLFllYcBSwhfh2x85+UcMDu6k0DxFh6IhCkTutJRt/9yn1pWSD4dvIpowJIf/kAr\nbbla5ZSkTa9koYuhsnshJNLRFBbGJBGt/i+xifQuFLP3LAEdScwM1j/f6NXMcA6K\ngOuLrOp/xlem5sIZcJUxzOEQUwaSZZBbwSxfZYJYixnuh5JR4gIUBBPWZBYO4lUV\nGSLsJl+xqAqcOBzFoPLVLSO1MzCu6Gr/B8CkN1SXaX37sUADCqdJvmcH8wMMJoWj\nN+l5OGmJ4SmQ1zLheFsd38Dkhm7mrhIozjo791VZ6+IN3JTXwaRaX8DBUwEGLIwK\n/H5ePNb61ejQ6FH+qM4Izvrp0TkufBdKi85AeQCWVOIKl1Z0QzFElqxSnmfK2SwZ\n6zmjC/eMtkRL+giWzI8GHQPYgq8e0lL3n/cN1k9d/zUyZ/TEHgOwJFC5+B0rh59j\n+bHAujlg75z2JhaYaGNo1cMeRh30zoud5mnnq+5y/omnQt99AV4/989MgPAZvr04\noaYyxX6LJNa+MnQZkIyL2vFwGlikJf3IsrxWgdBUrYjDPhF2gxjhx+D4VGAxOeTV\nctIPpnnzwCeY6ZLZ4UXIKZFTM7ohl5HJrPKzpkpbqeS3bmMoT4tK32M+irrfKQ3/\niiyE9q7Swf2s8Yu6RXVr+EmMRHIDlPHoIuU8HDtE4ivX4pEsZRS0CH/7SYxbUApy\nE7jA44xqASKoP9dAmWgqlNq/z6S569rtFW6oz/g21Bp9/D48nhwUqYWbcXVShw1u\nopg=\n-----END ENCRYPTED PRIVATE KEY-----",
        ),

        'beta-scep-1' => OpenXPKI::Test::CertHelper::Database::Cert->new(
            label => 'BETA SCEP 1',
            name => 'beta-scep-1',
            db => {
                authority_key_identifier => '5F:AA:16:6B:01:FC:E0:C1:D1:A7:42:FE:35:20:40:E2:2F:0B:45:07',
                cert_key => '24',
                data => "-----BEGIN CERTIFICATE-----\nMIIDdzCCAl+gAwIBAgIBGDANBgkqhkiG9w0BAQsFADBXMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nFzAVBgNVBAMMDkJFVEEgUm9vdCBDQSAxMCIYDzIwMTcwMTAxMDAwMDAwWhgPMjEw\nNTAxMzEyMzU5NTlaMFQxEzARBgoJkiaJk/IsZAEZFgNPUkcxGDAWBgoJkiaJk/Is\nZAEZFghPcGVuWFBLSTENMAsGA1UECwwEQUNNRTEUMBIGA1UEAwwLQkVUQSBTQ0VQ\nIDEwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCe6kIBo1Dfbigh2EYQ\n0SOeFl8dPe+f/Mwu6tYUMTDUicUQpO9Ua85fk7DqKGyv2A1P+Spb8sYpfa1vgz8d\nA3Veyp11zJ1I2ir+JtWWL/M0USBoMpAZcOJmMUYpKVKkuEw8SiIW6ZV4wUoztsBH\nlmufnQ5AmjGN+aG+bX/U+b8PZ5/aIaAGWVVZ4QFFnbO6upABu9PQQqVgh646m74k\nNXysDMKJQnQ5U0TRUKyYMQZ3DFHW6pc+bgnq48ePhi4WZaTRHaHLd40MpfEFd6VW\nhLeUwI6PsWT6mfbkGYyWsTYwuZCcaFmUXxrK50YroyOU8XLg11UdggY/N9Xu4EED\ns04LAgMBAAGjTTBLMAkGA1UdEwQCMAAwHQYDVR0OBBYEFC9eZdvvjDMgei/qT0DI\nracO7V0LMB8GA1UdIwQYMBaAFF+qFmsB/ODB0adC/jUgQOIvC0UHMA0GCSqGSIb3\nDQEBCwUAA4IBAQAlTf41mkSc4N65E57E3aYtoD4NNvbjoX+3yLycJWPf18K5M2Dk\nlRsR5Bwg7Fp9MWUCo6bNI95Q1UCmm6TIVWAowCMzY7MMoaEHaF5+mZGLgN4IuOPV\n7YJF1C5Yyjd2ygLbTI6jiXSGBQplmyuR8gSnAeZ2oDXXvYekFTs4IAy4vkJe6JWk\nSM1zSbGxY7zGwGlmw/UsfWEFenzsd+QIMlHfzM0agIw+udgacEZaRiDAmD7wt+gR\nmlVFzU001NxbAPc9P+KoP1ABj+mx6+mQ9aZhQJVcXKbArX/6XIOx2m0JjXY53ikD\nBI8ElGZ3yI4tOySnIPCQTdLLdnhQ+ZufNgLq\n-----END CERTIFICATE-----",
                hold_instruction_code => undef,
                identifier => 'OeZkHdf35j2sRVaDpZKlGDZx804',
                invalidity_time => undef,
                issuer_dn => 'CN=BETA Root CA 1,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'xCvDfhOr-JiMb53tNR8BIQPR4q0',
                notafter => '4262889599', # 2105-01-31T23:59:59
                notbefore => '1483228800', # 2017-01-01T00:00:00
                pki_realm => 'beta',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:9e:ea:42:01:a3:50:df:6e:28:21:d8:46:10:d1:\n    23:9e:16:5f:1d:3d:ef:9f:fc:cc:2e:ea:d6:14:31:\n    30:d4:89:c5:10:a4:ef:54:6b:ce:5f:93:b0:ea:28:\n    6c:af:d8:0d:4f:f9:2a:5b:f2:c6:29:7d:ad:6f:83:\n    3f:1d:03:75:5e:ca:9d:75:cc:9d:48:da:2a:fe:26:\n    d5:96:2f:f3:34:51:20:68:32:90:19:70:e2:66:31:\n    46:29:29:52:a4:b8:4c:3c:4a:22:16:e9:95:78:c1:\n    4a:33:b6:c0:47:96:6b:9f:9d:0e:40:9a:31:8d:f9:\n    a1:be:6d:7f:d4:f9:bf:0f:67:9f:da:21:a0:06:59:\n    55:59:e1:01:45:9d:b3:ba:ba:90:01:bb:d3:d0:42:\n    a5:60:87:ae:3a:9b:be:24:35:7c:ac:0c:c2:89:42:\n    74:39:53:44:d1:50:ac:98:31:06:77:0c:51:d6:ea:\n    97:3e:6e:09:ea:e3:c7:8f:86:2e:16:65:a4:d1:1d:\n    a1:cb:77:8d:0c:a5:f1:05:77:a5:56:84:b7:94:c0:\n    8e:8f:b1:64:fa:99:f6:e4:19:8c:96:b1:36:30:b9:\n    90:9c:68:59:94:5f:1a:ca:e7:46:2b:a3:23:94:f1:\n    72:e0:d7:55:1d:82:06:3f:37:d5:ee:e0:41:03:b3:\n    4e:0b\nExponent: 65537 (0x10001)\n",
                reason_code => undef,
                req_key => undef,
                revocation_time => undef,
                status => 'ISSUED',
                subject => 'CN=BETA SCEP 1,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '2F:5E:65:DB:EF:8C:33:20:7A:2F:EA:4F:40:C8:AD:A7:0E:ED:5D:0B',
            },
            db_alias => {
                alias => 'beta-scep-1',
                generation => '1',
                group_id => 'beta-scep',
            },
            private_key => "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFDjBABgkqhkiG9w0BBQ0wMzAbBgkqhkiG9w0BBQwwDgQIKnMTOt0IMLQCAggA\nMBQGCCqGSIb3DQMHBAjJ4ixcE2vtJQSCBMh27T2xXaqYkA2VrrarVUCcGytz1A6C\njcZpg5HPHvVx+S3I9QP7gC/N2B6dC/mvMgVxQurljxM+5BztOwjm6MlttbcjU4He\n6c3O2Qo2OO66MPWAUNJJi0j5Webi3gWRldUg4h9YZQTqQQWnlbCBwZGBwXVChdaG\n3BlTqI/74I1y4stpPBM7z5BoB0HH+DV1MSwFf6RrYeAZwueyj0L3M9FLPfkQvVcT\nAnVenqZYckvEgMit9K8WJGm6/04RlyH8PL5rHkDOF71GkoQwxyUI6dwViaOkDppd\nZI28bgrG1L5DzLDQbvoFmM2eLIXs5HzXhRy0+KWt4RzApkJA0I14mOAGkgwB1V9c\nX3A14svCo3w2dNR5SwwkjwH+n4Gm+0u3sWJgqiR0/Ci+ZiM4YGd3oPTVrYnkD/zQ\nd2hxdGwWLwdB/9mS/9TB2m5MJisZA2gp2P9TlAXZiprnm2Qq9mLsQj9wskNNoPRp\nIRha66SOvz39/Ed6qtrOe8CuQHJiyiBNQSBTqVb+T775sc8BvVyssMclCFkqxIEk\nBREl8QTAVfVaMoKTYYScTx1O6qxb3EPXahJS3iS07oYRrbDP30BbSvOhwxQv/w9D\n19LLUcn64ujM4OgtbuUJUZEfwMKBZHNxJS+sd+RVG8RiQTRn11eOKNaiFlXtWDHH\nxzfv7rN6f6o/y97D0ah8YGHt/YHxji+/9XGRIcLHhg8nCBinuSDcRh0lrYP1if5J\n2npLmDG4RcxmcKutihZBcpWNwmqumEDiI3TeQhtOe5merxj/RbHJhpgrqZJM2abL\n2ZRmHgwGL7yzxjnfOp8s2bmajA9QY/wSNKmOUIEdjq8k35J3e+bhvZlguPrXmCxE\nQL+jmKchYpgUTU3YOobEWIZ8cIGVUYTBHgGk9QyY8z7fgZXVKhBtOMhjrckuo2BV\nI4JGr7bwPZw4LXkzmglmVkT/40sXIdRRzYJc00yP74YBo4DMspaXs7XP7eUJzb6n\na7+3hp+FWYkmG/xfwWhTsv2ofXrUBpoCPVtmXpRVjDX6CN2Z9EgrdPTnztSqMi7H\nytSrbqr7V0SwtqAwhulcWJAIR2uEP3wmc5C7HZeW1GAgI94hW4nOnHAKK19KX8Ay\n/DLhqplMdwWz+zlSYBMJZEYu9r6+KwLfIMVoHVxbNi2af4gh63ynnIk3+7o055FT\n+nnJmMjQZFA/LFdiW2mCiGX6zZ1S3JBBZm1lL/7VTOG50V9icKPwpPw1VwW9UEf1\nEGn2pM6oM9Yje4FtPPe4f8hpv0tcQgGjFSqHBmGRPHMejqY8fdCCcC0okA9PRE0e\nx2XEo86umlzFwZ01D3OnnUGlitp5oIMeAhFBA8550xajh3BsLoIBsNXr8mqvBTBV\ntx2hyIg84TIqINTaFPm0BWMdODNRsG9QqjL9++/4SmwCeWah7MM7xoMJ8KAmj0QE\nRqT9XWl4KAkO98PildwCuWkuKl2MHiMXBcXSgWj/n8Gq5FGtwees7C4uoDlxvTvn\nhubwP3GiYGDbPhfuyggPc7dajOgu7OnzCaGzzU+cAPIyFvzynUn+MqU5wZdJ/DiF\npbZRZ+95JaEi/9tyoy6f+duP565sgTchJzfz5at4SjCVSrjXzo8yatYBSTu9nsjN\ns8E=\n-----END ENCRYPTED PRIVATE KEY-----",
        ),

        'beta-signer-1' => OpenXPKI::Test::CertHelper::Database::Cert->new(
            label => 'BETA Signing CA 1',
            name => 'beta-signer-1',
            db => {
                authority_key_identifier => '5F:AA:16:6B:01:FC:E0:C1:D1:A7:42:FE:35:20:40:E2:2F:0B:45:07',
                cert_key => '23',
                data => "-----BEGIN CERTIFICATE-----\nMIIDkDCCAnigAwIBAgIBFzANBgkqhkiG9w0BAQsFADBXMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nFzAVBgNVBAMMDkJFVEEgUm9vdCBDQSAxMCIYDzIwMTcwMTAxMDAwMDAwWhgPMjEw\nNTAxMzEyMzU5NTlaMFoxEzARBgoJkiaJk/IsZAEZFgNPUkcxGDAWBgoJkiaJk/Is\nZAEZFghPcGVuWFBLSTENMAsGA1UECwwEQUNNRTEaMBgGA1UEAwwRQkVUQSBTaWdu\naW5nIENBIDEwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDrEMOxo12G\nTXGlX7Q0uW8jnHNWjKoLnoY31/Vg73g6E33xpM3HkFX5uWoUiDl8b/YDvvRQoOeT\nkQ0fZ0gYfsDCzyxrVIFXflF6GyCPD81i6MSau80IvIK2zvD559RFRqlkBFHikwz1\na0ZzFG03QJR1+x4cDT1huiVMAN3ZKgOryQDoTGxEZd5ILoB+rgmdockm2mX+B0ki\navoLbVUrjAYhg/2v9qOXLebhcrOZh/t/2Mu4OoptKqwQSpeeZeaT6d018zhvSMjk\nE6RWyFuF84iTUWvoz4Vqd7P47R8qktCtFbkqPTCe7YIjDu1zNg1jcyLgUYOeo37q\nM6Zlumta+xQZAgMBAAGjYDBeMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFBMK\nzHfejuebN9DlTYwmcvfVXG1NMB8GA1UdIwQYMBaAFF+qFmsB/ODB0adC/jUgQOIv\nC0UHMAsGA1UdDwQEAwIBBjANBgkqhkiG9w0BAQsFAAOCAQEAD+thHJfm2G5aAyFB\nO1k/z3BFd2wx/ivNtmuTOkQDtM7Ji7H9WBiaj08zgdxSqnYW19iZ+esbKcs5zSnc\nRuMli36GJDaLPLoUT1SazmecT6L6duHKqnJep05Qh9A5vz+RwuMgcCuCNmYxH0mD\nXBLYbqrdcKG33rTqyTz/WXQ0wkoPFzenLH1WyoFPO6kReni4WJ+9Pt3F7NxEu2DN\nE7+JBZ/i1+AIaSvaZEdGi1WPinjPjeVJ1YdfIy3pac86bYlAc5sn245PjD6quzqf\nGXM+mNaEMYhe2To6H79Ls5cdhN4Lyjo6zMFobyjo8mL2vjtg5H3PeBWe8Zoyk5Gp\ndetcwA==\n-----END CERTIFICATE-----",
                hold_instruction_code => undef,
                identifier => '3z1luFO6vA0chsdpSm5CiDv12xA',
                invalidity_time => undef,
                issuer_dn => 'CN=BETA Root CA 1,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'xCvDfhOr-JiMb53tNR8BIQPR4q0',
                notafter => '4262889599', # 2105-01-31T23:59:59
                notbefore => '1483228800', # 2017-01-01T00:00:00
                pki_realm => 'beta',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:eb:10:c3:b1:a3:5d:86:4d:71:a5:5f:b4:34:b9:\n    6f:23:9c:73:56:8c:aa:0b:9e:86:37:d7:f5:60:ef:\n    78:3a:13:7d:f1:a4:cd:c7:90:55:f9:b9:6a:14:88:\n    39:7c:6f:f6:03:be:f4:50:a0:e7:93:91:0d:1f:67:\n    48:18:7e:c0:c2:cf:2c:6b:54:81:57:7e:51:7a:1b:\n    20:8f:0f:cd:62:e8:c4:9a:bb:cd:08:bc:82:b6:ce:\n    f0:f9:e7:d4:45:46:a9:64:04:51:e2:93:0c:f5:6b:\n    46:73:14:6d:37:40:94:75:fb:1e:1c:0d:3d:61:ba:\n    25:4c:00:dd:d9:2a:03:ab:c9:00:e8:4c:6c:44:65:\n    de:48:2e:80:7e:ae:09:9d:a1:c9:26:da:65:fe:07:\n    49:22:6a:fa:0b:6d:55:2b:8c:06:21:83:fd:af:f6:\n    a3:97:2d:e6:e1:72:b3:99:87:fb:7f:d8:cb:b8:3a:\n    8a:6d:2a:ac:10:4a:97:9e:65:e6:93:e9:dd:35:f3:\n    38:6f:48:c8:e4:13:a4:56:c8:5b:85:f3:88:93:51:\n    6b:e8:cf:85:6a:77:b3:f8:ed:1f:2a:92:d0:ad:15:\n    b9:2a:3d:30:9e:ed:82:23:0e:ed:73:36:0d:63:73:\n    22:e0:51:83:9e:a3:7e:ea:33:a6:65:ba:6b:5a:fb:\n    14:19\nExponent: 65537 (0x10001)\n",
                reason_code => undef,
                req_key => undef,
                revocation_time => undef,
                status => 'ISSUED',
                subject => 'CN=BETA Signing CA 1,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '13:0A:CC:77:DE:8E:E7:9B:37:D0:E5:4D:8C:26:72:F7:D5:5C:6D:4D',
            },
            db_alias => {
                alias => 'beta-signer-1',
                generation => '1',
                group_id => 'beta-signer',
            },
            private_key => "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFDjBABgkqhkiG9w0BBQ0wMzAbBgkqhkiG9w0BBQwwDgQImRPNEYrnDicCAggA\nMBQGCCqGSIb3DQMHBAjuUk8r3cto8QSCBMjCsdgjuULlQXmoPorx5FQnwqeKK15N\nXSJMru/XJ59ER3b9IUG4VFsSrx7Z8w/gMbxCr/wzN6fAS69LWDBd2bc4qJl/LOJe\nt+J6HmF6k18vNmOEw1yKRBmQFYFjaihmPYOvxSecM8L46PsZiM6/1e3wXt5hVCdu\nzM/3gcA1ZbiINGU38sT9vXtr9beZoCvBKKL45PxWJBqidkzU6FcRIC+pHewy62yD\nNYifD1MvQAe3k6gA4jlM4gjdMHCrR7tXEl2xG3/R1CGcutBiDKFTKsC/hR5Iy3ms\nonz8bJ6MP/pztV2xledUy4pB5w+ZRdPSmBo3TPVGX2w0NufYOBnTxUa6/Qb4HZ1O\nsjc8oUW6bM/XmEu4lE5eB/x5MPjAH1/jYbVl3CQ22/MrhRzn+VDVFYB2dpzoMVn6\n3Ej106V8Mnaz8qnli5n/bBClBrgDx5laq86L+Brvc6GUFZJahnQJ7z/0JgTDcyFw\n+eYBMt777QcYI+2zwkK+wtFxDPJ45+e0SUetf9DDCVpOPxh0CPS7WPGVr3QnQxVd\nFJEGEm2LJd+vXUFsKec7QMZCcntsUXvhB6+rL+d2ZsJ4EfPyo2eHD8SSf/ZnpzAA\nBjnX1O3K/M3cZ8QTHKWcBF7EHO6FSwiyK930rvgP6LSbrhSgQcgeNbbWO8aWbUW0\nSppE4BYnrSif5mhoeTggPHRs+aD+JrOr49jIu1z7tbsM3YSt8s8HG8viPcXUrKC3\nzmdiVQgPcizP8jq7Dp4D8t7Lb9Sw1uIheF1pydFmtuOyAqREjYtYDUyOU7/qoWU4\n0xjruYrgt2v/6G7DEB8c1XWc8BCaSmmhOph5jgb/BE7CyVgLVOeQergwMr5/FHPJ\nKlY4Bzrpp94Bifu2pwjNh+4WB6g0WGdhhKlXBPfR7x+iS23uGsFp9FpyW+PjgGlz\ntcu7pCl8mWNny4di9fkmQVanXad9ce3J2Su4ds/ApOY+u7YoylCNMSCE3eabiTOh\nTTpx651APkYiAaZFroVlsEjsC8bX8AIaof+dro+fhs1jq5uxWJkRR04HcWsJ1XtB\naMgwbWHomUpTrzT2//lk8e38r+USfU7pC+QA90Bq64fhP93VeuxMXKSP6dgW3yh4\n1EYfKOFKL8TXogotfM4chgOxAGeKy8vf+ioSY2GCsTwoaLqlphu7iaBpZQ7pjhU1\n2j0gRkjtcttIovdC9KPSiO4hETAr8K2HOoh/QBE2bqxOT21VFAsfd4BzvGDxvWAS\naeahm0K9CrpsXGxqRPyTFEae3JkEESn8JgUqRpwKP/TBCFmCErI0jT5woo1qW3d2\nIKKjnpVmTjSbBsCDc8wwugb3M9t+ldfrrwkpb0OzKSNQNX7mJ6l5gBozVKw0UGzI\nlvEES1KdZWLAZg/rxC+EleymkuHBodc0fA7/CAezqinV2jdnx0tLgGT6l5vnycFC\nerEiwp0SUN+uIGSGFFWTfpStZgIU9ninff2k3eO+yuSYT2+KWODaXf6pt6xP2xbu\nQhv7nID+xlWwGkRv8Jsd4RXo12K8rV86YhJM41gzFzLAQBK0VaLpTDZW8zXtfqPR\nxG9zXfaA5nJdpWrGvp83dZ8+NXWnl5Ubzu94jSckxKCj0bwe2Til6Rb3HykLMLNo\nZ7g=\n-----END ENCRYPTED PRIVATE KEY-----",
        ),

        'beta-root-1' => OpenXPKI::Test::CertHelper::Database::Cert->new(
            label => 'BETA Root CA 1',
            name => 'beta-root-1',
            db => {
                authority_key_identifier => '5F:AA:16:6B:01:FC:E0:C1:D1:A7:42:FE:35:20:40:E2:2F:0B:45:07',
                cert_key => '22',
                data => "-----BEGIN CERTIFICATE-----\nMIIDjTCCAnWgAwIBAgIBFjANBgkqhkiG9w0BAQsFADBXMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nFzAVBgNVBAMMDkJFVEEgUm9vdCBDQSAxMCIYDzIwMTcwMTAxMDAwMDAwWhgPMjEw\nNTAxMzEyMzU5NTlaMFcxEzARBgoJkiaJk/IsZAEZFgNPUkcxGDAWBgoJkiaJk/Is\nZAEZFghPcGVuWFBLSTENMAsGA1UECwwEQUNNRTEXMBUGA1UEAwwOQkVUQSBSb290\nIENBIDEwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCyu3tZ/w5YkOWf\n6AQVD/S/wHVWup0rrpAXUMCGKOgRV6nQnk1vIPs3HoKTMSP3AMLGYm6YGVw4cESA\najZkq60xtPhIEBULvP9an2+oEI09KTqxTZrJUSyuySFjOf/bDfkWqddi2vmSbtCY\ne1H5py+2mDV6gS2B85nwILSgDWhc0gvmGy9e0dvx/cKDWMafQSGXusWTVShZ/JRT\ns06qMguOAgEhDvM0FrPje6yw2H5VVuOgzai6GYeUmxFkw4FIxT2Qd9NKq+SMyM+h\n/JqokvVaf9iab4mRPaFWJbkDoFBLfYU4Xtz6HOnRQtFhlhU4HE6nY7uAXFkjw9Xs\n+HHRnH29AgMBAAGjYDBeMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFF+qFmsB\n/ODB0adC/jUgQOIvC0UHMB8GA1UdIwQYMBaAFF+qFmsB/ODB0adC/jUgQOIvC0UH\nMAsGA1UdDwQEAwIBBjANBgkqhkiG9w0BAQsFAAOCAQEAICrJ4jbkxi8276hroJot\nBqUqZqez3Ay4/bz6ZECCxFqNbRM88CEqNbaJLCiWsMdINY56VM/wNP67Bh+dLgNl\nK9fYj/K/tSZULvN+rvQwDUqHY1bF6Wzazr/eCnKcxZPf7QDKzprWIRIrQNc/wjFS\nwhdEABiZu7f5dmDKfStrHcI9KbDjKN2db+zK2tDidwKO8MxiS+t3pR6JMSk/pZdL\nTlLONdpS7dLBjtxKCM+Pt7FK8PMPQgLU53gL1VUdXwWzQo2gQtsteDqEti87XXNA\nue+uu8NfgxS6Cuzid4ZWxyovS9vcqsAcgzANy1mjXni2G10V6jgYgk7CVwrw1PP2\nPA==\n-----END CERTIFICATE-----",
                hold_instruction_code => undef,
                identifier => 'xCvDfhOr-JiMb53tNR8BIQPR4q0',
                invalidity_time => undef,
                issuer_dn => 'CN=BETA Root CA 1,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'xCvDfhOr-JiMb53tNR8BIQPR4q0',
                notafter => '4262889599', # 2105-01-31T23:59:59
                notbefore => '1483228800', # 2017-01-01T00:00:00
                pki_realm => 'beta',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:b2:bb:7b:59:ff:0e:58:90:e5:9f:e8:04:15:0f:\n    f4:bf:c0:75:56:ba:9d:2b:ae:90:17:50:c0:86:28:\n    e8:11:57:a9:d0:9e:4d:6f:20:fb:37:1e:82:93:31:\n    23:f7:00:c2:c6:62:6e:98:19:5c:38:70:44:80:6a:\n    36:64:ab:ad:31:b4:f8:48:10:15:0b:bc:ff:5a:9f:\n    6f:a8:10:8d:3d:29:3a:b1:4d:9a:c9:51:2c:ae:c9:\n    21:63:39:ff:db:0d:f9:16:a9:d7:62:da:f9:92:6e:\n    d0:98:7b:51:f9:a7:2f:b6:98:35:7a:81:2d:81:f3:\n    99:f0:20:b4:a0:0d:68:5c:d2:0b:e6:1b:2f:5e:d1:\n    db:f1:fd:c2:83:58:c6:9f:41:21:97:ba:c5:93:55:\n    28:59:fc:94:53:b3:4e:aa:32:0b:8e:02:01:21:0e:\n    f3:34:16:b3:e3:7b:ac:b0:d8:7e:55:56:e3:a0:cd:\n    a8:ba:19:87:94:9b:11:64:c3:81:48:c5:3d:90:77:\n    d3:4a:ab:e4:8c:c8:cf:a1:fc:9a:a8:92:f5:5a:7f:\n    d8:9a:6f:89:91:3d:a1:56:25:b9:03:a0:50:4b:7d:\n    85:38:5e:dc:fa:1c:e9:d1:42:d1:61:96:15:38:1c:\n    4e:a7:63:bb:80:5c:59:23:c3:d5:ec:f8:71:d1:9c:\n    7d:bd\nExponent: 65537 (0x10001)\n",
                reason_code => undef,
                req_key => undef,
                revocation_time => undef,
                status => 'ISSUED',
                subject => 'CN=BETA Root CA 1,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '5F:AA:16:6B:01:FC:E0:C1:D1:A7:42:FE:35:20:40:E2:2F:0B:45:07',
            },
            db_alias => {
                alias => 'root-1',
                generation => '1',
                group_id => 'root',
            },
            private_key => "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFDjBABgkqhkiG9w0BBQ0wMzAbBgkqhkiG9w0BBQwwDgQIA226wb5KVqoCAggA\nMBQGCCqGSIb3DQMHBAiK1ELLlZKCTASCBMgY1eiZGNKJIX0628Mn0UvbpfjPDOIE\nepJ1/MSu2dL/ylALdOibEP+kVFhYWwOhgnukYPtu7O3on4BAyCH/mSgvMZBjaYLA\n6k8e7xzJd678YsGMuMOZGsUOfQFwFHD/UVF8cWu6WpAZ+zyY7M4VU+sBji1tkBHR\n0ErfViUuha/Qx3VntQmmFD8vZVTJcFAQp7NVrDpsAd9mowI1n1+wPHlimu+3/dIy\nrr1hEhnEqkvw+jUdTCsCKB2Y23l003P8CAX3pmGPN6+G+U3kWQBCtsHxrP9J+ipY\ncRvg8Jkmu9CLlydW/BrGQ9rFLFD8PR8A6i+nVpQSg/NrDoO19GgeVdwbDuq4L+KL\nBRTPybne5FF2vT3IceDQ0NL6++LmOLarBGx85rnUslouZHO6B5DpTURmKEJkUJZO\nJmNRteERAoRgUAzy/6z8em9FjF6tKH/LERU9SnVFnC+WMTqACmT3c2Cfbv8ZfzMS\n8zelaQMre94d7rUkzjrOQb+b3ZSQPM1Db8mjAr/8GShdgCKgfhpVx0ohb12Q6qTi\ncFzj8qeZhVAX0lT4XPjny3rULZ5qRTFIFO+z0NjbelC6eAyUre6vp2eaA+jldbsI\n3FdBbWdFQupIV/EywXu8LZTPkwRaDeo5eGmvumKBp2mwVWx4zG6NFpKgUAPiHVvx\n3ArkWKAJ8jQi0R2yGcVetSuwQG01gRWB5/sYttIkKmJzN05tqqF1qBwL8smLsaIS\nxpVLyzcySUBR+rdIxgfNIcTIz3U/7jI09BUNnx/A/7WinsCHiQeDx0HqEqHfaeiD\nz+aPHlenEjucojQ503pvlWeT85oROfJIXUTBW1dH0JZBDwi0TTh9eP9hEgWIFdkB\n1fPAwPpNXrfZPaz2tKTTnlUq1buXuYVyIBOso4ogMdW9dDzW2TU2FseA5dBt1mB9\nmG5nCe0h0P9CgGSD90gfoATqtmlXD63UozAMiMTkNQImFoFjzkWCVNPCXkq0YEyK\n7ndanCNP5oRY2Y7zLgPjn4M5P5iMrUEdJmR9gFAjARZo29wO+xIzPf2KzhC8v0zR\nB8BxkILW400JuF3/TgG1a7CzAHyihUuAeeNlyQu+LwMvPiS3rQ6LwQ2RopQJFvyI\nb0MdgGYyXnjS3WAGksKYIho1taBLO4+C4GiRjfOaiMb1BZDYBXUVTSg2wV/Jm4Hg\n+U0LZuyzYa3j9F92cRmoRLIZKAMFO3ESZD8IINYqQUa6eBKLvRNinU2OrpgmLlue\nHmiBvp6Hhd3gSzsMKKM3L3ztNg67zdbxV3aDNXrt6iuW46VwIWpKHVg2XTjWWGct\n1XtruSOL9sHjI6efEGQIieX0i/UgYfZUOqNdZziLmaUa9aJqB7fy+bIv/kaPsvrz\nSK7SnhGlTPecKe7x0SOjscyFDKn2eUwSuLqynQhfr1P96wh5CC2atnyaIfRE8BYI\nD9qoJd4CXqOKyAVuWvI9qmlEFsCBVdKFLJEo/RNSXCpFw8GlUvbto8XDYjglOcza\nT0xi+FQ0bhXzJyUIm+TqdL0ozgEPOvhf5lOBnKlnoP3hPOhPq2r7mHHwY9BZbiG2\nMhgHf1ZccGY+Xmnkm0uvbtWA2nwodVAUGJ9qgr/kBkJWV/F6eKf74uwGpEkR5NBk\noI8=\n-----END ENCRYPTED PRIVATE KEY-----",
        ),

        'gamma-bob-1' => OpenXPKI::Test::CertHelper::Database::Cert->new(
            label => 'GAMMA Client Bob 1',
            name => 'gamma-bob-1',
            db => {
                authority_key_identifier => '24:D4:62:7B:4A:75:C5:B5:34:7F:95:C2:8C:F3:1F:F5:E2:65:CD:9E',
                cert_key => '32',
                data => "-----BEGIN CERTIFICATE-----\nMIIDgjCCAmqgAwIBAgIBIDANBgkqhkiG9w0BAQsFADBbMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGzAZBgNVBAMMEkdBTU1BIFNpZ25pbmcgQ0EgMTAiGA8yMDE3MDEwMTAwMDAwMFoY\nDzIxMDUwMTMxMjM1OTU5WjBbMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZIm\niZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxGzAZBgNVBAMMEkdBTU1B\nIENsaWVudCBCb2IgMTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAO1J\nvseWGl8O2eDWmHJenzBtDEwLyCP7QzarfqkwjO7lWwLqd2Lmsy+CZ5xbpgNKV11o\nEqT91ILVeAVcl/2b12wsnmEBb0fY/d5pA5aDWy7Wdf60ZqQYJCNBPyDzVIiqKwI7\nhsUJSZ1JwSzOO0pJzslmjT2rPigmlbjSlmOal5ie+LXA0gkV9sIxzcDYMNpQNX1t\n5cf7wRRP83DWHg3xE+M/sbtJ1Ci6/dlcsUUJ0k/UDGHz98u0OpCEN7TespGJ1CIg\nyJHV3IdQXp02Cazak5AFgMUxdDk4G3uGF7suvEB/DAS5JUqsE4jATcwAvy/tkNyH\n3YlePNfh6gtnvlDm6SsCAwEAAaNNMEswCQYDVR0TBAIwADAdBgNVHQ4EFgQU/QOV\nG78N7QZiYA3Q1bFbuvmc7K0wHwYDVR0jBBgwFoAUJNRie0p1xbU0f5XCjPMf9eJl\nzZ4wDQYJKoZIhvcNAQELBQADggEBAIhCy0T9lUGR426BoNTAOkR5BIslGh4TqtBw\n6OgpK3MXliCsCJeW9tCo/tkObycb3EtpWx4qAkEHbWpsVBlevYBXJ2TKzs+khzo+\neZvXer83xSoHRtPEyCGfXp+pEDQ7ZUGRe/cffXIiuQLDNhDqhmRC5wxcR2LtVIwj\nstxE9cOJIb0WJIm5IpimqN2/DFGi6UYs5ygt3TOjhAep5UCeQ4XxbthgeKRj4Dac\na+LZaaYPaVzA3iY2DbzHTeiH3Nq64A4v9tZ+kZHyZ/2cLrC2kAHsIaKxv6B7YwLS\nDPzamtkRvCEYOJOPlbgKjoXL3Fu0de0FRt7F0TCV1ChGQE8wwyU=\n-----END CERTIFICATE-----",
                hold_instruction_code => undef,
                identifier => 'q8bTzEtcMM4JlYh2c77tGYkaLcw',
                invalidity_time => undef,
                issuer_dn => 'CN=GAMMA Signing CA 1,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => '',
                notafter => '4262889599', # 2105-01-31T23:59:59
                notbefore => '1483228800', # 2017-01-01T00:00:00
                pki_realm => 'gamma',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:ed:49:be:c7:96:1a:5f:0e:d9:e0:d6:98:72:5e:\n    9f:30:6d:0c:4c:0b:c8:23:fb:43:36:ab:7e:a9:30:\n    8c:ee:e5:5b:02:ea:77:62:e6:b3:2f:82:67:9c:5b:\n    a6:03:4a:57:5d:68:12:a4:fd:d4:82:d5:78:05:5c:\n    97:fd:9b:d7:6c:2c:9e:61:01:6f:47:d8:fd:de:69:\n    03:96:83:5b:2e:d6:75:fe:b4:66:a4:18:24:23:41:\n    3f:20:f3:54:88:aa:2b:02:3b:86:c5:09:49:9d:49:\n    c1:2c:ce:3b:4a:49:ce:c9:66:8d:3d:ab:3e:28:26:\n    95:b8:d2:96:63:9a:97:98:9e:f8:b5:c0:d2:09:15:\n    f6:c2:31:cd:c0:d8:30:da:50:35:7d:6d:e5:c7:fb:\n    c1:14:4f:f3:70:d6:1e:0d:f1:13:e3:3f:b1:bb:49:\n    d4:28:ba:fd:d9:5c:b1:45:09:d2:4f:d4:0c:61:f3:\n    f7:cb:b4:3a:90:84:37:b4:de:b2:91:89:d4:22:20:\n    c8:91:d5:dc:87:50:5e:9d:36:09:ac:da:93:90:05:\n    80:c5:31:74:39:38:1b:7b:86:17:bb:2e:bc:40:7f:\n    0c:04:b9:25:4a:ac:13:88:c0:4d:cc:00:bf:2f:ed:\n    90:dc:87:dd:89:5e:3c:d7:e1:ea:0b:67:be:50:e6:\n    e9:2b\nExponent: 65537 (0x10001)\n",
                reason_code => undef,
                req_key => undef,
                revocation_time => undef,
                status => 'ISSUED',
                subject => 'CN=GAMMA Client Bob 1,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => 'FD:03:95:1B:BF:0D:ED:06:62:60:0D:D0:D5:B1:5B:BA:F9:9C:EC:AD',
            },
            db_alias => {
                alias => 'gamma-bob-1',
                generation => undef,
                group_id => undef,
            },
            private_key => "-----BEGIN ENCRYPTED PRIVATE KEY-----\nMIIFDjBABgkqhkiG9w0BBQ0wMzAbBgkqhkiG9w0BBQwwDgQIoJgIbnq5r3MCAggA\nMBQGCCqGSIb3DQMHBAioJUmgKrFZEQSCBMis8a1EKX/dypouVRSdmazJJjESYZGj\ncIRH3NsyAY9vbThJlpA7HrSbZcOYmYQCOVvzDH6070r8DXdtzrZO+n3u5uuX5OZt\n1D19QwHw0zEmeNnGVsCo2Yy7AiCaIgEZ4JiupRLhKi+TBBFjyrt40ZtrlQkxQnk0\ntvqmFCrY3LdzP7mPKY2pnAHYtLsNtWao+bQrTchZjAo3RusTG2YYK2nG+LNwB8oZ\na0xFpzSQ6vkI1IBqRE7A0GebDIlNsZU2UeaH3LhhK3lilQ9GiBzoksYBQi0k76rz\nos5uYwWUdLxjqKGnG1VH9sAv3N37c0mwC613kjXcdZbJJ2fe9vKriP5Mcjua+2e+\nMEfQeEa9ABP423dKo7fN04r0vO/CmESysFygZNzU+f/Fj/KyhR3rLLRL3mX6qIZ9\n5SeDGnhCtu5oq91PAVfOd5KLr8eGwI5Yt9hm+NA/2t3K+pNYW2syzOw9/mgyLL3/\nRYuGCyW97rOqEHCW5B+7AtBek86j13dgTXAPuQIXTj8FFPtsI2l5x2J5fGtfSEzQ\nybdqRQgpcrxVlI67nqZjLC3i/BOd1S1hTAA6FbphXhhSFon+zEiKtR8gq+MCWI4I\nzfRTyo43r3I2cGdxjNAdyWGlsyp8lANQlidgxk2+AzvhJv2WIdcFD6Ub9PVkHWFg\nqJcktCDITGVDIO1t9+All/OG7nlrtquShHVGrjMJMJZm1SF090WCLou+/rnkabCH\nnQVeyLp2yfvYhPKLpWW1yIYqrxTSkf6n6QuipzvHsJmK0I3nMR8cMl5QuPnrCJxp\nfD1cvrY4MKuOd1Pe2smI+gid1jQcJ/rIh7FUslWKHD+JFVTGyUhbJNU663IpBRmL\ndmlUO0lqbgjONBWm1d1ZHX/2cUMhq1MkqTSzL0yXDePC7qt2CNz4z1ZJgChPbrwL\nYze8BvQhK3KigluEcgzSIEcbA10IqmQzX8p7ZoZI0Dhl2jKMQN2jEdp3PG151Q8M\np9lXCBL2pmE65WSdfWiA4gsYO44P5xlMWmfBpWMHll1vRV1cfgJA4/hkQud8Krw8\nywjcJurMcVEeRXmmM6GEfvSU1mqoTid5jYMuL9EvCRHltQ6skB+UusWPiEl+ODfv\nlz7+9Ltj79PpXkQEkeaWf5YBtrUa7YjYjcTpaqoS1okP06ZYayucTy+EdSivhj1R\nlZTsC4klCjHeHfaPOQYjwqOGs25HkQpzz/TofdBnDqpGXj3htQUAqm8GlW/EEhpp\nkQ1uWpk8SNMoB9K+MVER0SQZGipJKsVYvTGhUsu+bu/0XmBuIp1PIlVvNW4cXwJD\n2tEtJ9SsvaBFSW7WpcZrcumMQJByHXkHa/OsWLur3YI0/MCUjcqi5AHZtA1+2FB5\n5MkqxlZENLVKACvahGs+Q9b4Pm/T1RPhOBFaT+bgNlkApaaCAgnAN4FABr0FXHVO\niZtOfMZlvZdDNm5IHTB9ntZLtfP0vrvZ0EID7pyexUURtctjDzx1EsWmzqImCVsE\n8GScvqaKxtXJxjSh2vkqRuH4QLWi3VCBN0ZdiGfy1ADj9W2iFA+ZxA7fNkF56kei\n/vkPKvokczfjChklgPXvhX9iKJf+bidmhvWjgoapLAuSn5U+rWGocYnQgiOkyo+z\nuz4=\n-----END ENCRYPTED PRIVATE KEY-----",
        ),

    };
}

__PACKAGE__->meta->make_immutable;
