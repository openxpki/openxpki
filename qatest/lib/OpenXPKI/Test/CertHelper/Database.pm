package OpenXPKI::Test::CertHelper::Database;
use Moose;
use utf8;

=head1 NAME

OpenXPKI::Test::CertHelper::Database - Test helper that contains raw
certificate data to be inserted into the database and functions to do so.

=head1 DESCRIPTION

This class is not intended for direct use. Please use the class methods in
L<OpenXPKI::Test::CertHelper> instead.

=cut

# Project modules
use OpenXPKI::Server::Init;
use OpenXPKI::i18n;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Test::CertHelper::Database::PEM;

################################################################################
# Other attributes
#
has dbi => (
    is => 'ro',
    isa => 'OpenXPKI::Server::Database',
    lazy => 1,
    default => sub {
        CTX('dbi') or die "Could not instantiate database backend\n";
    },
);

################################################################################
# Other attributes
has _certs => (
    is => 'rw',
    isa => 'HashRef[OpenXPKI::Test::CertHelper::Database::PEM]',
    lazy => 1,
    builder => '_build_certs',
);

################################################################################

=head1 METHODS

=cut

sub BUILD {
    my $self = shift;
    $ENV{OPENXPKI_CONF_PATH} = '/etc/openxpki/config.d';
    # TODO #legacydb Remove dbi_backend once we got rid of the old DB layer
    OpenXPKI::Server::Init::init({
        TASKS  => ['config_versioned','log','api','crypto_layer','dbi','dbi_backend'],
        SILENT => 1,
        CLI => 1,
    });
}

=head2 cert

Returns an instance of L<OpenXPKI::Test::CertHelper::Database::PEM> with the
requested test certificate data.

    print $db->cert("acme_root_2")->id, "\n";

=cut
sub cert {
    my ($self, $certname) =@_;
    die "A test certificate named '$certname' does not exist." unless $self->_certs->{$certname};
    return $self->_certs->{$certname};
}

=head2 all_cert_ids

Returns an ArrayRef with the IDs ("subject_key_identifier") of all test
certificates handled by this class.

=cut
sub all_cert_ids {
    my $self = shift;
    return [ map { $_->id } values %{$self->_certs} ];
}

=head2 cert_names_where

Returns a list with the internal short names of all test certificates
where the given attribute has the given value.

=cut
sub cert_names_where {
    my ($self, $attribute, $value) = @_;
    my @result = grep { $self->cert($_)->db->{$attribute} eq $value } keys %{$self->_certs};
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
    } keys %{$self->_certs};
    die "No test certificates found for realm '$realm', generation $gen" unless scalar(@result);
    return @result;
}

=head2 all_cert_names

Returns an ArrayRef with the internal short names of all test certificates
handled by this class.

=cut
sub all_cert_names {
    my $self = shift;
    return [ keys %{$self->_certs} ];
}

=head2 insert_all

Inserts all test certificates into the database.

=cut
sub insert_all {
    my ($self) = @_;
    $self->dbi->start_txn;

    $self->dbi->merge(
        into => "certificate",
        set => $self->cert($_)->db,
        where => { subject_key_identifier => $self->cert($_)->id },
    ) for @{ $self->all_cert_names };

    for (@{ $self->all_cert_names }) {
        next unless $self->cert($_)->db_alias->{alias};
        $self->dbi->merge(
            into => "aliases",
            set => {
                %{ $self->cert($_)->db_alias },
                identifier  => $self->cert($_)->db->{identifier},
                notbefore   => $self->cert($_)->db->{notbefore},
                notafter    => $self->cert($_)->db->{notafter},
            },
            where => {
                pki_realm   => $self->cert($_)->db->{pki_realm},
                alias       => $self->cert($_)->db_alias->{alias},
            },
        );
    }
    $self->dbi->commit;
}

=head2 delete_all

Deletes all test certificates from the database.

=cut
sub delete_all {
    my ($self) = @_;
    $self->dbi->start_txn;
    $self->dbi->delete(from => 'certificate', where => { subject_key_identifier => $self->all_cert_ids } );
    $self->dbi->delete(from => 'aliases',     where => { identifier => [ map { $_->db->{identifier} } values %{$self->_certs} ] } );
    $self->dbi->commit;
}

=head2 acme1_pkcs7

Returns the PKCS7 file contents that containts the certificates "beta_root_1",
"beta_signer_1" and "beta_alice_1".

=cut
# To convert a .p7b file:
# perl -e 'open (my $fh, "<", "beta-alice-1.p7b"); my @d = <$fh>; close $fh; chomp(@d); printf "return \"%s\\n\";\n", join("\\n", @d);'


sub beta_alice_pkcs7 {
    return "-----BEGIN PKCS7-----\n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\n-----END PKCS7-----\n";
}

# Test certificate data
sub _build_certs {
    return {
        alpha_alice_1 => OpenXPKI::Test::CertHelper::Database::PEM->new(
            label => 'ALPHA Client Alice',
            db => {
                authority_key_identifier => 'D9:C7:B2:D3:61:FF:C4:36:0A:E4:C3:2D:2E:64:1A:6D:E5:F8:CF:8D',
                cert_key => '5',
                data => "-----BEGIN CERTIFICATE-----\nMIIDgDCCAmigAwIBAgIBBTANBgkqhkiG9w0BAQsFADBZMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGTAXBgNVBAMMEEFMUEhBIFNpZ25pbmcgQ0EwIhgPMjAwNjAxMDEwMDAwMDBaGA8y\nMDA3MDEzMTIzNTk1OVowWzETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmSJomT\n8ixkARkWCE9wZW5YUEtJMQ0wCwYDVQQLDARBQ01FMRswGQYDVQQDDBJBTFBIQSBD\nbGllbnQgQWxpY2UwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQClfrEJ\nd0MIwqmZJjOLL7/idFdZQpxIlUex13LnRDz3ksHPj3cVcH48IOhJkdnbmmdsyJG4\nSYEbuzNTmmycUdmLilx4Ph5dkkimRxqbCs7smF9ObhnGy6i+4bgSxXa/TtM3rjQB\nH8btYpZudDeP1l7zivNjz4sd4IM9WQx1vjQXzJ+Suy8w1Ohs6LzoAUOFT1S1ttm0\n2jWjLZHzMD0qP0+wYLVQNVMTE6V8UHGXlFxZHj/UZrZEj0LRelOVTY+TY7N3jJEy\ngtw0FtOLZx7XfXLHNkQYZkeeHWPr4a3lkBoPpoG4BR0Y59+B5xzvSlPj3FwIrvLD\nLrmGGAp+GluBFWuxAgMBAAGjTTBLMAkGA1UdEwQCMAAwHQYDVR0OBBYEFPni3BQf\ndpp51PpxzCYqRWRPEfh8MB8GA1UdIwQYMBaAFNnHstNh/8Q2CuTDLS5kGm3l+M+N\nMA0GCSqGSIb3DQEBCwUAA4IBAQCHGcJk3vjwoytW2L7y0q9W5qBPjJ07F5TFXNzr\nQxO7NHR0zcUQSmngmnuIJ7w1ir78QdrHACkcx/K4jTP3EV0J/SVPd1XSUIiVGp6y\nz9GOMZ4UOPomrEuIj4QbQJCYGDwwZdYQBqo0WQFwO2oDSyokHrIN6Flru9fGN+jw\nBHFP6+b9eO2Vu+ygNv9Fut8zq7qLJajryHDFTmBYsUf6HYzHu4ZLkvKFbf1oOvkj\nko3ccnjwzw7MOzTKiNL9jJsg6GQsEBAWejmme1LGi27XCVG8pRCI16lhvGk/MFlO\nS7IJq2+9aed2XuCULCeEbxV66g/zsoLffoQaRaLfvFHT7381\n-----END CERTIFICATE-----",
                identifier => '93t0tVjGuID4qB5KweyqPodkcOI',
                issuer_dn => 'CN=ALPHA Signing CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'KmALfiYiQq7fgh0sXYXtPI36k8g',
                loa => undef,
                notafter => '1170287999', # 2007-01-31T23:59:59
                notbefore => '1136073600', # 2006-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:a5:7e:b1:09:77:43:08:c2:a9:99:26:33:8b:2f:\n    bf:e2:74:57:59:42:9c:48:95:47:b1:d7:72:e7:44:\n    3c:f7:92:c1:cf:8f:77:15:70:7e:3c:20:e8:49:91:\n    d9:db:9a:67:6c:c8:91:b8:49:81:1b:bb:33:53:9a:\n    6c:9c:51:d9:8b:8a:5c:78:3e:1e:5d:92:48:a6:47:\n    1a:9b:0a:ce:ec:98:5f:4e:6e:19:c6:cb:a8:be:e1:\n    b8:12:c5:76:bf:4e:d3:37:ae:34:01:1f:c6:ed:62:\n    96:6e:74:37:8f:d6:5e:f3:8a:f3:63:cf:8b:1d:e0:\n    83:3d:59:0c:75:be:34:17:cc:9f:92:bb:2f:30:d4:\n    e8:6c:e8:bc:e8:01:43:85:4f:54:b5:b6:d9:b4:da:\n    35:a3:2d:91:f3:30:3d:2a:3f:4f:b0:60:b5:50:35:\n    53:13:13:a5:7c:50:71:97:94:5c:59:1e:3f:d4:66:\n    b6:44:8f:42:d1:7a:53:95:4d:8f:93:63:b3:77:8c:\n    91:32:82:dc:34:16:d3:8b:67:1e:d7:7d:72:c7:36:\n    44:18:66:47:9e:1d:63:eb:e1:ad:e5:90:1a:0f:a6:\n    81:b8:05:1d:18:e7:df:81:e7:1c:ef:4a:53:e3:dc:\n    5c:08:ae:f2:c3:2e:b9:86:18:0a:7e:1a:5b:81:15:\n    6b:b1\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA Client Alice,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => 'F9:E2:DC:14:1F:76:9A:79:D4:FA:71:CC:26:2A:45:64:4F:11:F8:7C',
            },
            db_alias => {
                alias => 'alpha-alice-1',
                generation => undef,
                group_id => undef,
            },
        ),

        alpha_alice_2 => OpenXPKI::Test::CertHelper::Database::PEM->new(
            label => 'ALPHA Client Alice',
            db => {
                authority_key_identifier => 'B7:F9:80:4C:64:53:F8:E2:0A:83:E9:80:C7:81:A2:E9:02:9C:CC:A5',
                cert_key => '11',
                data => "-----BEGIN CERTIFICATE-----\nMIIDgDCCAmigAwIBAgIBCzANBgkqhkiG9w0BAQsFADBZMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGTAXBgNVBAMMEEFMUEhBIFNpZ25pbmcgQ0EwIhgPMjAwNzAxMDEwMDAwMDBaGA8y\nMTA3MDEzMTIzNTk1OVowWzETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmSJomT\n8ixkARkWCE9wZW5YUEtJMQ0wCwYDVQQLDARBQ01FMRswGQYDVQQDDBJBTFBIQSBD\nbGllbnQgQWxpY2UwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC1XP+M\njq8sLEPDkN1y+i3ciRJyLjLthv/eu4TZQNroisfblpG9LEgmKD4g/gLz/WXfVHN+\nQnr6bPqhPWENphZlFSVdzsT7x6qsdyEIWMWZ/KCVxWyN9jRPVMNJ2gfNNGF8Pe34\nfsL6DGfOcu96LjUpwzZvVFeRcBXZev7UAU0VufP6CjHIuXfLjiHfGG/tUqwoCm9c\nHIiDs9av4PWO5pYmIlUr4zvTKwfYexWX15HOrRTpMWMbWVDNlAAdgD4kW09Hv1nd\nThG788OQrUbhcTWK7PXJQMUpv3OWsVLOSxnGiiNcCDtPsjUccB9P/pA2itPxxQzp\ntq/BlW6clssIBlQpAgMBAAGjTTBLMAkGA1UdEwQCMAAwHQYDVR0OBBYEFLyBTsEU\nJJ3hTylhR3YOn5kYOeZ6MB8GA1UdIwQYMBaAFLf5gExkU/jiCoPpgMeBoukCnMyl\nMA0GCSqGSIb3DQEBCwUAA4IBAQDJKld11v84egQuA2Bpltox/tAw8R2l0AnsvoWw\nJumiV0DeHM1R2mfeIFaIFux9mnczW0ZJJFSe0l/hNIsXxtHn22D86H0LTAkbFtGO\nlsYqFi1hJkolfaMIq3SfwVEjVpZJ7njGF96kzR9rDOORRBtre5O8ePzNi3Xhr5Gs\ntoSzq+JYMgTopWJct2s4O5xJxFDLVH6kNQCYwYaKeGn8o5QRoeqn2XFpheU5izcN\nW+QBj0mjJFQuEzTnwWiZEHQSZnXCc6UzQ73bBqydTyFQK9UJ4WvaPuqAgQa7kouF\nv3YxWXhB2Y8eAN6SzGuPBA72wEmrE9a8VyugTyGX7ouutdDM\n-----END CERTIFICATE-----",
                identifier => 'ekq5E8oUm_CmBM_YU3E80jKGlCw',
                issuer_dn => 'CN=ALPHA Signing CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'd7RhCpUYe88uAVAmKHXBfeEFi0c',
                loa => undef,
                notafter => '4294967295', # 2106-02-07T06:28:15
                notbefore => '1167609600', # 2007-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:b5:5c:ff:8c:8e:af:2c:2c:43:c3:90:dd:72:fa:\n    2d:dc:89:12:72:2e:32:ed:86:ff:de:bb:84:d9:40:\n    da:e8:8a:c7:db:96:91:bd:2c:48:26:28:3e:20:fe:\n    02:f3:fd:65:df:54:73:7e:42:7a:fa:6c:fa:a1:3d:\n    61:0d:a6:16:65:15:25:5d:ce:c4:fb:c7:aa:ac:77:\n    21:08:58:c5:99:fc:a0:95:c5:6c:8d:f6:34:4f:54:\n    c3:49:da:07:cd:34:61:7c:3d:ed:f8:7e:c2:fa:0c:\n    67:ce:72:ef:7a:2e:35:29:c3:36:6f:54:57:91:70:\n    15:d9:7a:fe:d4:01:4d:15:b9:f3:fa:0a:31:c8:b9:\n    77:cb:8e:21:df:18:6f:ed:52:ac:28:0a:6f:5c:1c:\n    88:83:b3:d6:af:e0:f5:8e:e6:96:26:22:55:2b:e3:\n    3b:d3:2b:07:d8:7b:15:97:d7:91:ce:ad:14:e9:31:\n    63:1b:59:50:cd:94:00:1d:80:3e:24:5b:4f:47:bf:\n    59:dd:4e:11:bb:f3:c3:90:ad:46:e1:71:35:8a:ec:\n    f5:c9:40:c5:29:bf:73:96:b1:52:ce:4b:19:c6:8a:\n    23:5c:08:3b:4f:b2:35:1c:70:1f:4f:fe:90:36:8a:\n    d3:f1:c5:0c:e9:b6:af:c1:95:6e:9c:96:cb:08:06:\n    54:29\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA Client Alice,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => 'BC:81:4E:C1:14:24:9D:E1:4F:29:61:47:76:0E:9F:99:18:39:E6:7A',
            },
            db_alias => {
                alias => 'alpha-alice-2',
                generation => undef,
                group_id => undef,
            },
        ),

        alpha_alice_3 => OpenXPKI::Test::CertHelper::Database::PEM->new(
            label => 'ALPHA Client Alice',
            db => {
                authority_key_identifier => '3F:AE:5F:B1:7A:D1:66:39:9C:15:11:7A:E4:9B:FD:B1:7F:05:64:C9',
                cert_key => '17',
                data => "-----BEGIN CERTIFICATE-----\nMIIDgDCCAmigAwIBAgIBETANBgkqhkiG9w0BAQsFADBZMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGTAXBgNVBAMMEEFMUEhBIFNpZ25pbmcgQ0EwIhgPMjEwNzAxMDEwMDAwMDBaGA8y\nMTA4MDEzMTIzNTk1OVowWzETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmSJomT\n8ixkARkWCE9wZW5YUEtJMQ0wCwYDVQQLDARBQ01FMRswGQYDVQQDDBJBTFBIQSBD\nbGllbnQgQWxpY2UwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC0N4Pb\n2BCzVbflfvlIXoDRO39mHqCsp+hBK/v6g2FiSAMu+DGoge5DMwXhP5+dtTKe1iA+\neLPVGTkAYM/owGPHk4iGpQBDiUX3BJ48gWujvLwDdZXIVVCy6xc/qNIeQPofTTaM\nzyyAyuIHuPcCQQjRCevsSKugaWQ5ZHJJ/3TuDtxbIpPe8jDQ4tGMVpg790/zD1Q3\nM59GraMvgR/3x6VgDWhdi3G4V7WOn52XeKcMb3ZB072CrEhdQpAIYg2mir2lTMVj\nXH8K5RuMhsSJAnj7LjIrOAAJoutpDwD/Adt2iXNu8AgAgXDYJWW6Qq+OUW3iSzLh\nlJOBFeMonkzJVvnNAgMBAAGjTTBLMAkGA1UdEwQCMAAwHQYDVR0OBBYEFKlbtXy3\nmzuMvYhaKpMqLPkKIn0jMB8GA1UdIwQYMBaAFD+uX7F60WY5nBUReuSb/bF/BWTJ\nMA0GCSqGSIb3DQEBCwUAA4IBAQCJqe9fEgUsN+iaTHv/2b9xyRruzJ8wMX2FX/4Z\naWq/XA37EQ9ACSDryhYkbbbXvFwuQMgOFWZNXMqd4RQZdkPrLctjxgXN+t7mYEfi\n4kbgQi45+Z+yKyqofkMY6Nz2bFm4j9uXWtTWDhmSlmIDjGbdIr/xv+wS2VjIBjkh\nKRNAX0lTLBA8XmCe1a6Ym+P+NavWBh2cVYajM8lVFoeW3JxXKvSQ+BwU6l+fYHIQ\ncMDAdR9H9e7ZPGYOW5iqAD+cgmOUbyC79gjczzvmzemJtLwtSaMi4jFpjfbVeKsL\nvYi4Yx9bTu0w33TAIKFSTmKBdx0072p//vXiWBE6fDnQakqI\n-----END CERTIFICATE-----",
                identifier => 'k1RRWVMoZx0v2GBYMq4xht06Xws',
                issuer_dn => 'CN=ALPHA Signing CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'QYQa-QZFkgiaVvSShYRjd9alxNU',
                loa => undef,
                notafter => '4294967295', # 2106-02-07T06:28:15
                notbefore => '4294967295', # 2106-02-07T06:28:15
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:b4:37:83:db:d8:10:b3:55:b7:e5:7e:f9:48:5e:\n    80:d1:3b:7f:66:1e:a0:ac:a7:e8:41:2b:fb:fa:83:\n    61:62:48:03:2e:f8:31:a8:81:ee:43:33:05:e1:3f:\n    9f:9d:b5:32:9e:d6:20:3e:78:b3:d5:19:39:00:60:\n    cf:e8:c0:63:c7:93:88:86:a5:00:43:89:45:f7:04:\n    9e:3c:81:6b:a3:bc:bc:03:75:95:c8:55:50:b2:eb:\n    17:3f:a8:d2:1e:40:fa:1f:4d:36:8c:cf:2c:80:ca:\n    e2:07:b8:f7:02:41:08:d1:09:eb:ec:48:ab:a0:69:\n    64:39:64:72:49:ff:74:ee:0e:dc:5b:22:93:de:f2:\n    30:d0:e2:d1:8c:56:98:3b:f7:4f:f3:0f:54:37:33:\n    9f:46:ad:a3:2f:81:1f:f7:c7:a5:60:0d:68:5d:8b:\n    71:b8:57:b5:8e:9f:9d:97:78:a7:0c:6f:76:41:d3:\n    bd:82:ac:48:5d:42:90:08:62:0d:a6:8a:bd:a5:4c:\n    c5:63:5c:7f:0a:e5:1b:8c:86:c4:89:02:78:fb:2e:\n    32:2b:38:00:09:a2:eb:69:0f:00:ff:01:db:76:89:\n    73:6e:f0:08:00:81:70:d8:25:65:ba:42:af:8e:51:\n    6d:e2:4b:32:e1:94:93:81:15:e3:28:9e:4c:c9:56:\n    f9:cd\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA Client Alice,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => 'A9:5B:B5:7C:B7:9B:3B:8C:BD:88:5A:2A:93:2A:2C:F9:0A:22:7D:23',
            },
            db_alias => {
                alias => 'alpha-alice-3',
                generation => undef,
                group_id => undef,
            },
        ),

        alpha_bob_1 => OpenXPKI::Test::CertHelper::Database::PEM->new(
            label => 'ALPHA Client Bob',
            db => {
                authority_key_identifier => 'D9:C7:B2:D3:61:FF:C4:36:0A:E4:C3:2D:2E:64:1A:6D:E5:F8:CF:8D',
                cert_key => '6',
                data => "-----BEGIN CERTIFICATE-----\nMIIDfjCCAmagAwIBAgIBBjANBgkqhkiG9w0BAQsFADBZMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGTAXBgNVBAMMEEFMUEhBIFNpZ25pbmcgQ0EwIhgPMjAwNjAxMDEwMDAwMDBaGA8y\nMDA3MDEzMTIzNTk1OVowWTETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmSJomT\n8ixkARkWCE9wZW5YUEtJMQ0wCwYDVQQLDARBQ01FMRkwFwYDVQQDDBBBTFBIQSBD\nbGllbnQgQm9iMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqqjVAVPB\n+DcwuPuclIMkMoJk4DDw4oZtywztv3FF73WBcBFD/LHnNpiPC/vkXcfsC9f3A7sm\nOw9TiM9kgdP+9DgOYDT9X9bwI6JoGmtAVryZUQN2NO785aaBU5UwlZbsSuIHbvvE\n0DTeH8RktZg5EP9oCyWuEM8zV6fErjYkiwIsC1OIO4nMNcWn1/tgscFYsnyrPDDc\nluCbis5j49hzQ7u14XXAHxnsrVp3oljpcFB11eHQM3CK3G4lMb+Y2RXlAz+arN8A\nZu44kJZlFEcOi5lhn0OWnplDQ4C0pb5WbFa/eDSWKd/TLHmFK032Ex40cmue2HKB\nFIGRImJqogptjQIDAQABo00wSzAJBgNVHRMEAjAAMB0GA1UdDgQWBBRpOhiGL5OG\neZ9GmPYVvxWjNyEkyDAfBgNVHSMEGDAWgBTZx7LTYf/ENgrkwy0uZBpt5fjPjTAN\nBgkqhkiG9w0BAQsFAAOCAQEAMs07nT37N4Cwokp1yN/5340TTaJUskW/Mi/mFts9\nYyM9g0oY7ie/EZan6mS2luzc6pTYCrclobRNHQ8WtwuhlQFcFphgaNs8d1IeHjyQ\npmYzsOlL1RdNFuEKw0wmof0IhOm5J4MoXwW12jMa1VcwVuL5z5ooElG5I5Uy6A+q\n7YLrtW/fS9gIw5t2C1288Y81xC2FodGuyPn6GiHyiPOF2IGOTZ4lVEwGbln9Mz6h\nTXwgwV0ZSG0iBZorLvV8HhGuxVJdK/Ljk6gKomzC9Y0zWlKO6TxSmFMrNJS9Xo9m\n73TVp4FxKnyTkUqdS4ARt6yE465cB0qFNvFuzQnpYIJhsw==\n-----END CERTIFICATE-----",
                identifier => 'nzuUACf-LIdOwSRi6GuHGbwwL3Y',
                issuer_dn => 'CN=ALPHA Signing CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'KmALfiYiQq7fgh0sXYXtPI36k8g',
                loa => undef,
                notafter => '1170287999', # 2007-01-31T23:59:59
                notbefore => '1136073600', # 2006-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:aa:a8:d5:01:53:c1:f8:37:30:b8:fb:9c:94:83:\n    24:32:82:64:e0:30:f0:e2:86:6d:cb:0c:ed:bf:71:\n    45:ef:75:81:70:11:43:fc:b1:e7:36:98:8f:0b:fb:\n    e4:5d:c7:ec:0b:d7:f7:03:bb:26:3b:0f:53:88:cf:\n    64:81:d3:fe:f4:38:0e:60:34:fd:5f:d6:f0:23:a2:\n    68:1a:6b:40:56:bc:99:51:03:76:34:ee:fc:e5:a6:\n    81:53:95:30:95:96:ec:4a:e2:07:6e:fb:c4:d0:34:\n    de:1f:c4:64:b5:98:39:10:ff:68:0b:25:ae:10:cf:\n    33:57:a7:c4:ae:36:24:8b:02:2c:0b:53:88:3b:89:\n    cc:35:c5:a7:d7:fb:60:b1:c1:58:b2:7c:ab:3c:30:\n    dc:96:e0:9b:8a:ce:63:e3:d8:73:43:bb:b5:e1:75:\n    c0:1f:19:ec:ad:5a:77:a2:58:e9:70:50:75:d5:e1:\n    d0:33:70:8a:dc:6e:25:31:bf:98:d9:15:e5:03:3f:\n    9a:ac:df:00:66:ee:38:90:96:65:14:47:0e:8b:99:\n    61:9f:43:96:9e:99:43:43:80:b4:a5:be:56:6c:56:\n    bf:78:34:96:29:df:d3:2c:79:85:2b:4d:f6:13:1e:\n    34:72:6b:9e:d8:72:81:14:81:91:22:62:6a:a2:0a:\n    6d:8d\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA Client Bob,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '69:3A:18:86:2F:93:86:79:9F:46:98:F6:15:BF:15:A3:37:21:24:C8',
            },
            db_alias => {
                alias => 'alpha-bob-1',
                generation => undef,
                group_id => undef,
            },
        ),

        alpha_bob_2 => OpenXPKI::Test::CertHelper::Database::PEM->new(
            label => 'ALPHA Client Bob',
            db => {
                authority_key_identifier => 'B7:F9:80:4C:64:53:F8:E2:0A:83:E9:80:C7:81:A2:E9:02:9C:CC:A5',
                cert_key => '12',
                data => "-----BEGIN CERTIFICATE-----\nMIIDfjCCAmagAwIBAgIBDDANBgkqhkiG9w0BAQsFADBZMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGTAXBgNVBAMMEEFMUEhBIFNpZ25pbmcgQ0EwIhgPMjAwNzAxMDEwMDAwMDBaGA8y\nMTA3MDEzMTIzNTk1OVowWTETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmSJomT\n8ixkARkWCE9wZW5YUEtJMQ0wCwYDVQQLDARBQ01FMRkwFwYDVQQDDBBBTFBIQSBD\nbGllbnQgQm9iMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAzINzRXQc\n5JbDh7A7jhSJBOMDDbeslegETCWV2GQ7QjQJnXBm3E6roBq85vPQyvh401iff797\nYsUb5DoH3wb+fHgHfZjLvtWOoDdOMRjf/ePpOW84u5ucZspv6tW/NWiyAvOwf/Az\nB1oGZV6okftOqeQzj2BUV5/9FFbN9a4FOZ3Gi572n+Kv3PFsNjdH4jykW6EIUivj\nuArdr5DG+J91YN5zxs176BkcOUIfjY4qsiwR0Y67ilYydBwxhiIsqCKPIQVTfWCF\neUptxJR9sI8//sDnZ3FtFs3LueYOm2v7lA7x/vUm+vEle9+LVsTvPa8KjVsd1Yz1\n4k4mytbDzvwxZwIDAQABo00wSzAJBgNVHRMEAjAAMB0GA1UdDgQWBBTZ/onSjJtP\nnsH2fnl4j6wG4Nv/hTAfBgNVHSMEGDAWgBS3+YBMZFP44gqD6YDHgaLpApzMpTAN\nBgkqhkiG9w0BAQsFAAOCAQEAY4sMFMivh83pONuU5Wc25GiI8eoP8xPtzutttCcG\nfj4SsdzHEL7WsWyTMVqGQYtPiKQfin49+IfwLjkKS6ewlyt+l5rqUz67Ajbsm/pO\nY84v/PR2FQQAq0gsoTHsWcRX+Ffinv245epxojKqCb4NNvMU7mZhOzTPBBxOFIqw\nbwbPfJNka9HPLBUhem59hl1Iwi9reruqTW36BmuB4HbRqHky/SXeh86Bl9xBSYrq\nsHe9v/2Ob+gF2oY7o7gof+K3spINEuigfk9nnVWHlytB8rdVSn408TA7Yd8hcJiJ\nnwwUTIEiv1RoP8p5jlZF3ZWBmbmhW09S4zbFJFCBkMdC7Q==\n-----END CERTIFICATE-----",
                identifier => 'jotgitxWjYBiWBzvJrsoiznDB5c',
                issuer_dn => 'CN=ALPHA Signing CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'd7RhCpUYe88uAVAmKHXBfeEFi0c',
                loa => undef,
                notafter => '4294967295', # 2106-02-07T06:28:15
                notbefore => '1167609600', # 2007-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:cc:83:73:45:74:1c:e4:96:c3:87:b0:3b:8e:14:\n    89:04:e3:03:0d:b7:ac:95:e8:04:4c:25:95:d8:64:\n    3b:42:34:09:9d:70:66:dc:4e:ab:a0:1a:bc:e6:f3:\n    d0:ca:f8:78:d3:58:9f:7f:bf:7b:62:c5:1b:e4:3a:\n    07:df:06:fe:7c:78:07:7d:98:cb:be:d5:8e:a0:37:\n    4e:31:18:df:fd:e3:e9:39:6f:38:bb:9b:9c:66:ca:\n    6f:ea:d5:bf:35:68:b2:02:f3:b0:7f:f0:33:07:5a:\n    06:65:5e:a8:91:fb:4e:a9:e4:33:8f:60:54:57:9f:\n    fd:14:56:cd:f5:ae:05:39:9d:c6:8b:9e:f6:9f:e2:\n    af:dc:f1:6c:36:37:47:e2:3c:a4:5b:a1:08:52:2b:\n    e3:b8:0a:dd:af:90:c6:f8:9f:75:60:de:73:c6:cd:\n    7b:e8:19:1c:39:42:1f:8d:8e:2a:b2:2c:11:d1:8e:\n    bb:8a:56:32:74:1c:31:86:22:2c:a8:22:8f:21:05:\n    53:7d:60:85:79:4a:6d:c4:94:7d:b0:8f:3f:fe:c0:\n    e7:67:71:6d:16:cd:cb:b9:e6:0e:9b:6b:fb:94:0e:\n    f1:fe:f5:26:fa:f1:25:7b:df:8b:56:c4:ef:3d:af:\n    0a:8d:5b:1d:d5:8c:f5:e2:4e:26:ca:d6:c3:ce:fc:\n    31:67\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA Client Bob,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => 'D9:FE:89:D2:8C:9B:4F:9E:C1:F6:7E:79:78:8F:AC:06:E0:DB:FF:85',
            },
            db_alias => {
                alias => 'alpha-bob-2',
                generation => undef,
                group_id => undef,
            },
        ),

        alpha_bob_3 => OpenXPKI::Test::CertHelper::Database::PEM->new(
            label => 'ALPHA Client Bob',
            db => {
                authority_key_identifier => '3F:AE:5F:B1:7A:D1:66:39:9C:15:11:7A:E4:9B:FD:B1:7F:05:64:C9',
                cert_key => '18',
                data => "-----BEGIN CERTIFICATE-----\nMIIDfjCCAmagAwIBAgIBEjANBgkqhkiG9w0BAQsFADBZMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGTAXBgNVBAMMEEFMUEhBIFNpZ25pbmcgQ0EwIhgPMjEwNzAxMDEwMDAwMDBaGA8y\nMTA4MDEzMTIzNTk1OVowWTETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmSJomT\n8ixkARkWCE9wZW5YUEtJMQ0wCwYDVQQLDARBQ01FMRkwFwYDVQQDDBBBTFBIQSBD\nbGllbnQgQm9iMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqi+9gF8W\nrN49Wzu8LRd5BIs6sHF60vY03fU3scht3pwogoI/BPxoU5vqiYxUsEQPvjOF3JG6\n0JiNt8+A0co94DC88hpOSZPvLtM0jJ9aWfrL/VpgPd9thEafN3dOyp6AiW4dX6h3\nM/30QXk+pXsX9gOAtmAyAN5h4JadWicXGSwB4AE3bKFB0wAXHHLu+YJXamaVlSQV\nNgz3y0RgoJ13hIkuNizwC4lxav6vdrLsc28n99N2lPgxbW7Zs8w1szKkQAGVCtyk\nszS8Utynx2qQjSbSd99mgKlPGyb2jH7R+5efYSZfgB7zj4p1bHOvOjE7HTPq6DOR\n6CdLBbfadgxoPQIDAQABo00wSzAJBgNVHRMEAjAAMB0GA1UdDgQWBBS8HVA5kdOw\nG4jkmPKAVAgY0XpNbjAfBgNVHSMEGDAWgBQ/rl+xetFmOZwVEXrkm/2xfwVkyTAN\nBgkqhkiG9w0BAQsFAAOCAQEAHNa6RN7xCUXwnT5JtZUbjNVjkWiXyM8viMjWlSGj\nDK4ZUArhCYG/Esp2HetXguFXNHprsE+5QXdyBVJCOFzJuWR6WtESvMlchaKUI8mX\ne2hCkchNAfeRzG909WulouLuL4t0YuuS9QZGtx3jboRI7fcRBebOwx7kZqgN/voI\nf3jVVVZzX1uN7dJQ715xpdVTUJRBx/A3ECKpIjfWQ/jfPIto9X89ppDVo4IVq2+W\nDQB4BJ8ldHWkMh4q+uiOJYiEnWEApSDXYdBcD1bOIDA5Yhyairds1D++ogZUSBov\nusmrSg1aB6DS8sI9ryOF3M8Vv5XrRTaTJC8n2ROucXGHPQ==\n-----END CERTIFICATE-----",
                identifier => 'czsxXkxkJzvK8ksy4K7s1qW-nlM',
                issuer_dn => 'CN=ALPHA Signing CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'QYQa-QZFkgiaVvSShYRjd9alxNU',
                loa => undef,
                notafter => '4294967295', # 2106-02-07T06:28:15
                notbefore => '4294967295', # 2106-02-07T06:28:15
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:aa:2f:bd:80:5f:16:ac:de:3d:5b:3b:bc:2d:17:\n    79:04:8b:3a:b0:71:7a:d2:f6:34:dd:f5:37:b1:c8:\n    6d:de:9c:28:82:82:3f:04:fc:68:53:9b:ea:89:8c:\n    54:b0:44:0f:be:33:85:dc:91:ba:d0:98:8d:b7:cf:\n    80:d1:ca:3d:e0:30:bc:f2:1a:4e:49:93:ef:2e:d3:\n    34:8c:9f:5a:59:fa:cb:fd:5a:60:3d:df:6d:84:46:\n    9f:37:77:4e:ca:9e:80:89:6e:1d:5f:a8:77:33:fd:\n    f4:41:79:3e:a5:7b:17:f6:03:80:b6:60:32:00:de:\n    61:e0:96:9d:5a:27:17:19:2c:01:e0:01:37:6c:a1:\n    41:d3:00:17:1c:72:ee:f9:82:57:6a:66:95:95:24:\n    15:36:0c:f7:cb:44:60:a0:9d:77:84:89:2e:36:2c:\n    f0:0b:89:71:6a:fe:af:76:b2:ec:73:6f:27:f7:d3:\n    76:94:f8:31:6d:6e:d9:b3:cc:35:b3:32:a4:40:01:\n    95:0a:dc:a4:b3:34:bc:52:dc:a7:c7:6a:90:8d:26:\n    d2:77:df:66:80:a9:4f:1b:26:f6:8c:7e:d1:fb:97:\n    9f:61:26:5f:80:1e:f3:8f:8a:75:6c:73:af:3a:31:\n    3b:1d:33:ea:e8:33:91:e8:27:4b:05:b7:da:76:0c:\n    68:3d\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA Client Bob,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => 'BC:1D:50:39:91:D3:B0:1B:88:E4:98:F2:80:54:08:18:D1:7A:4D:6E',
            },
            db_alias => {
                alias => 'alpha-bob-3',
                generation => undef,
                group_id => undef,
            },
        ),

        alpha_scep_1 => OpenXPKI::Test::CertHelper::Database::PEM->new(
            label => 'ALPHA SCEP',
            db => {
                authority_key_identifier => 'E5:64:77:5A:87:EC:A6:6B:22:B3:B4:5C:25:EA:ED:2A:24:26:04:83',
                cert_key => '4',
                data => "-----BEGIN CERTIFICATE-----\nMIIDdTCCAl2gAwIBAgIBBDANBgkqhkiG9w0BAQsFADBWMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nFjAUBgNVBAMMDUFMUEhBIFJvb3QgQ0EwIhgPMjAwNjAxMDEwMDAwMDBaGA8yMDA3\nMDEzMTIzNTk1OVowUzETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmSJomT8ixk\nARkWCE9wZW5YUEtJMQ0wCwYDVQQLDARBQ01FMRMwEQYDVQQDDApBTFBIQSBTQ0VQ\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA8cVZ2A4NkV1GIUR6H+N3\nuHzyBdwu0U699dp2pVNnYhTEKHCdfomI3bHBWkRxUipON1xtB81aPKkf0yU8SEQX\nPRnCvHKNRNLyqTbH4A6vSpWg8p3NOCnM2fFss3k2wEgowqmuw9PYjlhABwy4LgxG\nm3/R413wWvbkuI9WRjJkmhfsG9Zvrw8uco13pFBgykd+6Vs1FxwvnHXXcfTUl7J2\neqqCp6KhaN7XbBZM68Az2z+mQKLrkmA554IMxJ/3HPw+McAnJxrg7WA6iEPMyccB\nWmgp0HaW6Qca/FcdReLm6G+55o0221czZql2YOcupQ3lhYARlyUUfZ0ktJ/F9p4c\n1QIDAQABo00wSzAJBgNVHRMEAjAAMB0GA1UdDgQWBBSC1vp9NzSMEfLGDIcPlTQq\nvxTC+TAfBgNVHSMEGDAWgBTlZHdah+ymayKztFwl6u0qJCYEgzANBgkqhkiG9w0B\nAQsFAAOCAQEAK6aMy272WCqfEJ3yBcm9Fy6acgIkT1UWG/ngm628zJaXtXlvlkyE\nm7KXzwW/P6Hu1EramX4z8NR6nwjb8S1plrx4//ZGcm3gfzb8K5f2CVY5rm6orXR+\nQrFdDIUuBRyE0OIo55vQJ+FSng3dygkunNhz6dpeLhWdYoTPbZerMjLHb4VQ++Q4\nndTid/Jfy+hdIh7zhI3vy3t/PZ7Ll4BSzuBCTQRsd5qxbx3uN+/BDROT1eHL1u6Q\nXJWe9vZ3QhbEQWmVeRaUQLNWVXgEQdq0YCrGMSx9Ok+jlL3ZgLxz8pBNOuf5IpZ2\nIoilzKxVKWjslNf4Q0jgQRyP+swM4MqPcw==\n-----END CERTIFICATE-----",
                identifier => '_mpjHABx9YV4XEaKYDtIqDlgKOE',
                issuer_dn => 'CN=ALPHA Root CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'pl0Khd6wlFBUII8kStVUkSQXyM8',
                loa => undef,
                notafter => '1170287999', # 2007-01-31T23:59:59
                notbefore => '1136073600', # 2006-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:f1:c5:59:d8:0e:0d:91:5d:46:21:44:7a:1f:e3:\n    77:b8:7c:f2:05:dc:2e:d1:4e:bd:f5:da:76:a5:53:\n    67:62:14:c4:28:70:9d:7e:89:88:dd:b1:c1:5a:44:\n    71:52:2a:4e:37:5c:6d:07:cd:5a:3c:a9:1f:d3:25:\n    3c:48:44:17:3d:19:c2:bc:72:8d:44:d2:f2:a9:36:\n    c7:e0:0e:af:4a:95:a0:f2:9d:cd:38:29:cc:d9:f1:\n    6c:b3:79:36:c0:48:28:c2:a9:ae:c3:d3:d8:8e:58:\n    40:07:0c:b8:2e:0c:46:9b:7f:d1:e3:5d:f0:5a:f6:\n    e4:b8:8f:56:46:32:64:9a:17:ec:1b:d6:6f:af:0f:\n    2e:72:8d:77:a4:50:60:ca:47:7e:e9:5b:35:17:1c:\n    2f:9c:75:d7:71:f4:d4:97:b2:76:7a:aa:82:a7:a2:\n    a1:68:de:d7:6c:16:4c:eb:c0:33:db:3f:a6:40:a2:\n    eb:92:60:39:e7:82:0c:c4:9f:f7:1c:fc:3e:31:c0:\n    27:27:1a:e0:ed:60:3a:88:43:cc:c9:c7:01:5a:68:\n    29:d0:76:96:e9:07:1a:fc:57:1d:45:e2:e6:e8:6f:\n    b9:e6:8d:36:db:57:33:66:a9:76:60:e7:2e:a5:0d:\n    e5:85:80:11:97:25:14:7d:9d:24:b4:9f:c5:f6:9e:\n    1c:d5\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA SCEP,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '82:D6:FA:7D:37:34:8C:11:F2:C6:0C:87:0F:95:34:2A:BF:14:C2:F9',
            },
            db_alias => {
                alias => 'alpha-scep-1',
                generation => '1',
                group_id => 'alpha-scep',
            },
        ),

        alpha_scep_2 => OpenXPKI::Test::CertHelper::Database::PEM->new(
            label => 'ALPHA SCEP',
            db => {
                authority_key_identifier => '22:4B:30:55:0D:D7:67:5E:63:1A:F8:74:80:9F:9E:9B:72:08:38:5E',
                cert_key => '10',
                data => "-----BEGIN CERTIFICATE-----\nMIIDdTCCAl2gAwIBAgIBCjANBgkqhkiG9w0BAQsFADBWMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nFjAUBgNVBAMMDUFMUEhBIFJvb3QgQ0EwIhgPMjAwNzAxMDEwMDAwMDBaGA8yMTA3\nMDEzMTIzNTk1OVowUzETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmSJomT8ixk\nARkWCE9wZW5YUEtJMQ0wCwYDVQQLDARBQ01FMRMwEQYDVQQDDApBTFBIQSBTQ0VQ\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1KKqSGc/Lak0atuy9TH2\n5ChaQQD7BQ/+uYMxY011JPnd4fZKkIfYYi8TbEAWGzrXzMBFrB4P1VgyFL7z5HKr\nnASXvixpuOVItLMG/Wp2ZZ4+mMJC7PMdY7b82sdmNS4y544bz/HirhU8IfGGYHJ7\nrwEtN3tgTgBcElM7LkDY9XB5VkA3ScXNhVk2rn4UDued2GQaL3Z12E9bIzevC8U7\njI3PGI40fBwFzyfQ7VdWKI2xB42ShnxZ57QQs1pA1dzETbjn4jG85BsqHtEzmm/N\n7l2EerAhN0MgfUul0wT0xnQg6KTvykl4uhJAVIPvPNnb3sloJxZFSZ1LToSbNe3B\nfQIDAQABo00wSzAJBgNVHRMEAjAAMB0GA1UdDgQWBBTYFe5oZCcZxvW5UGOet2cF\nGJnIXTAfBgNVHSMEGDAWgBQiSzBVDddnXmMa+HSAn56bcgg4XjANBgkqhkiG9w0B\nAQsFAAOCAQEApvWGas5ajR8JyLy+JSoCh4mrLWZTwSuXJ5Blp55qPO2R1sHszbMQ\nmSUMiVTv1gbanXGxsFBg7onf9rfz1MIZ/rmP6bNu8WvnqxF70S4VDeN1XjO6O1Xe\n2RPmW2MvoZCIGxr0HgdK3LwBwTcwN308racSgaC+XwtyrzfOmXDabfycOJHbg1Uk\nm45KQSEIvBgpQC38cYdiomrCbuhgIs9gbSjXH5jHSVCw3T1lytxWwW09CIx2BiRa\nJR+UlJKynO2I0RkczFdxjjwco6COWGvBavJPiPHKstqpUM6ZOGBVCh4SEcPRLOuG\nDYE4gpdLi/Ikw9QW5++Lwx1gHkyZQ9YxgA==\n-----END CERTIFICATE-----",
                identifier => 'MoVRbJVMrcPK0cOnUwl1aSH2uDA',
                issuer_dn => 'CN=ALPHA Root CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => '6e2c0jJNZ8Rr6i-5uEukByNsWPw',
                loa => undef,
                notafter => '4294967295', # 2106-02-07T06:28:15
                notbefore => '1167609600', # 2007-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:d4:a2:aa:48:67:3f:2d:a9:34:6a:db:b2:f5:31:\n    f6:e4:28:5a:41:00:fb:05:0f:fe:b9:83:31:63:4d:\n    75:24:f9:dd:e1:f6:4a:90:87:d8:62:2f:13:6c:40:\n    16:1b:3a:d7:cc:c0:45:ac:1e:0f:d5:58:32:14:be:\n    f3:e4:72:ab:9c:04:97:be:2c:69:b8:e5:48:b4:b3:\n    06:fd:6a:76:65:9e:3e:98:c2:42:ec:f3:1d:63:b6:\n    fc:da:c7:66:35:2e:32:e7:8e:1b:cf:f1:e2:ae:15:\n    3c:21:f1:86:60:72:7b:af:01:2d:37:7b:60:4e:00:\n    5c:12:53:3b:2e:40:d8:f5:70:79:56:40:37:49:c5:\n    cd:85:59:36:ae:7e:14:0e:e7:9d:d8:64:1a:2f:76:\n    75:d8:4f:5b:23:37:af:0b:c5:3b:8c:8d:cf:18:8e:\n    34:7c:1c:05:cf:27:d0:ed:57:56:28:8d:b1:07:8d:\n    92:86:7c:59:e7:b4:10:b3:5a:40:d5:dc:c4:4d:b8:\n    e7:e2:31:bc:e4:1b:2a:1e:d1:33:9a:6f:cd:ee:5d:\n    84:7a:b0:21:37:43:20:7d:4b:a5:d3:04:f4:c6:74:\n    20:e8:a4:ef:ca:49:78:ba:12:40:54:83:ef:3c:d9:\n    db:de:c9:68:27:16:45:49:9d:4b:4e:84:9b:35:ed:\n    c1:7d\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA SCEP,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => 'D8:15:EE:68:64:27:19:C6:F5:B9:50:63:9E:B7:67:05:18:99:C8:5D',
            },
            db_alias => {
                alias => 'alpha-scep-2',
                generation => '2',
                group_id => 'alpha-scep',
            },
        ),

        alpha_scep_3 => OpenXPKI::Test::CertHelper::Database::PEM->new(
            label => 'ALPHA SCEP',
            db => {
                authority_key_identifier => 'B3:87:BF:C1:9B:7B:02:0E:0B:9C:4A:9C:55:4E:A7:0A:55:90:09:DA',
                cert_key => '16',
                data => "-----BEGIN CERTIFICATE-----\nMIIDdTCCAl2gAwIBAgIBEDANBgkqhkiG9w0BAQsFADBWMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nFjAUBgNVBAMMDUFMUEhBIFJvb3QgQ0EwIhgPMjEwNzAxMDEwMDAwMDBaGA8yMTA4\nMDEzMTIzNTk1OVowUzETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmSJomT8ixk\nARkWCE9wZW5YUEtJMQ0wCwYDVQQLDARBQ01FMRMwEQYDVQQDDApBTFBIQSBTQ0VQ\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA05zW2zK1kGPv6AZYBGqB\nZhHjMvl6XtlTGyr09ZiyBtuZpX1+gFCbN4D8HadbwbevzHdUwWQ8nZNmL7lAwuzI\nSDchw55lJakWcFyFI+sV1Tj98Xd2tueYKh3X4YZg2MkGs/e+ZZInd2H54Wks+Lhk\no7pC04BjD5v8IlkGJzkoAziR5SGuHMitrU0YVc7lb00GPF3sSYCMg9Odt1DZzX7G\nOYVgZUqIDCi2Gg8Y/kulf7wq+8OBwgVs4dU9mkHp3PCqaidW9mxpQdxDVrmSkq3l\nlqp5fdwzBJ2iTBNoI+Yc06wucI8GzvD/vPr+2AX6T84r28SzmDEaBP5C9QJl81Bd\nMQIDAQABo00wSzAJBgNVHRMEAjAAMB0GA1UdDgQWBBTdV0kYJAUEJZXfRr8zhI1e\nsueSATAfBgNVHSMEGDAWgBSzh7/Bm3sCDgucSpxVTqcKVZAJ2jANBgkqhkiG9w0B\nAQsFAAOCAQEAJtu8fLTtJhfoVai10MsNK3Bxy515PGjdDqkJ+kcm2XQBJGtTJdiw\nL5C+g9LSw6hvSBjGRAZKScERD+97VerpQDR7vv2o+Qu0FFIw1RdVKWQNkWmDn6eg\nYXsNLYlTJM9be5Jg0s4OdksT3t1Ncgpnr9WH0iWLTl9Lpsl8Af58GNkLzCbT911l\nt58Zav+6KyKWRcdoJrIBSbcLURTOty3A39KV6LjLuYk3rwmeOPKoEllq8szpAjsI\nMqbsHnVKED92csSjBE3Vy9wPbuuM0p6ptIhcelNztQ1jFNMgMO2jQc2rkQq6AL3N\nikN+huRG0asvNJhjFb/V0IetaQ6BAaX70w==\n-----END CERTIFICATE-----",
                identifier => 'VA_4kHsKGhzRMi8bxXx4S9PugKM',
                issuer_dn => 'CN=ALPHA Root CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'RrisDnSwLAcjJJvQhufjoNPMJr8',
                loa => undef,
                notafter => '4294967295', # 2106-02-07T06:28:15
                notbefore => '4294967295', # 2106-02-07T06:28:15
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:d3:9c:d6:db:32:b5:90:63:ef:e8:06:58:04:6a:\n    81:66:11:e3:32:f9:7a:5e:d9:53:1b:2a:f4:f5:98:\n    b2:06:db:99:a5:7d:7e:80:50:9b:37:80:fc:1d:a7:\n    5b:c1:b7:af:cc:77:54:c1:64:3c:9d:93:66:2f:b9:\n    40:c2:ec:c8:48:37:21:c3:9e:65:25:a9:16:70:5c:\n    85:23:eb:15:d5:38:fd:f1:77:76:b6:e7:98:2a:1d:\n    d7:e1:86:60:d8:c9:06:b3:f7:be:65:92:27:77:61:\n    f9:e1:69:2c:f8:b8:64:a3:ba:42:d3:80:63:0f:9b:\n    fc:22:59:06:27:39:28:03:38:91:e5:21:ae:1c:c8:\n    ad:ad:4d:18:55:ce:e5:6f:4d:06:3c:5d:ec:49:80:\n    8c:83:d3:9d:b7:50:d9:cd:7e:c6:39:85:60:65:4a:\n    88:0c:28:b6:1a:0f:18:fe:4b:a5:7f:bc:2a:fb:c3:\n    81:c2:05:6c:e1:d5:3d:9a:41:e9:dc:f0:aa:6a:27:\n    56:f6:6c:69:41:dc:43:56:b9:92:92:ad:e5:96:aa:\n    79:7d:dc:33:04:9d:a2:4c:13:68:23:e6:1c:d3:ac:\n    2e:70:8f:06:ce:f0:ff:bc:fa:fe:d8:05:fa:4f:ce:\n    2b:db:c4:b3:98:31:1a:04:fe:42:f5:02:65:f3:50:\n    5d:31\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA SCEP,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => 'DD:57:49:18:24:05:04:25:95:DF:46:BF:33:84:8D:5E:B2:E7:92:01',
            },
            db_alias => {
                alias => 'alpha-scep-3',
                generation => '3',
                group_id => 'alpha-scep',
            },
        ),

        alpha_signer_1 => OpenXPKI::Test::CertHelper::Database::PEM->new(
            label => 'ALPHA Signing CA',
            db => {
                authority_key_identifier => 'E5:64:77:5A:87:EC:A6:6B:22:B3:B4:5C:25:EA:ED:2A:24:26:04:83',
                cert_key => '3',
                data => "-----BEGIN CERTIFICATE-----\nMIIDjjCCAnagAwIBAgIBAzANBgkqhkiG9w0BAQsFADBWMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nFjAUBgNVBAMMDUFMUEhBIFJvb3QgQ0EwIhgPMjAwNjAxMDEwMDAwMDBaGA8yMDA3\nMDEzMTIzNTk1OVowWTETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmSJomT8ixk\nARkWCE9wZW5YUEtJMQ0wCwYDVQQLDARBQ01FMRkwFwYDVQQDDBBBTFBIQSBTaWdu\naW5nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqgKzgdwg25nd\nZvJvNj955gTVW70/OkRjhp+aw0uXVyiyGzRkdjbxB8Jp59V55y27GzKVgelS8zrY\ngyrcsoh4S4yhhDBAPlwyKjObwtTsvfgFkjZjb9BU3uHQZXpz1JeCedzTP8waCQMX\nc8YagfwprQkRyfraOI3w+P22Nh36idKb/Kqa2oF4Js0EPKYBSJgUy8kuTF4LrNRZ\nUBRBPfMZ4pk4goakswOxiOBbGFRTOqbFKtJCNmNeXgOykiNGDAMMEQ4Bvb371ZPv\nTDbpUjR5pIq4tLBg8YjRy4Ranfv6957OTW81dOq5ZEOrVnklFifiQzmcZtuEGwxM\nj6g9tYEOeQIDAQABo2AwXjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTZx7LT\nYf/ENgrkwy0uZBpt5fjPjTAfBgNVHSMEGDAWgBTlZHdah+ymayKztFwl6u0qJCYE\ngzALBgNVHQ8EBAMCAQYwDQYJKoZIhvcNAQELBQADggEBADwtPtu7W8czbhRlX0lr\nYEb86G7aiv51Wg/iFY4wvXmyQgSQMqrpOQ+cq5LVQuqVI4wqg4/Th2N1+x3kQ8vZ\nnSi+1B/FJJcXmguYQoPNH+ufg9uXxE9LbBwHMuNnRZozHse8juSBllJ00RLMt+2J\ny69AuVUHadBSPmJQJe8AQD44Qd2mtwiIIGbl/XmtOdCwm2A8EfDfYGajMFVY+PhY\n6sUJxPUhsR9nfM9AkDEC+JBjpvrplJ51TghcWQ8mmdHaFvzo2hRJsCboK71RXDjR\n8Kegula55FrHSsjx84aw4lQj3XhQHPEbJMh5fNmccA9T08qFv0WAwUBH5KN11wwB\nGUs=\n-----END CERTIFICATE-----",
                identifier => 'KmALfiYiQq7fgh0sXYXtPI36k8g',
                issuer_dn => 'CN=ALPHA Root CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'pl0Khd6wlFBUII8kStVUkSQXyM8',
                loa => undef,
                notafter => '1170287999', # 2007-01-31T23:59:59
                notbefore => '1136073600', # 2006-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:aa:02:b3:81:dc:20:db:99:dd:66:f2:6f:36:3f:\n    79:e6:04:d5:5b:bd:3f:3a:44:63:86:9f:9a:c3:4b:\n    97:57:28:b2:1b:34:64:76:36:f1:07:c2:69:e7:d5:\n    79:e7:2d:bb:1b:32:95:81:e9:52:f3:3a:d8:83:2a:\n    dc:b2:88:78:4b:8c:a1:84:30:40:3e:5c:32:2a:33:\n    9b:c2:d4:ec:bd:f8:05:92:36:63:6f:d0:54:de:e1:\n    d0:65:7a:73:d4:97:82:79:dc:d3:3f:cc:1a:09:03:\n    17:73:c6:1a:81:fc:29:ad:09:11:c9:fa:da:38:8d:\n    f0:f8:fd:b6:36:1d:fa:89:d2:9b:fc:aa:9a:da:81:\n    78:26:cd:04:3c:a6:01:48:98:14:cb:c9:2e:4c:5e:\n    0b:ac:d4:59:50:14:41:3d:f3:19:e2:99:38:82:86:\n    a4:b3:03:b1:88:e0:5b:18:54:53:3a:a6:c5:2a:d2:\n    42:36:63:5e:5e:03:b2:92:23:46:0c:03:0c:11:0e:\n    01:bd:bd:fb:d5:93:ef:4c:36:e9:52:34:79:a4:8a:\n    b8:b4:b0:60:f1:88:d1:cb:84:5a:9d:fb:fa:f7:9e:\n    ce:4d:6f:35:74:ea:b9:64:43:ab:56:79:25:16:27:\n    e2:43:39:9c:66:db:84:1b:0c:4c:8f:a8:3d:b5:81:\n    0e:79\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA Signing CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => 'D9:C7:B2:D3:61:FF:C4:36:0A:E4:C3:2D:2E:64:1A:6D:E5:F8:CF:8D',
            },
            db_alias => {
                alias => 'alpha-signer-1',
                generation => '1',
                group_id => 'alpha-signer',
            },
        ),

        alpha_signer_2 => OpenXPKI::Test::CertHelper::Database::PEM->new(
            label => 'ALPHA Signing CA',
            db => {
                authority_key_identifier => '22:4B:30:55:0D:D7:67:5E:63:1A:F8:74:80:9F:9E:9B:72:08:38:5E',
                cert_key => '9',
                data => "-----BEGIN CERTIFICATE-----\nMIIDjjCCAnagAwIBAgIBCTANBgkqhkiG9w0BAQsFADBWMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nFjAUBgNVBAMMDUFMUEhBIFJvb3QgQ0EwIhgPMjAwNzAxMDEwMDAwMDBaGA8yMTA3\nMDEzMTIzNTk1OVowWTETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmSJomT8ixk\nARkWCE9wZW5YUEtJMQ0wCwYDVQQLDARBQ01FMRkwFwYDVQQDDBBBTFBIQSBTaWdu\naW5nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA3yXFbi/x0uvV\n5WcY7G5rthauS+injZKN2FFakcXDCFMBu3cC2uYnp4Us5UroLSlv0ZqnfKx9UvTB\nh6awOalbEs8tqW9bETvmbAR2DsCaDusp/vDNJcoLl87A2WRfk0SFuXDo3olnr0GL\nkOhZiSFa0lfasSIY/rkGJjqEJVS2olFkY17hEFtMqmMJ/5H+GOuE5Ym8b7BSEMb2\n0maFPUb8eZAqcBan91V60wzA2/3q3/Me5Nw0cAWkXfuChWF2bt+9V12SzlMVh2G3\n1MngxTSyHzF1u+0PDoZPGI63BuBZ0ZRmIApGEcDvs3JvSw+bHjHiJ2BDqjOQRmKa\n0PE1io1xjQIDAQABo2AwXjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBS3+YBM\nZFP44gqD6YDHgaLpApzMpTAfBgNVHSMEGDAWgBQiSzBVDddnXmMa+HSAn56bcgg4\nXjALBgNVHQ8EBAMCAQYwDQYJKoZIhvcNAQELBQADggEBAFuhKhR6T66stwIxrVvo\nNmrjVsrV45hAyWcDAOkrhRDpzeDkK+SwsiCyGRXy06oDIw9SJDmpdnKDGuGa0uOz\nUsjVRVIlI0TWLN6MsU8UaSd/Umbf6fHpvgYgw7mOUh3q/uE9+K4M3Hv7xSUvRD4U\nwRSrDOmqzyJfVZFTZdJRdrkt9lZTdZm2iT/HQfOA5hNa0/LP4F3KwM6NZ18Z+5Hh\nzGakLMvRikgYvuC20zEkXD7hYZg1f8djCMhdPcxnTvflpJ6uJ+PI4poNL1zZCexw\nm0faoNDBgqEroCej1Z507bGkueKSv5i4wxRKzSdZZZUTDnhvC3pjk5elR9y0g/LG\nwS0=\n-----END CERTIFICATE-----",
                identifier => 'd7RhCpUYe88uAVAmKHXBfeEFi0c',
                issuer_dn => 'CN=ALPHA Root CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => '6e2c0jJNZ8Rr6i-5uEukByNsWPw',
                loa => undef,
                notafter => '4294967295', # 2106-02-07T06:28:15
                notbefore => '1167609600', # 2007-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:df:25:c5:6e:2f:f1:d2:eb:d5:e5:67:18:ec:6e:\n    6b:b6:16:ae:4b:e8:a7:8d:92:8d:d8:51:5a:91:c5:\n    c3:08:53:01:bb:77:02:da:e6:27:a7:85:2c:e5:4a:\n    e8:2d:29:6f:d1:9a:a7:7c:ac:7d:52:f4:c1:87:a6:\n    b0:39:a9:5b:12:cf:2d:a9:6f:5b:11:3b:e6:6c:04:\n    76:0e:c0:9a:0e:eb:29:fe:f0:cd:25:ca:0b:97:ce:\n    c0:d9:64:5f:93:44:85:b9:70:e8:de:89:67:af:41:\n    8b:90:e8:59:89:21:5a:d2:57:da:b1:22:18:fe:b9:\n    06:26:3a:84:25:54:b6:a2:51:64:63:5e:e1:10:5b:\n    4c:aa:63:09:ff:91:fe:18:eb:84:e5:89:bc:6f:b0:\n    52:10:c6:f6:d2:66:85:3d:46:fc:79:90:2a:70:16:\n    a7:f7:55:7a:d3:0c:c0:db:fd:ea:df:f3:1e:e4:dc:\n    34:70:05:a4:5d:fb:82:85:61:76:6e:df:bd:57:5d:\n    92:ce:53:15:87:61:b7:d4:c9:e0:c5:34:b2:1f:31:\n    75:bb:ed:0f:0e:86:4f:18:8e:b7:06:e0:59:d1:94:\n    66:20:0a:46:11:c0:ef:b3:72:6f:4b:0f:9b:1e:31:\n    e2:27:60:43:aa:33:90:46:62:9a:d0:f1:35:8a:8d:\n    71:8d\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA Signing CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => 'B7:F9:80:4C:64:53:F8:E2:0A:83:E9:80:C7:81:A2:E9:02:9C:CC:A5',
            },
            db_alias => {
                alias => 'alpha-signer-2',
                generation => '2',
                group_id => 'alpha-signer',
            },
        ),

        alpha_signer_3 => OpenXPKI::Test::CertHelper::Database::PEM->new(
            label => 'ALPHA Signing CA',
            db => {
                authority_key_identifier => 'B3:87:BF:C1:9B:7B:02:0E:0B:9C:4A:9C:55:4E:A7:0A:55:90:09:DA',
                cert_key => '15',
                data => "-----BEGIN CERTIFICATE-----\nMIIDjjCCAnagAwIBAgIBDzANBgkqhkiG9w0BAQsFADBWMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nFjAUBgNVBAMMDUFMUEhBIFJvb3QgQ0EwIhgPMjEwNzAxMDEwMDAwMDBaGA8yMTA4\nMDEzMTIzNTk1OVowWTETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmSJomT8ixk\nARkWCE9wZW5YUEtJMQ0wCwYDVQQLDARBQ01FMRkwFwYDVQQDDBBBTFBIQSBTaWdu\naW5nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAslEa/dwvlIfR\nLN2pWu3Y/0ebpTjeIl+xd+k5jxq5/OcLHhpXeVpycQqWAonF28ndpJZaMxsncO9I\nCGarjIexDUONvKmJxOOCBo4F1pJpPM6RBc0j1IZbaMsP4F8NxBiMA4wDEUTRt6os\nz8q4V9wKtlOr9T7UFTUAba0y4zJSKPuevQ8XcpfnYyaK4k4UdpChD9v9CwRsyq1y\nB7SRfIseuTJBTbX8uKC+qR9akHpVzzee9D5g1Oito4GMfGq+SJ0PR59m1q7e5/Qh\niQuJkSHlBQV4aNs0VZzwk7ZRJdiuvobY0xr51J/GyrqpmbdXWLzDRAEOFm5lnW8M\n/vm+NgDkmwIDAQABo2AwXjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBQ/rl+x\netFmOZwVEXrkm/2xfwVkyTAfBgNVHSMEGDAWgBSzh7/Bm3sCDgucSpxVTqcKVZAJ\n2jALBgNVHQ8EBAMCAQYwDQYJKoZIhvcNAQELBQADggEBAGJR6Pg1HmRlVi5EprTp\nlgUbQswkAKvNWteuWpkGAejy9SH/AvkJLMt7/3dfB+nVm8jKxbdLN403oLWFT8Jg\nrf3ikswmlTE1WpDgGXu3dDBcneW+HRN9xCnm1UovcXKoYfXpj4LldsnEVwpi42JJ\nJkuQZJ1LXhIIv4nOCMgYpL1G06blpoejE8LHpD99OfD6r9EEzhwPiH/9X4qxocKw\n2NBSvYu1d+dsIp2Z+g5PwkHgDSEKggjwvTFZrzpjOsYDcYdnIBxmt0o/PPQd0uLt\n8uEMMVfqnLKqAhqS/X5qCeWLinQq1YqUoNe06rH0xo2SSMB3pBB1OPENhLEbAS7D\n4/U=\n-----END CERTIFICATE-----",
                identifier => 'QYQa-QZFkgiaVvSShYRjd9alxNU',
                issuer_dn => 'CN=ALPHA Root CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'RrisDnSwLAcjJJvQhufjoNPMJr8',
                loa => undef,
                notafter => '4294967295', # 2106-02-07T06:28:15
                notbefore => '4294967295', # 2106-02-07T06:28:15
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:b2:51:1a:fd:dc:2f:94:87:d1:2c:dd:a9:5a:ed:\n    d8:ff:47:9b:a5:38:de:22:5f:b1:77:e9:39:8f:1a:\n    b9:fc:e7:0b:1e:1a:57:79:5a:72:71:0a:96:02:89:\n    c5:db:c9:dd:a4:96:5a:33:1b:27:70:ef:48:08:66:\n    ab:8c:87:b1:0d:43:8d:bc:a9:89:c4:e3:82:06:8e:\n    05:d6:92:69:3c:ce:91:05:cd:23:d4:86:5b:68:cb:\n    0f:e0:5f:0d:c4:18:8c:03:8c:03:11:44:d1:b7:aa:\n    2c:cf:ca:b8:57:dc:0a:b6:53:ab:f5:3e:d4:15:35:\n    00:6d:ad:32:e3:32:52:28:fb:9e:bd:0f:17:72:97:\n    e7:63:26:8a:e2:4e:14:76:90:a1:0f:db:fd:0b:04:\n    6c:ca:ad:72:07:b4:91:7c:8b:1e:b9:32:41:4d:b5:\n    fc:b8:a0:be:a9:1f:5a:90:7a:55:cf:37:9e:f4:3e:\n    60:d4:e8:ad:a3:81:8c:7c:6a:be:48:9d:0f:47:9f:\n    66:d6:ae:de:e7:f4:21:89:0b:89:91:21:e5:05:05:\n    78:68:db:34:55:9c:f0:93:b6:51:25:d8:ae:be:86:\n    d8:d3:1a:f9:d4:9f:c6:ca:ba:a9:99:b7:57:58:bc:\n    c3:44:01:0e:16:6e:65:9d:6f:0c:fe:f9:be:36:00:\n    e4:9b\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA Signing CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '3F:AE:5F:B1:7A:D1:66:39:9C:15:11:7A:E4:9B:FD:B1:7F:05:64:C9',
            },
            db_alias => {
                alias => 'alpha-signer-3',
                generation => '3',
                group_id => 'alpha-signer',
            },
        ),

        alpha_vault_1 => OpenXPKI::Test::CertHelper::Database::PEM->new(
            label => 'ALPHA DataVault',
            db => {
                authority_key_identifier => '6E:96:E7:B5:5B:58:98:27:FC:66:0A:C6:36:8B:B4:A7:E5:F7:9E:5C',
                cert_key => '1',
                data => "-----BEGIN CERTIFICATE-----\nMIIDnjCCAoagAwIBAgIBATANBgkqhkiG9w0BAQsFADBYMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGDAWBgNVBAMMD0FMUEhBIERhdGFWYXVsdDAiGA8yMDA2MDEwMTAwMDAwMFoYDzIw\nMDcwMTMxMjM1OTU5WjBYMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZImiZPy\nLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxGDAWBgNVBAMMD0FMUEhBIERh\ndGFWYXVsdDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAL3w9SUOm4M/\n28PZ95sG5uitmlRQ3B/yzLDzMlo14NanR7HRl3GOFc2uIRw+6Mlf/kx7fsu26LKQ\nLPAeUJgYa3bWT/SYd8Fp5fUVOqYR8AhfX4MEeMRLYvkt6l5quDIm8JLlx+fCIvIY\nAjrq7p6a8WQcsDUuFqy+DCW1BZu1RobcIEXoeXyuyHNVEHUJP9iKrBrXvVDsI6GX\nRd5+hTGju1E0eiBapqsQGS82UhT6bAMldi+xwGyX1+F/uoc69//78X+REuKqgmkm\n00PAs9/JdWADfGGNnfxyBvaGBsa4ljMwgK1Wnc5kxbbI7Blpnyu500ka+7GAm5qk\ne71hpOT0Y4kCAwEAAaNvMG0wCQYDVR0TBAIwADAdBgNVHQ4EFgQUbpbntVtYmCf8\nZgrGNou0p+X3nlwwHwYDVR0jBBgwFoAUbpbntVtYmCf8ZgrGNou0p+X3nlwwCwYD\nVR0PBAQDAgUgMBMGA1UdJQQMMAoGCCsGAQUFBwMEMA0GCSqGSIb3DQEBCwUAA4IB\nAQBS4nE4zqX7AWcgYmnzchVrdTnh1bXcMHuucFZD/fcsS6QbacglqTHp964cEzhm\nUocMfQ87dyl//DUhU4CqPU2g2Pg9zW7fMwcl7T0IlpNgafEAilQhoqqns2hasjzc\n5Cg6kph96IAyrycrm11wtz9Mdyq37rCKgn3NiYEvtkj/ByYxTbuFa69UTsvYH024\nu9+VxPLZw8UWhQDiss6QGbdnN59ypJiSEeN60upam1QHWh19MU+Zus+oQe/0i1OC\nJEQpcYsU/KgrJj/GfzHpW/o6/Yo+azJEaQs7S5glPiUom9WKcwl+UmVqER3hNpsm\nN+2rRuT4WggKoiq3TEs6VX3u\n-----END CERTIFICATE-----",
                identifier => 'RaiG3Xv9qJrWRUsUw8hI98Kozmo',
                issuer_dn => 'CN=ALPHA DataVault,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'RaiG3Xv9qJrWRUsUw8hI98Kozmo',
                loa => undef,
                notafter => '1170287999', # 2007-01-31T23:59:59
                notbefore => '1136073600', # 2006-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:bd:f0:f5:25:0e:9b:83:3f:db:c3:d9:f7:9b:06:\n    e6:e8:ad:9a:54:50:dc:1f:f2:cc:b0:f3:32:5a:35:\n    e0:d6:a7:47:b1:d1:97:71:8e:15:cd:ae:21:1c:3e:\n    e8:c9:5f:fe:4c:7b:7e:cb:b6:e8:b2:90:2c:f0:1e:\n    50:98:18:6b:76:d6:4f:f4:98:77:c1:69:e5:f5:15:\n    3a:a6:11:f0:08:5f:5f:83:04:78:c4:4b:62:f9:2d:\n    ea:5e:6a:b8:32:26:f0:92:e5:c7:e7:c2:22:f2:18:\n    02:3a:ea:ee:9e:9a:f1:64:1c:b0:35:2e:16:ac:be:\n    0c:25:b5:05:9b:b5:46:86:dc:20:45:e8:79:7c:ae:\n    c8:73:55:10:75:09:3f:d8:8a:ac:1a:d7:bd:50:ec:\n    23:a1:97:45:de:7e:85:31:a3:bb:51:34:7a:20:5a:\n    a6:ab:10:19:2f:36:52:14:fa:6c:03:25:76:2f:b1:\n    c0:6c:97:d7:e1:7f:ba:87:3a:f7:ff:fb:f1:7f:91:\n    12:e2:aa:82:69:26:d3:43:c0:b3:df:c9:75:60:03:\n    7c:61:8d:9d:fc:72:06:f6:86:06:c6:b8:96:33:30:\n    80:ad:56:9d:ce:64:c5:b6:c8:ec:19:69:9f:2b:b9:\n    d3:49:1a:fb:b1:80:9b:9a:a4:7b:bd:61:a4:e4:f4:\n    63:89\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA DataVault,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '6E:96:E7:B5:5B:58:98:27:FC:66:0A:C6:36:8B:B4:A7:E5:F7:9E:5C',
            },
            db_alias => {
                alias => 'alpha-vault-1',
                generation => '1',
                group_id => 'alpha-vault',
            },
        ),

        alpha_vault_2 => OpenXPKI::Test::CertHelper::Database::PEM->new(
            label => 'ALPHA DataVault',
            db => {
                authority_key_identifier => '29:FD:3B:59:0E:84:3B:52:D8:78:3C:CA:E1:46:7C:1B:CF:8A:6C:47',
                cert_key => '7',
                data => "-----BEGIN CERTIFICATE-----\nMIIDnjCCAoagAwIBAgIBBzANBgkqhkiG9w0BAQsFADBYMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGDAWBgNVBAMMD0FMUEhBIERhdGFWYXVsdDAiGA8yMDA3MDEwMTAwMDAwMFoYDzIx\nMDcwMTMxMjM1OTU5WjBYMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZImiZPy\nLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxGDAWBgNVBAMMD0FMUEhBIERh\ndGFWYXVsdDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMg0+y6CG9y+\ny1R6bOMy/Er9OMz2p9AdGyN8/H0TAPUa2726pOsy1pJxGPtaDMyLa7Zn/qZag+1c\nJG/mQXvFnGqSMF6cZz4LGyHDmwhRrzkKK7xjzHyS+r4f4uW7Dq/tnz7wovHMAswo\nLCJiUkZlWBo5xSoRSc6TZ6dlYL8QyyJhi85lOCzI6gqpUkDDLno27lhv3SKC+PZG\nheEtmsYhTdRx7+RffsVhny+pVFcWHrIFtwrLZ8LVAVHaMC0XKCJCpm6KxMxOpqWY\nDiFCZxgS9qSB31gRyCJy8ROxpExw6CEaFKyYkAUDju/y7yG7pMpGux3QoesfHydc\nlJzdAq63tzsCAwEAAaNvMG0wCQYDVR0TBAIwADAdBgNVHQ4EFgQUKf07WQ6EO1LY\neDzK4UZ8G8+KbEcwHwYDVR0jBBgwFoAUKf07WQ6EO1LYeDzK4UZ8G8+KbEcwCwYD\nVR0PBAQDAgUgMBMGA1UdJQQMMAoGCCsGAQUFBwMEMA0GCSqGSIb3DQEBCwUAA4IB\nAQAuYcad0CR7oR/UgjShM2/INevSRPNV22Mha+/59QF+ACiobcrMEOQFaYsmGr8n\nzSLi1EqU4c0vl2I3NwPS/fPmUIS+y415rXVPayl/qzeyDkUIjeBHl34OImldBeHq\nGxQGh/HKLBEVk6dkuM65CzZV0M8vi6aSVmwNyHc3BGE6IqBq8V13OyvNRuvPE6Sk\nHXZtQD8C9Knng7p6g5p5gPkEuDW/llHdYxYx9VxIT8ATm0kOJ1Emy/dioi4b02vB\nfG1PAJDYmtT8lOM8AR5u+hmysjUAewNJE6P5D4ZAJ1UepHGA5Jqoe8mv2M9wX2eV\n7MoMB/1BtXBq9HofffN5yq6V\n-----END CERTIFICATE-----",
                identifier => '-90nzmWcaFlQ1dB6yDQAnP5erWQ',
                issuer_dn => 'CN=ALPHA DataVault,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => '-90nzmWcaFlQ1dB6yDQAnP5erWQ',
                loa => undef,
                notafter => '4294967295', # 2106-02-07T06:28:15
                notbefore => '1167609600', # 2007-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:c8:34:fb:2e:82:1b:dc:be:cb:54:7a:6c:e3:32:\n    fc:4a:fd:38:cc:f6:a7:d0:1d:1b:23:7c:fc:7d:13:\n    00:f5:1a:db:bd:ba:a4:eb:32:d6:92:71:18:fb:5a:\n    0c:cc:8b:6b:b6:67:fe:a6:5a:83:ed:5c:24:6f:e6:\n    41:7b:c5:9c:6a:92:30:5e:9c:67:3e:0b:1b:21:c3:\n    9b:08:51:af:39:0a:2b:bc:63:cc:7c:92:fa:be:1f:\n    e2:e5:bb:0e:af:ed:9f:3e:f0:a2:f1:cc:02:cc:28:\n    2c:22:62:52:46:65:58:1a:39:c5:2a:11:49:ce:93:\n    67:a7:65:60:bf:10:cb:22:61:8b:ce:65:38:2c:c8:\n    ea:0a:a9:52:40:c3:2e:7a:36:ee:58:6f:dd:22:82:\n    f8:f6:46:85:e1:2d:9a:c6:21:4d:d4:71:ef:e4:5f:\n    7e:c5:61:9f:2f:a9:54:57:16:1e:b2:05:b7:0a:cb:\n    67:c2:d5:01:51:da:30:2d:17:28:22:42:a6:6e:8a:\n    c4:cc:4e:a6:a5:98:0e:21:42:67:18:12:f6:a4:81:\n    df:58:11:c8:22:72:f1:13:b1:a4:4c:70:e8:21:1a:\n    14:ac:98:90:05:03:8e:ef:f2:ef:21:bb:a4:ca:46:\n    bb:1d:d0:a1:eb:1f:1f:27:5c:94:9c:dd:02:ae:b7:\n    b7:3b\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA DataVault,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '29:FD:3B:59:0E:84:3B:52:D8:78:3C:CA:E1:46:7C:1B:CF:8A:6C:47',
            },
            db_alias => {
                alias => 'alpha-vault-2',
                generation => '2',
                group_id => 'alpha-vault',
            },
        ),

        alpha_vault_3 => OpenXPKI::Test::CertHelper::Database::PEM->new(
            label => 'ALPHA DataVault',
            db => {
                authority_key_identifier => 'CC:44:17:79:22:92:37:9A:B3:98:06:31:98:01:3A:7B:EF:A7:E1:59',
                cert_key => '13',
                data => "-----BEGIN CERTIFICATE-----\nMIIDnjCCAoagAwIBAgIBDTANBgkqhkiG9w0BAQsFADBYMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGDAWBgNVBAMMD0FMUEhBIERhdGFWYXVsdDAiGA8yMTA3MDEwMTAwMDAwMFoYDzIx\nMDgwMTMxMjM1OTU5WjBYMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZImiZPy\nLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxGDAWBgNVBAMMD0FMUEhBIERh\ndGFWYXVsdDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALqtnSsyiboC\no3lRwyVla5yZj+FC1xTFBHKWPFKLO7iUny3drB11XlRysZgfyQPYv0c6p8jIpM3o\nkgtUPErCixyL8NoZLe8cDfIftWsnvVhIm8gH4znaTS7E7AgI7FfVMRc3tiBSR/pW\nYSYPvBzzAzTOWQyILSCYUHrvFv500NUPznFjp6/YY+pDvs8xI+qHXe8A+SKlQY9W\nBJh8fz1NcsbulkIazz8P94XdTrqtH6/fz1dSOcIw4N7qQy7FJWOJfrHx8t1z9KAp\nAJWQ/5JcZnBcdoqq4XaO0dBOJqbKCOYVyPf95GN+LwiaCyRxwurMSnANOGJbwYcN\n0Ntn3S6Sm0MCAwEAAaNvMG0wCQYDVR0TBAIwADAdBgNVHQ4EFgQUzEQXeSKSN5qz\nmAYxmAE6e++n4VkwHwYDVR0jBBgwFoAUzEQXeSKSN5qzmAYxmAE6e++n4VkwCwYD\nVR0PBAQDAgUgMBMGA1UdJQQMMAoGCCsGAQUFBwMEMA0GCSqGSIb3DQEBCwUAA4IB\nAQAFQ6APMDreA2DQPwCNJGIzRVtWl0+xiXmN81EyNjCrHZXiY4s2AQopfOapFtvE\nErico+k9rEl0VE9jGApKZadjBT7EcnLJnSp/E0PewS19NEwt7bhBgewZOaM4ZPTE\nO1Km+9rwSi4bEU1LLody7axABOnOrUGiEOBygL9WD+YoJSEGI2JdleiqkD+XjJNV\nIB8k7+EazxlPEZ96+pAAYdRYkiL4TP6p7mQlvki/OSv0ODfHdITPkPPYdYD2q+z1\n2SIVXdmpQ+jKTZSigwTXQaer9D1KpI0/hwZRCN9tbHNl0ZGxi9Mlp2FAsUyVh64i\nnQIN7Qlxeh2jklEPMoctfJG4\n-----END CERTIFICATE-----",
                identifier => '2x-roetsmd8hKm3wRDATea26htM',
                issuer_dn => 'CN=ALPHA DataVault,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => '2x-roetsmd8hKm3wRDATea26htM',
                loa => undef,
                notafter => '4294967295', # 2106-02-07T06:28:15
                notbefore => '4294967295', # 2106-02-07T06:28:15
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:ba:ad:9d:2b:32:89:ba:02:a3:79:51:c3:25:65:\n    6b:9c:99:8f:e1:42:d7:14:c5:04:72:96:3c:52:8b:\n    3b:b8:94:9f:2d:dd:ac:1d:75:5e:54:72:b1:98:1f:\n    c9:03:d8:bf:47:3a:a7:c8:c8:a4:cd:e8:92:0b:54:\n    3c:4a:c2:8b:1c:8b:f0:da:19:2d:ef:1c:0d:f2:1f:\n    b5:6b:27:bd:58:48:9b:c8:07:e3:39:da:4d:2e:c4:\n    ec:08:08:ec:57:d5:31:17:37:b6:20:52:47:fa:56:\n    61:26:0f:bc:1c:f3:03:34:ce:59:0c:88:2d:20:98:\n    50:7a:ef:16:fe:74:d0:d5:0f:ce:71:63:a7:af:d8:\n    63:ea:43:be:cf:31:23:ea:87:5d:ef:00:f9:22:a5:\n    41:8f:56:04:98:7c:7f:3d:4d:72:c6:ee:96:42:1a:\n    cf:3f:0f:f7:85:dd:4e:ba:ad:1f:af:df:cf:57:52:\n    39:c2:30:e0:de:ea:43:2e:c5:25:63:89:7e:b1:f1:\n    f2:dd:73:f4:a0:29:00:95:90:ff:92:5c:66:70:5c:\n    76:8a:aa:e1:76:8e:d1:d0:4e:26:a6:ca:08:e6:15:\n    c8:f7:fd:e4:63:7e:2f:08:9a:0b:24:71:c2:ea:cc:\n    4a:70:0d:38:62:5b:c1:87:0d:d0:db:67:dd:2e:92:\n    9b:43\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA DataVault,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => 'CC:44:17:79:22:92:37:9A:B3:98:06:31:98:01:3A:7B:EF:A7:E1:59',
            },
            db_alias => {
                alias => 'alpha-vault-3',
                generation => '3',
                group_id => 'alpha-vault',
            },
        ),

        alpha_root_1 => OpenXPKI::Test::CertHelper::Database::PEM->new(
            label => 'ALPHA Root CA',
            db => {
                authority_key_identifier => 'E5:64:77:5A:87:EC:A6:6B:22:B3:B4:5C:25:EA:ED:2A:24:26:04:83',
                cert_key => '2',
                data => "-----BEGIN CERTIFICATE-----\nMIIDizCCAnOgAwIBAgIBAjANBgkqhkiG9w0BAQsFADBWMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nFjAUBgNVBAMMDUFMUEhBIFJvb3QgQ0EwIhgPMjAwNjAxMDEwMDAwMDBaGA8yMDA3\nMDEzMTIzNTk1OVowVjETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmSJomT8ixk\nARkWCE9wZW5YUEtJMQ0wCwYDVQQLDARBQ01FMRYwFAYDVQQDDA1BTFBIQSBSb290\nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4QQu9qGDTOek5Rz1\nTVBiGlw5fJiuZ+3GG5CW4TEF7r8miR18NeTUE84HKyghPNioVsTiYxc4BxWu29w/\noYr7W6kSL7y5I6NvV++EHmYT0QP3AO55nH4lAe885gaJiLJjBLou7ac14HnHmGmF\n2BJAyMo059RwdKZntKuk6cQj4G1WmcptU2qzE3gefqehgyi6Y8tyuEOENEoRob2J\nsuGFLBcnWxcoWLcQiQPsrZGPYLSKVNVtpPfOS+PBrDKuStoa2P55nxz/wZ4eSnlt\ns7/KkmZNDlUut7tw1HBNIq8c4WiFMAYKqhZKA6Vg0+4Xvr5GO85V8HlIES+xHYRj\ngzm4JwIDAQABo2AwXjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTlZHdah+ym\nayKztFwl6u0qJCYEgzAfBgNVHSMEGDAWgBTlZHdah+ymayKztFwl6u0qJCYEgzAL\nBgNVHQ8EBAMCAQYwDQYJKoZIhvcNAQELBQADggEBAGqtmEbKFoQtoN2uMeWeIRfD\nYud3leuo5G79xPBLl2HUQciqUYutTVk3sDw75UOeTuHVnnc3NV+mSXS0f8Jz/jyA\nfZxeWh45oM7XEZfasIvLGnKOeqExYN9UcyHbG6E1jmf1d91fYGL5MLNzNZuLgvXG\ndfOM55fSND9hcNmLjKjXAxRq55qmS+RVr/j8Abv/si+mCF7W9JX4gVJfRWxdqzyM\nvrEjWAFiyA/plIokfdUXDsQ0oYJtJfzE86Ged3MHl68OfXG4FZsFKJgnc3i2cjkh\nGF6zjOQ2GOxkXf2z1Az6EQXnGU1nPjnqBB/NrqXmwtChOb/nU71IcCNEJ29lEsU=\n-----END CERTIFICATE-----",
                identifier => 'pl0Khd6wlFBUII8kStVUkSQXyM8',
                issuer_dn => 'CN=ALPHA Root CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'pl0Khd6wlFBUII8kStVUkSQXyM8',
                loa => undef,
                notafter => '1170287999', # 2007-01-31T23:59:59
                notbefore => '1136073600', # 2006-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:e1:04:2e:f6:a1:83:4c:e7:a4:e5:1c:f5:4d:50:\n    62:1a:5c:39:7c:98:ae:67:ed:c6:1b:90:96:e1:31:\n    05:ee:bf:26:89:1d:7c:35:e4:d4:13:ce:07:2b:28:\n    21:3c:d8:a8:56:c4:e2:63:17:38:07:15:ae:db:dc:\n    3f:a1:8a:fb:5b:a9:12:2f:bc:b9:23:a3:6f:57:ef:\n    84:1e:66:13:d1:03:f7:00:ee:79:9c:7e:25:01:ef:\n    3c:e6:06:89:88:b2:63:04:ba:2e:ed:a7:35:e0:79:\n    c7:98:69:85:d8:12:40:c8:ca:34:e7:d4:70:74:a6:\n    67:b4:ab:a4:e9:c4:23:e0:6d:56:99:ca:6d:53:6a:\n    b3:13:78:1e:7e:a7:a1:83:28:ba:63:cb:72:b8:43:\n    84:34:4a:11:a1:bd:89:b2:e1:85:2c:17:27:5b:17:\n    28:58:b7:10:89:03:ec:ad:91:8f:60:b4:8a:54:d5:\n    6d:a4:f7:ce:4b:e3:c1:ac:32:ae:4a:da:1a:d8:fe:\n    79:9f:1c:ff:c1:9e:1e:4a:79:6d:b3:bf:ca:92:66:\n    4d:0e:55:2e:b7:bb:70:d4:70:4d:22:af:1c:e1:68:\n    85:30:06:0a:aa:16:4a:03:a5:60:d3:ee:17:be:be:\n    46:3b:ce:55:f0:79:48:11:2f:b1:1d:84:63:83:39:\n    b8:27\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA Root CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => 'E5:64:77:5A:87:EC:A6:6B:22:B3:B4:5C:25:EA:ED:2A:24:26:04:83',
            },
            db_alias => {
                alias => 'root-1',
                generation => '1',
                group_id => 'root',
            },
        ),

        alpha_root_2 => OpenXPKI::Test::CertHelper::Database::PEM->new(
            label => 'ALPHA Root CA',
            db => {
                authority_key_identifier => '22:4B:30:55:0D:D7:67:5E:63:1A:F8:74:80:9F:9E:9B:72:08:38:5E',
                cert_key => '8',
                data => "-----BEGIN CERTIFICATE-----\nMIIDizCCAnOgAwIBAgIBCDANBgkqhkiG9w0BAQsFADBWMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nFjAUBgNVBAMMDUFMUEhBIFJvb3QgQ0EwIhgPMjAwNzAxMDEwMDAwMDBaGA8yMTA3\nMDEzMTIzNTk1OVowVjETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmSJomT8ixk\nARkWCE9wZW5YUEtJMQ0wCwYDVQQLDARBQ01FMRYwFAYDVQQDDA1BTFBIQSBSb290\nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1wER8VD1HaeaXx7C\nMGhknu6Wlsm7k3Uk4UEJDekVULNwyShcZFJF0r2HICGomnlsLc44yJwY9Tv9g+Hq\nw6/W65GtPbaJWaxwr2o5h4YbLZNLrkfGArT9jrqXNjAW2LPeg3nuDg2Ty48sbKvk\ncNtXQ35UQ4q80mp5yi/GxXFGRp2O/S2GblMi4hUynnmLfV7+ydVIAIRmN4zQs/6p\nipI3pnbb4pWqB/AdGq+Yg9Ku5/HSFaN7s0j5w0QjAYnt8BIVFrQegYM6cBH/v2K3\njp1aET08X0k1XO/PNjZqZrQo7dLjY7vPlnN3Xhf4qkh3GpWbDkYnela44XVbF1GS\nZ5nhHwIDAQABo2AwXjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBQiSzBVDddn\nXmMa+HSAn56bcgg4XjAfBgNVHSMEGDAWgBQiSzBVDddnXmMa+HSAn56bcgg4XjAL\nBgNVHQ8EBAMCAQYwDQYJKoZIhvcNAQELBQADggEBAEpJ3DPGXVN4hukrQGbG6uA7\ndODUmWFpiByn12BlxUwCwEALFJns313P275N8q0wmLV+9Aoj0Gf/fQCfDmBzAeT7\nXfzkUjLFPL/SCQxt7sHZSdyvWPC9gdXp+PnBNxA8xYiFheVKwJC4poskYIie0yWP\nSnAgvLEXAtckqy5KtMGwIqni9VAx+yRqECDZJH5TIxpstlfUhmIjOHCT0McKuCr9\nGEziN1ErkJNWMKCBEpmxkhR+B6aMpn2/7Eo+LYLZdleYgrMGSuG4DYz0tVIcBd+s\nkRTBfTFRT2sfJYHE9aLN/NPdOEvSr4Ah4IM//q5ZM2AudpNaSFWGo7YZGfbCCuQ=\n-----END CERTIFICATE-----",
                identifier => '6e2c0jJNZ8Rr6i-5uEukByNsWPw',
                issuer_dn => 'CN=ALPHA Root CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => '6e2c0jJNZ8Rr6i-5uEukByNsWPw',
                loa => undef,
                notafter => '4294967295', # 2106-02-07T06:28:15
                notbefore => '1167609600', # 2007-01-01T00:00:00
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:d7:01:11:f1:50:f5:1d:a7:9a:5f:1e:c2:30:68:\n    64:9e:ee:96:96:c9:bb:93:75:24:e1:41:09:0d:e9:\n    15:50:b3:70:c9:28:5c:64:52:45:d2:bd:87:20:21:\n    a8:9a:79:6c:2d:ce:38:c8:9c:18:f5:3b:fd:83:e1:\n    ea:c3:af:d6:eb:91:ad:3d:b6:89:59:ac:70:af:6a:\n    39:87:86:1b:2d:93:4b:ae:47:c6:02:b4:fd:8e:ba:\n    97:36:30:16:d8:b3:de:83:79:ee:0e:0d:93:cb:8f:\n    2c:6c:ab:e4:70:db:57:43:7e:54:43:8a:bc:d2:6a:\n    79:ca:2f:c6:c5:71:46:46:9d:8e:fd:2d:86:6e:53:\n    22:e2:15:32:9e:79:8b:7d:5e:fe:c9:d5:48:00:84:\n    66:37:8c:d0:b3:fe:a9:8a:92:37:a6:76:db:e2:95:\n    aa:07:f0:1d:1a:af:98:83:d2:ae:e7:f1:d2:15:a3:\n    7b:b3:48:f9:c3:44:23:01:89:ed:f0:12:15:16:b4:\n    1e:81:83:3a:70:11:ff:bf:62:b7:8e:9d:5a:11:3d:\n    3c:5f:49:35:5c:ef:cf:36:36:6a:66:b4:28:ed:d2:\n    e3:63:bb:cf:96:73:77:5e:17:f8:aa:48:77:1a:95:\n    9b:0e:46:27:7a:56:b8:e1:75:5b:17:51:92:67:99:\n    e1:1f\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA Root CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '22:4B:30:55:0D:D7:67:5E:63:1A:F8:74:80:9F:9E:9B:72:08:38:5E',
            },
            db_alias => {
                alias => 'root-2',
                generation => '2',
                group_id => 'root',
            },
        ),

        alpha_root_3 => OpenXPKI::Test::CertHelper::Database::PEM->new(
            label => 'ALPHA Root CA',
            db => {
                authority_key_identifier => 'B3:87:BF:C1:9B:7B:02:0E:0B:9C:4A:9C:55:4E:A7:0A:55:90:09:DA',
                cert_key => '14',
                data => "-----BEGIN CERTIFICATE-----\nMIIDizCCAnOgAwIBAgIBDjANBgkqhkiG9w0BAQsFADBWMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nFjAUBgNVBAMMDUFMUEhBIFJvb3QgQ0EwIhgPMjEwNzAxMDEwMDAwMDBaGA8yMTA4\nMDEzMTIzNTk1OVowVjETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmSJomT8ixk\nARkWCE9wZW5YUEtJMQ0wCwYDVQQLDARBQ01FMRYwFAYDVQQDDA1BTFBIQSBSb290\nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEApaltZ7aQdJ23YNm9\nKGCFclKjEgIiKv56xg6NvSLRa4nEGSQ0j+hj8KpuGgVZMJnQAtwCtkq7ueyw1Gwi\neirQ4hiFdOXSn1aU62yM8PbVOmZ2xOdNxvJYuA9wAgKswD1SdidDvhxty1ikhNPV\nqbAgKJPidoiHIt6GKNYyMA1+aBXP29GUEeum9pgMqlY6iut4HSAyavZK+J8clodz\nH6YGmMBApItsFyeOK/gRgbkVvxKd6nfD/SxIvVLWKHMBaNCWiD1Pda0Oxhz57wDw\nDicfEsocofQpeVla9KT/AVnYPfUAwtHCcRDrvIvkH5hW15ldwI/fzlH1s8SDEcck\nzm5vUQIDAQABo2AwXjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBSzh7/Bm3sC\nDgucSpxVTqcKVZAJ2jAfBgNVHSMEGDAWgBSzh7/Bm3sCDgucSpxVTqcKVZAJ2jAL\nBgNVHQ8EBAMCAQYwDQYJKoZIhvcNAQELBQADggEBAKGcVqXn1kyjmuqCgU4yLeNT\nyVNZgs2BpeqWQNeF79WViCe+OrLpNA6jpv+BBCv5Z41A+r5fbn1bl+Qodl2TUa+E\nug4FoUy2C7rekVvcuZ4pZEScUAFXc0fQaSvZ8YQ9MXi5oXXjDVkzNcvnfv/bWtSa\nUfxWxpa1XgBTFuWSpnGraql5Z615Fh9HRiRjr0LLbUR/n6Mmscjw6OJxLuPBF7Gn\nqxgFhyqq5hW8bK6RBBecWX82gBa7qLAUDglDCjo3Ba53pCtIFgR6eGsMPKIjJoB7\nn+b6YQY70yw+CazU40UP6sud2BJ99CIbSKlkGb+zMZhBDEiAdsfzjj7X1w+qCww=\n-----END CERTIFICATE-----",
                identifier => 'RrisDnSwLAcjJJvQhufjoNPMJr8',
                issuer_dn => 'CN=ALPHA Root CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'RrisDnSwLAcjJJvQhufjoNPMJr8',
                loa => undef,
                notafter => '4294967295', # 2106-02-07T06:28:15
                notbefore => '4294967295', # 2106-02-07T06:28:15
                pki_realm => 'alpha',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:a5:a9:6d:67:b6:90:74:9d:b7:60:d9:bd:28:60:\n    85:72:52:a3:12:02:22:2a:fe:7a:c6:0e:8d:bd:22:\n    d1:6b:89:c4:19:24:34:8f:e8:63:f0:aa:6e:1a:05:\n    59:30:99:d0:02:dc:02:b6:4a:bb:b9:ec:b0:d4:6c:\n    22:7a:2a:d0:e2:18:85:74:e5:d2:9f:56:94:eb:6c:\n    8c:f0:f6:d5:3a:66:76:c4:e7:4d:c6:f2:58:b8:0f:\n    70:02:02:ac:c0:3d:52:76:27:43:be:1c:6d:cb:58:\n    a4:84:d3:d5:a9:b0:20:28:93:e2:76:88:87:22:de:\n    86:28:d6:32:30:0d:7e:68:15:cf:db:d1:94:11:eb:\n    a6:f6:98:0c:aa:56:3a:8a:eb:78:1d:20:32:6a:f6:\n    4a:f8:9f:1c:96:87:73:1f:a6:06:98:c0:40:a4:8b:\n    6c:17:27:8e:2b:f8:11:81:b9:15:bf:12:9d:ea:77:\n    c3:fd:2c:48:bd:52:d6:28:73:01:68:d0:96:88:3d:\n    4f:75:ad:0e:c6:1c:f9:ef:00:f0:0e:27:1f:12:ca:\n    1c:a1:f4:29:79:59:5a:f4:a4:ff:01:59:d8:3d:f5:\n    00:c2:d1:c2:71:10:eb:bc:8b:e4:1f:98:56:d7:99:\n    5d:c0:8f:df:ce:51:f5:b3:c4:83:11:c7:24:ce:6e:\n    6f:51\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=ALPHA Root CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => 'B3:87:BF:C1:9B:7B:02:0E:0B:9C:4A:9C:55:4E:A7:0A:55:90:09:DA',
            },
            db_alias => {
                alias => 'root-3',
                generation => '3',
                group_id => 'root',
            },
        ),

        beta_alice_1 => OpenXPKI::Test::CertHelper::Database::PEM->new(
            label => 'BETA Client Alice',
            db => {
                authority_key_identifier => 'C0:73:45:48:66:91:F2:BC:1C:D1:07:25:6F:14:2A:FF:3A:86:FF:BB',
                cert_key => '23',
                data => "-----BEGIN CERTIFICATE-----\nMIIDfjCCAmagAwIBAgIBFzANBgkqhkiG9w0BAQsFADBYMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGDAWBgNVBAMMD0JFVEEgU2lnbmluZyBDQTAiGA8yMDE3MDEwMTAwMDAwMFoYDzIx\nMTcwMTMxMjM1OTU5WjBaMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZImiZPy\nLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxGjAYBgNVBAMMEUJFVEEgQ2xp\nZW50IEFsaWNlMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA5uuJIF5A\nF3DrsXRFBITbda2ftOVtKNdy5QFwV/PA+1wKOO2GwKksbZNpQTlCSaqlSKdjIYEz\nKEsvHSF1dWqEbcHssZkbMZyWXzew5HfN1BV053RjEVuAgHqN+6PsygnIm0oYsULm\nmlKQH91omTlAmfILNZVCop0gd9jfcBMV0v7VQNrpGRSj4hbwCx6RAKwyDX8nxhet\nbQXOzmNvWKEMLJLiukdtxogUH66aClUq0SpCojgak9/Dr3l+hvQwx3ShRUDQxxPC\nP+1dKrplsKX9DHyOyvY7uOT3eVAZymgL0qMZQqLIvalbL4cJg/yfOKT0DZ1m9tJy\nEtqkKoqPj5+iMQIDAQABo00wSzAJBgNVHRMEAjAAMB0GA1UdDgQWBBQjXeHFPjlK\nydJyM6UwXghh3fe6KDAfBgNVHSMEGDAWgBTAc0VIZpHyvBzRByVvFCr/Oob/uzAN\nBgkqhkiG9w0BAQsFAAOCAQEAdE2bXUWBKLvXOmTrZm0l+f7c2BAGadDu3XAB+P0v\n0Hr8hbsfggFCjbkgprXc9vxd1IZjYX2WnuRtDWHeiHp0BEsZzczdhFSDPJW06tBi\nzJZvfZ9/xgpweWeWX5WWvnnsxPPg95FpexLC9pTX12x0v363aiMQCSaeyNI6xznd\nuG9YgKgKaJ4thMgaYisOCDKhH6zMMYnYYgrpO5RqJ68Fibmm4HQvtjaqYWt3ovUQ\nZZwvF+cxRTLq00vIKXxmi7I/jJdMzODldAI2cHY6XoAjJpi8sD+nWTj7kQP1ks53\nQnttWnc9x8PISmgH/+GSLUZ2e5f+7D9ZEy9o701pSIenjQ==\n-----END CERTIFICATE-----",
                identifier => 'Z93LoaPuQbin83L2mfqo6tgYzfE',
                issuer_dn => 'CN=BETA Signing CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'dW9E0xfEVAiP707Hp-TXW0WKSsk',
                loa => undef,
                notafter => '4294967295', # 2106-02-07T06:28:15
                notbefore => '1483228800', # 2017-01-01T00:00:00
                pki_realm => 'beta',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:e6:eb:89:20:5e:40:17:70:eb:b1:74:45:04:84:\n    db:75:ad:9f:b4:e5:6d:28:d7:72:e5:01:70:57:f3:\n    c0:fb:5c:0a:38:ed:86:c0:a9:2c:6d:93:69:41:39:\n    42:49:aa:a5:48:a7:63:21:81:33:28:4b:2f:1d:21:\n    75:75:6a:84:6d:c1:ec:b1:99:1b:31:9c:96:5f:37:\n    b0:e4:77:cd:d4:15:74:e7:74:63:11:5b:80:80:7a:\n    8d:fb:a3:ec:ca:09:c8:9b:4a:18:b1:42:e6:9a:52:\n    90:1f:dd:68:99:39:40:99:f2:0b:35:95:42:a2:9d:\n    20:77:d8:df:70:13:15:d2:fe:d5:40:da:e9:19:14:\n    a3:e2:16:f0:0b:1e:91:00:ac:32:0d:7f:27:c6:17:\n    ad:6d:05:ce:ce:63:6f:58:a1:0c:2c:92:e2:ba:47:\n    6d:c6:88:14:1f:ae:9a:0a:55:2a:d1:2a:42:a2:38:\n    1a:93:df:c3:af:79:7e:86:f4:30:c7:74:a1:45:40:\n    d0:c7:13:c2:3f:ed:5d:2a:ba:65:b0:a5:fd:0c:7c:\n    8e:ca:f6:3b:b8:e4:f7:79:50:19:ca:68:0b:d2:a3:\n    19:42:a2:c8:bd:a9:5b:2f:87:09:83:fc:9f:38:a4:\n    f4:0d:9d:66:f6:d2:72:12:da:a4:2a:8a:8f:8f:9f:\n    a2:31\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=BETA Client Alice,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '23:5D:E1:C5:3E:39:4A:C9:D2:72:33:A5:30:5E:08:61:DD:F7:BA:28',
            },
            db_alias => {
                alias => 'beta-alice-1',
                generation => undef,
                group_id => undef,
            },
        ),

        beta_bob_1 => OpenXPKI::Test::CertHelper::Database::PEM->new(
            label => 'BETA Client Bob',
            db => {
                authority_key_identifier => 'C0:73:45:48:66:91:F2:BC:1C:D1:07:25:6F:14:2A:FF:3A:86:FF:BB',
                cert_key => '24',
                data => "-----BEGIN CERTIFICATE-----\nMIIDfDCCAmSgAwIBAgIBGDANBgkqhkiG9w0BAQsFADBYMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGDAWBgNVBAMMD0JFVEEgU2lnbmluZyBDQTAiGA8yMDE3MDEwMTAwMDAwMFoYDzIx\nMTcwMTMxMjM1OTU5WjBYMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZImiZPy\nLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxGDAWBgNVBAMMD0JFVEEgQ2xp\nZW50IEJvYjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALMAP01ZFYIX\nEuUTGXzEGRZiqOEKGogZK3DlR7tvv1oDkUXOMvD3xgG/r/za+JOX1rvnkOVO+BP+\nl3p1QtwHXgpUpLSqwpcFU33i6izsNR9Y3aZSlY2XTZxuS3oiJMFhJvxbIGeEOu1/\nDPIzKLkeHpI2trC/ok9QdLl3yAsSCRsnBdTEWuXpkcMKzyXEfetKkg6nuFK8l1Gs\n7a2bBFzsqSC4Umdv70JC+ga0w+bbSQTNpcwubuap0UvvZtWJEo5IrTE4vhTIaCQs\noXU+gghOQLUwILX2E5gp7L58Bu3+nFcinrlE8S9cPr7HzEfuw5SJLmo1X7koFQX2\nNloaw0o3STkCAwEAAaNNMEswCQYDVR0TBAIwADAdBgNVHQ4EFgQUJon9ZKJuJSg2\napAVjRKgtYxvBqcwHwYDVR0jBBgwFoAUwHNFSGaR8rwc0QclbxQq/zqG/7swDQYJ\nKoZIhvcNAQELBQADggEBACRe7ziKPVAy0x07bG6FpsGGaxNG3XgRx0lt8UhalQwO\n2K0NBMpzBaMIa7n+irLvsvb9kzULzxhncmAO32M6GzDNWsVIWo/pWJzwubVO/kDT\ndVj87sNyD3b3j7RSg7vFL16dxJHY/ktjQTLAYF9Q5ojpIdv2EFkNjzNjbz+032MX\nym9bzzhX80MF9zkgy7AHiyd7AEKuAGDyeOZxwm7adiZV3OGzTKNelfHAq2/LPOaC\nvLaW4ZaFUM7Gbv/HPPOzj0vce+ycfR89FE3oXpCXZK6yBHzLv+AgEhpGTnnXJeBD\nFdcuwGQ3nHessbn3Qby0SSOjU1mlOHqD/HTyD7NTtf0=\n-----END CERTIFICATE-----",
                identifier => '3Og3L2amYGlil0zxcY1jujbyYB8',
                issuer_dn => 'CN=BETA Signing CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'dW9E0xfEVAiP707Hp-TXW0WKSsk',
                loa => undef,
                notafter => '4294967295', # 2106-02-07T06:28:15
                notbefore => '1483228800', # 2017-01-01T00:00:00
                pki_realm => 'beta',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:b3:00:3f:4d:59:15:82:17:12:e5:13:19:7c:c4:\n    19:16:62:a8:e1:0a:1a:88:19:2b:70:e5:47:bb:6f:\n    bf:5a:03:91:45:ce:32:f0:f7:c6:01:bf:af:fc:da:\n    f8:93:97:d6:bb:e7:90:e5:4e:f8:13:fe:97:7a:75:\n    42:dc:07:5e:0a:54:a4:b4:aa:c2:97:05:53:7d:e2:\n    ea:2c:ec:35:1f:58:dd:a6:52:95:8d:97:4d:9c:6e:\n    4b:7a:22:24:c1:61:26:fc:5b:20:67:84:3a:ed:7f:\n    0c:f2:33:28:b9:1e:1e:92:36:b6:b0:bf:a2:4f:50:\n    74:b9:77:c8:0b:12:09:1b:27:05:d4:c4:5a:e5:e9:\n    91:c3:0a:cf:25:c4:7d:eb:4a:92:0e:a7:b8:52:bc:\n    97:51:ac:ed:ad:9b:04:5c:ec:a9:20:b8:52:67:6f:\n    ef:42:42:fa:06:b4:c3:e6:db:49:04:cd:a5:cc:2e:\n    6e:e6:a9:d1:4b:ef:66:d5:89:12:8e:48:ad:31:38:\n    be:14:c8:68:24:2c:a1:75:3e:82:08:4e:40:b5:30:\n    20:b5:f6:13:98:29:ec:be:7c:06:ed:fe:9c:57:22:\n    9e:b9:44:f1:2f:5c:3e:be:c7:cc:47:ee:c3:94:89:\n    2e:6a:35:5f:b9:28:15:05:f6:36:5a:1a:c3:4a:37:\n    49:39\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=BETA Client Bob,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '26:89:FD:64:A2:6E:25:28:36:6A:90:15:8D:12:A0:B5:8C:6F:06:A7',
            },
            db_alias => {
                alias => 'beta-bob-1',
                generation => undef,
                group_id => undef,
            },
        ),

        beta_scep_1 => OpenXPKI::Test::CertHelper::Database::PEM->new(
            label => 'BETA SCEP',
            db => {
                authority_key_identifier => '93:13:4F:A8:55:99:90:9C:00:23:92:B2:40:F7:02:ED:4E:E1:5B:8D',
                cert_key => '22',
                data => "-----BEGIN CERTIFICATE-----\nMIIDczCCAlugAwIBAgIBFjANBgkqhkiG9w0BAQsFADBVMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nFTATBgNVBAMMDEJFVEEgUm9vdCBDQTAiGA8yMDE3MDEwMTAwMDAwMFoYDzIxMTcw\nMTMxMjM1OTU5WjBSMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZImiZPyLGQB\nGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxEjAQBgNVBAMMCUJFVEEgU0NFUDCC\nASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJz9v53EdMdti/qhWjlla7rz\nnHl4sR7UgRFWlAlnQS6m2QhmhKEjoFqWkX3qRdUk+NqidApdMhYjvTWFL2aYc63t\nIBXJYPS858ruhVKxCJrUp6pHZV2zNxJ43l7KKX1UrdS4sCIDXxaa/BRTUkCfE+ed\nFxqAmklOOUaWzC1M/nOezL3tjmkvw2kq4sBPZxUFWp7wO5f5cd4SCrmamndFFFwt\nrcka3pFK7ewFM4mJimaDX0YStgPZN2dwnGXSxcI533dmF0oaHxlT3jok0QawpeDA\nYYNn22NcXrMLnEim1Vw2be0XOjbGLsJKEFKEPomaoO5jOtGCasTEzMlFnuSB5ykC\nAwEAAaNNMEswCQYDVR0TBAIwADAdBgNVHQ4EFgQUj36BNAXde5u/dpP4y1i/e1vr\n1FAwHwYDVR0jBBgwFoAUkxNPqFWZkJwAI5KyQPcC7U7hW40wDQYJKoZIhvcNAQEL\nBQADggEBAIt/8wSAunjALWvGzyAOiwfePHJ3txuG5j14X3N0kTShGtBri+4aVu/V\nW4cNizFWSa2XFXuNLcBs/z+tSE2er7DbVy6mf7c4I6P73JmBdGWh4C75rrGSciqq\n2J9EmGemLW1zA9qpdZLXfWU5e9FDiN5a+SqfmPLX/MLViqmvn7hObbs0bad2Wa55\nopgk21Xh3PzB2uicLGNySMQqYzRl8P6Lk+FUa6eDEQTj69l30+pQIJBegLUp57ZF\nXRlrmBSK0VWrnyoJ44dcUuU/6kPqvpBI4Kg8+Jc9vkKKiWaaYugFJZd0qvJhZ8lL\nscUNLm7SciacLj/tCWH6PuVSlxFpAnU=\n-----END CERTIFICATE-----",
                identifier => 'J3eiIhAZIQ1xv5fT5KTRIZtDW9g',
                issuer_dn => 'CN=BETA Root CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'dIzjGjejKrw9C4jX8CtBgb-58vs',
                loa => undef,
                notafter => '4294967295', # 2106-02-07T06:28:15
                notbefore => '1483228800', # 2017-01-01T00:00:00
                pki_realm => 'beta',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:9c:fd:bf:9d:c4:74:c7:6d:8b:fa:a1:5a:39:65:\n    6b:ba:f3:9c:79:78:b1:1e:d4:81:11:56:94:09:67:\n    41:2e:a6:d9:08:66:84:a1:23:a0:5a:96:91:7d:ea:\n    45:d5:24:f8:da:a2:74:0a:5d:32:16:23:bd:35:85:\n    2f:66:98:73:ad:ed:20:15:c9:60:f4:bc:e7:ca:ee:\n    85:52:b1:08:9a:d4:a7:aa:47:65:5d:b3:37:12:78:\n    de:5e:ca:29:7d:54:ad:d4:b8:b0:22:03:5f:16:9a:\n    fc:14:53:52:40:9f:13:e7:9d:17:1a:80:9a:49:4e:\n    39:46:96:cc:2d:4c:fe:73:9e:cc:bd:ed:8e:69:2f:\n    c3:69:2a:e2:c0:4f:67:15:05:5a:9e:f0:3b:97:f9:\n    71:de:12:0a:b9:9a:9a:77:45:14:5c:2d:ad:c9:1a:\n    de:91:4a:ed:ec:05:33:89:89:8a:66:83:5f:46:12:\n    b6:03:d9:37:67:70:9c:65:d2:c5:c2:39:df:77:66:\n    17:4a:1a:1f:19:53:de:3a:24:d1:06:b0:a5:e0:c0:\n    61:83:67:db:63:5c:5e:b3:0b:9c:48:a6:d5:5c:36:\n    6d:ed:17:3a:36:c6:2e:c2:4a:10:52:84:3e:89:9a:\n    a0:ee:63:3a:d1:82:6a:c4:c4:cc:c9:45:9e:e4:81:\n    e7:29\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=BETA SCEP,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '8F:7E:81:34:05:DD:7B:9B:BF:76:93:F8:CB:58:BF:7B:5B:EB:D4:50',
            },
            db_alias => {
                alias => 'beta-scep-1',
                generation => '1',
                group_id => 'beta-scep',
            },
        ),

        beta_signer_1 => OpenXPKI::Test::CertHelper::Database::PEM->new(
            label => 'BETA Signing CA',
            db => {
                authority_key_identifier => '93:13:4F:A8:55:99:90:9C:00:23:92:B2:40:F7:02:ED:4E:E1:5B:8D',
                cert_key => '21',
                data => "-----BEGIN CERTIFICATE-----\nMIIDjDCCAnSgAwIBAgIBFTANBgkqhkiG9w0BAQsFADBVMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nFTATBgNVBAMMDEJFVEEgUm9vdCBDQTAiGA8yMDE3MDEwMTAwMDAwMFoYDzIxMTcw\nMTMxMjM1OTU5WjBYMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZImiZPyLGQB\nGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxGDAWBgNVBAMMD0JFVEEgU2lnbmlu\nZyBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALHcv5j4482wY8SI\n2jBvX2G4o+8wWif9xtR0wceBZ/94QvWR9eOmKrgpVeV3AshRhkSfxDRFdbXa22oS\nolFrhgCRqlsWBel4F8LE2E2YzEDxMXGABq6jqHTD4/PCB8vyx25savTBco8sBcmn\nYQJsTExoZYzDz8c+F72O6V4tYkbY1FqrxsbEWTjXdf3OZiMj7fbnzFPX1xjpYzBl\newHORNdYKhFYPlBl0df65CwFCTc+VgeRJgtXiLzha4SkdywYolbJzR7BRz26sugu\nWwkK/xFnkaVSxHoo+iCTU3BdstTGPcXiM9LWKf3xvzDU7e9qhssB5harG+IsVkpq\nidLcAe8CAwEAAaNgMF4wDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUwHNFSGaR\n8rwc0QclbxQq/zqG/7swHwYDVR0jBBgwFoAUkxNPqFWZkJwAI5KyQPcC7U7hW40w\nCwYDVR0PBAQDAgEGMA0GCSqGSIb3DQEBCwUAA4IBAQA50pzLsCmYOK7dSGtHZesn\nXrCz9oPIt5q9RByVyp+iR0rMbBbjtA0Vah8hb/3KzPdrbdeqlUVmvz2BY+gE24Fw\nEZswXesJP7Af7I7P/QOtcRGyUa0DGuAMTHwykfgng35Rnf8mAghJErKrSdqM6rsg\noeIxr0hvXg8CmjFqUM7NDy3UIsTITj9Iy/JLIA4y1ALyz0ZU+CrdgaFUA+MtZqGl\nEkU8GAKbEeyjmzgLk6vJKiCkucYxnmZBtYRaRTegiA5iNVr6Y+hA7tj69cwsZc2h\nm8MgVfnmAc+6hTdHY7r9TqjgPU1gSrzrFmV2UVAnjN6fg70mFxqPULYlHt/hKzG9\n-----END CERTIFICATE-----",
                identifier => 'dW9E0xfEVAiP707Hp-TXW0WKSsk',
                issuer_dn => 'CN=BETA Root CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'dIzjGjejKrw9C4jX8CtBgb-58vs',
                loa => undef,
                notafter => '4294967295', # 2106-02-07T06:28:15
                notbefore => '1483228800', # 2017-01-01T00:00:00
                pki_realm => 'beta',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:b1:dc:bf:98:f8:e3:cd:b0:63:c4:88:da:30:6f:\n    5f:61:b8:a3:ef:30:5a:27:fd:c6:d4:74:c1:c7:81:\n    67:ff:78:42:f5:91:f5:e3:a6:2a:b8:29:55:e5:77:\n    02:c8:51:86:44:9f:c4:34:45:75:b5:da:db:6a:12:\n    a2:51:6b:86:00:91:aa:5b:16:05:e9:78:17:c2:c4:\n    d8:4d:98:cc:40:f1:31:71:80:06:ae:a3:a8:74:c3:\n    e3:f3:c2:07:cb:f2:c7:6e:6c:6a:f4:c1:72:8f:2c:\n    05:c9:a7:61:02:6c:4c:4c:68:65:8c:c3:cf:c7:3e:\n    17:bd:8e:e9:5e:2d:62:46:d8:d4:5a:ab:c6:c6:c4:\n    59:38:d7:75:fd:ce:66:23:23:ed:f6:e7:cc:53:d7:\n    d7:18:e9:63:30:65:7b:01:ce:44:d7:58:2a:11:58:\n    3e:50:65:d1:d7:fa:e4:2c:05:09:37:3e:56:07:91:\n    26:0b:57:88:bc:e1:6b:84:a4:77:2c:18:a2:56:c9:\n    cd:1e:c1:47:3d:ba:b2:e8:2e:5b:09:0a:ff:11:67:\n    91:a5:52:c4:7a:28:fa:20:93:53:70:5d:b2:d4:c6:\n    3d:c5:e2:33:d2:d6:29:fd:f1:bf:30:d4:ed:ef:6a:\n    86:cb:01:e6:16:ab:1b:e2:2c:56:4a:6a:89:d2:dc:\n    01:ef\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=BETA Signing CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => 'C0:73:45:48:66:91:F2:BC:1C:D1:07:25:6F:14:2A:FF:3A:86:FF:BB',
            },
            db_alias => {
                alias => 'beta-signer-1',
                generation => '1',
                group_id => 'beta-signer',
            },
        ),

        beta_vault_1 => OpenXPKI::Test::CertHelper::Database::PEM->new(
            label => 'BETA DataVault',
            db => {
                authority_key_identifier => 'AD:52:61:1F:12:A6:DD:B4:53:81:FC:5F:84:61:E0:AD:DD:A7:53:38',
                cert_key => '19',
                data => "-----BEGIN CERTIFICATE-----\nMIIDnDCCAoSgAwIBAgIBEzANBgkqhkiG9w0BAQsFADBXMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nFzAVBgNVBAMMDkJFVEEgRGF0YVZhdWx0MCIYDzIwMTcwMTAxMDAwMDAwWhgPMjEx\nNzAxMzEyMzU5NTlaMFcxEzARBgoJkiaJk/IsZAEZFgNPUkcxGDAWBgoJkiaJk/Is\nZAEZFghPcGVuWFBLSTENMAsGA1UECwwEQUNNRTEXMBUGA1UEAwwOQkVUQSBEYXRh\nVmF1bHQwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDFqxE7zbTHjrNH\neCE6pJCoTbuzbbBLZlGQMcPqYZsaDSv7Ik+yM13HXRuHVBfdP7m+RGciQ0bw7FrD\nS0G70okKUJQnDbZt/KqfkLi8dDf7JaJRzv3FK/gu1wpzdnQ5MOLB75YVsxyI9un8\nscV1wIkITGEXQ2jJ+dien2FBUeM3PBkegfQJH9vqL9vP0jUjZIz1OeNxWhLI6W5O\nYKNb0NVN0lm5TtlBh3zHn1C7ct35oYFzF8jlCY1cbqAEVHJ50ftlScxFIhXSUL6o\nviLD7Mfts0bS6GFMGk+CqqVOgbNZsuKQ1agxIU7EXZlgnXgCfvSV17RD3DfXBDeX\n0SUYrLy7AgMBAAGjbzBtMAkGA1UdEwQCMAAwHQYDVR0OBBYEFK1SYR8Spt20U4H8\nX4Rh4K3dp1M4MB8GA1UdIwQYMBaAFK1SYR8Spt20U4H8X4Rh4K3dp1M4MAsGA1Ud\nDwQEAwIFIDATBgNVHSUEDDAKBggrBgEFBQcDBDANBgkqhkiG9w0BAQsFAAOCAQEA\nDY5mlKvvv8y5jeqXmlm92Rb1zTKmAjUoXoIZ/kPEmPZP8Ie1e7q1Nqs57qkOnDcU\npsfJ7InE0g0cFTRKZZgnvj3z2zCUjUiTa/fArfwaVwHO+Jywr6hfXH9unarWiLt1\nIzJ3gxgcDFzKCJi0qrjwTxFxKL0//rKpXvrcpziGgty/ns3D72fasKE6a+MMOoHL\nNHyIQE6jhUn10PtN4Ej7M4P50clTpOU5ASRWLVYolsTdA2K0UVOum4LoNuBjnjjm\n1GqBNnxrv57tqV4dIxi1UEjfEzg1k6fOM1+bzwTU17yVIse7HbTxpoV2fOMh51rF\n5sxNxB6y01ZpkylZewFyOQ==\n-----END CERTIFICATE-----",
                identifier => 'Wr78SCygZVabVANx6i4W1g9-wlc',
                issuer_dn => 'CN=BETA DataVault,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'Wr78SCygZVabVANx6i4W1g9-wlc',
                loa => undef,
                notafter => '4294967295', # 2106-02-07T06:28:15
                notbefore => '1483228800', # 2017-01-01T00:00:00
                pki_realm => 'beta',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:c5:ab:11:3b:cd:b4:c7:8e:b3:47:78:21:3a:a4:\n    90:a8:4d:bb:b3:6d:b0:4b:66:51:90:31:c3:ea:61:\n    9b:1a:0d:2b:fb:22:4f:b2:33:5d:c7:5d:1b:87:54:\n    17:dd:3f:b9:be:44:67:22:43:46:f0:ec:5a:c3:4b:\n    41:bb:d2:89:0a:50:94:27:0d:b6:6d:fc:aa:9f:90:\n    b8:bc:74:37:fb:25:a2:51:ce:fd:c5:2b:f8:2e:d7:\n    0a:73:76:74:39:30:e2:c1:ef:96:15:b3:1c:88:f6:\n    e9:fc:b1:c5:75:c0:89:08:4c:61:17:43:68:c9:f9:\n    d8:9e:9f:61:41:51:e3:37:3c:19:1e:81:f4:09:1f:\n    db:ea:2f:db:cf:d2:35:23:64:8c:f5:39:e3:71:5a:\n    12:c8:e9:6e:4e:60:a3:5b:d0:d5:4d:d2:59:b9:4e:\n    d9:41:87:7c:c7:9f:50:bb:72:dd:f9:a1:81:73:17:\n    c8:e5:09:8d:5c:6e:a0:04:54:72:79:d1:fb:65:49:\n    cc:45:22:15:d2:50:be:a8:be:22:c3:ec:c7:ed:b3:\n    46:d2:e8:61:4c:1a:4f:82:aa:a5:4e:81:b3:59:b2:\n    e2:90:d5:a8:31:21:4e:c4:5d:99:60:9d:78:02:7e:\n    f4:95:d7:b4:43:dc:37:d7:04:37:97:d1:25:18:ac:\n    bc:bb\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=BETA DataVault,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => 'AD:52:61:1F:12:A6:DD:B4:53:81:FC:5F:84:61:E0:AD:DD:A7:53:38',
            },
            db_alias => {
                alias => 'beta-vault-1',
                generation => '1',
                group_id => 'beta-vault',
            },
        ),

        beta_root_1 => OpenXPKI::Test::CertHelper::Database::PEM->new(
            label => 'BETA Root CA',
            db => {
                authority_key_identifier => '93:13:4F:A8:55:99:90:9C:00:23:92:B2:40:F7:02:ED:4E:E1:5B:8D',
                cert_key => '20',
                data => "-----BEGIN CERTIFICATE-----\nMIIDiTCCAnGgAwIBAgIBFDANBgkqhkiG9w0BAQsFADBVMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nFTATBgNVBAMMDEJFVEEgUm9vdCBDQTAiGA8yMDE3MDEwMTAwMDAwMFoYDzIxMTcw\nMTMxMjM1OTU5WjBVMRMwEQYKCZImiZPyLGQBGRYDT1JHMRgwFgYKCZImiZPyLGQB\nGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUxFTATBgNVBAMMDEJFVEEgUm9vdCBD\nQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKnu8xUzS0Gju41jGoIs\nweZX4Ngc4b7apvVdbMD0e4g8/xRXiC7canYIJznLXaIUXds0js53MQKAquYPfz+s\nlYrXvwlZGKggvb9/lGimFwtJfxoJEq/xdgQsW/GfcDatM8N0zA7rfSE6mpo2m/ZK\njwcfON/FkBx9z0BIvi1sycdnn2fhp/pnqAPdnTy7qJ70aFmM2xyTn/pjq5pJIV4I\nhX1Kbqyq1LV375P95B+ZiAxhOESgIG08n8kXil1ob1t64QbliI6GHgxc/Efp43FM\nNRwuTJt4OXSoLX8De9S1ep7NF/cRjzT0UJ7spGYqamMK401JDkaKjog8k6Qw+q+r\nDJcCAwEAAaNgMF4wDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUkxNPqFWZkJwA\nI5KyQPcC7U7hW40wHwYDVR0jBBgwFoAUkxNPqFWZkJwAI5KyQPcC7U7hW40wCwYD\nVR0PBAQDAgEGMA0GCSqGSIb3DQEBCwUAA4IBAQB1pu5NxHNxJwJu6NHI+s16cEOw\n0zDF2Y3I8oJdEe+D20gLS4inFdgOFFaJEyodatolidy5B2C87gqTyhDnyhs45YBy\n8suj0ZbiLCaGHlLGVszUxNxi6ti/VChiXkbKGdZ0O4lUtgu0h0lYKfX8rLYOLMUd\ny6OgpSi/76GcGsgXfM5qTCjAZYBuayXFaox689/3lDwKCFEIcNVYfSPYo7djnUmx\nAD8o05FPScnHa/X/LPWwXzXn5gMt0HtzIRhWFPF04tr9+Px0U1vs3d3dEPn+1D9n\nPunpANu8I8aX/wI+7LoEA4TPxQR3qrF+IROVtlA+Nwf64rA6Yc003C3DHLur\n-----END CERTIFICATE-----",
                identifier => 'dIzjGjejKrw9C4jX8CtBgb-58vs',
                issuer_dn => 'CN=BETA Root CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => 'dIzjGjejKrw9C4jX8CtBgb-58vs',
                loa => undef,
                notafter => '4294967295', # 2106-02-07T06:28:15
                notbefore => '1483228800', # 2017-01-01T00:00:00
                pki_realm => 'beta',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:a9:ee:f3:15:33:4b:41:a3:bb:8d:63:1a:82:2c:\n    c1:e6:57:e0:d8:1c:e1:be:da:a6:f5:5d:6c:c0:f4:\n    7b:88:3c:ff:14:57:88:2e:dc:6a:76:08:27:39:cb:\n    5d:a2:14:5d:db:34:8e:ce:77:31:02:80:aa:e6:0f:\n    7f:3f:ac:95:8a:d7:bf:09:59:18:a8:20:bd:bf:7f:\n    94:68:a6:17:0b:49:7f:1a:09:12:af:f1:76:04:2c:\n    5b:f1:9f:70:36:ad:33:c3:74:cc:0e:eb:7d:21:3a:\n    9a:9a:36:9b:f6:4a:8f:07:1f:38:df:c5:90:1c:7d:\n    cf:40:48:be:2d:6c:c9:c7:67:9f:67:e1:a7:fa:67:\n    a8:03:dd:9d:3c:bb:a8:9e:f4:68:59:8c:db:1c:93:\n    9f:fa:63:ab:9a:49:21:5e:08:85:7d:4a:6e:ac:aa:\n    d4:b5:77:ef:93:fd:e4:1f:99:88:0c:61:38:44:a0:\n    20:6d:3c:9f:c9:17:8a:5d:68:6f:5b:7a:e1:06:e5:\n    88:8e:86:1e:0c:5c:fc:47:e9:e3:71:4c:35:1c:2e:\n    4c:9b:78:39:74:a8:2d:7f:03:7b:d4:b5:7a:9e:cd:\n    17:f7:11:8f:34:f4:50:9e:ec:a4:66:2a:6a:63:0a:\n    e3:4d:49:0e:46:8a:8e:88:3c:93:a4:30:fa:af:ab:\n    0c:97\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=BETA Root CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '93:13:4F:A8:55:99:90:9C:00:23:92:B2:40:F7:02:ED:4E:E1:5B:8D',
            },
            db_alias => {
                alias => 'root-1',
                generation => '1',
                group_id => 'root',
            },
        ),

        gamma_bob_1 => OpenXPKI::Test::CertHelper::Database::PEM->new(
            label => 'GAMMA Client Bob',
            db => {
                authority_key_identifier => '29:42:8C:90:3C:97:D9:F8:F0:DB:61:56:75:EB:C1:8E:CE:13:B6:C9',
                cert_key => '30',
                data => "-----BEGIN CERTIFICATE-----\nMIIDfjCCAmagAwIBAgIBHjANBgkqhkiG9w0BAQsFADBZMRMwEQYKCZImiZPyLGQB\nGRYDT1JHMRgwFgYKCZImiZPyLGQBGRYIT3BlblhQS0kxDTALBgNVBAsMBEFDTUUx\nGTAXBgNVBAMMEEdBTU1BIFNpZ25pbmcgQ0EwIhgPMjAxNzAxMDEwMDAwMDBaGA8y\nMTE3MDEzMTIzNTk1OVowWTETMBEGCgmSJomT8ixkARkWA09SRzEYMBYGCgmSJomT\n8ixkARkWCE9wZW5YUEtJMQ0wCwYDVQQLDARBQ01FMRkwFwYDVQQDDBBHQU1NQSBD\nbGllbnQgQm9iMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEArFaAP0SY\nvANkVIP27xJJ7pWxKwZLcVfNV8tmqwf888Zm4JAMK64kE+XISnXnI5pvUtX895YD\nw5FirHNtwZBjzNrjVBvSWixUIJqJEnBFagfq8sbEBsN93E4eWkA+uwPpyJehQIlj\nm7xvNgl7fzEmrXhpM1CXYnv+QxOB9sLd1y4/qHAy/Dr2ZUyS9kGkcKz5uSHuBQJE\ncYHkqC9+YWPQuAv8AeNNg4eR0YCl2GNjiATDXrmHWyFeMkOKVqMfu0lz4F0s43X7\nXh2XXU98P0z5WyMRknXATeBF4ePUu/08fAWa1qn9UVlep3eKncvz46JlD7bGG0Bk\nC1544ffoC7O34wIDAQABo00wSzAJBgNVHRMEAjAAMB0GA1UdDgQWBBSBrVzEv14B\nG7FGieuEix9l3PO/0DAfBgNVHSMEGDAWgBQpQoyQPJfZ+PDbYVZ168GOzhO2yTAN\nBgkqhkiG9w0BAQsFAAOCAQEAxRCDYBkMlGnIDjW4SuZv1CeBcwoNPYfkbViA15nT\nQSqfVp/Lrnb9P7Zlzx50COzRtatDl1AxySkaUACeZkZ7uvjbKC0+G8+rR9Dktmh+\n8RQB3rZlGX8PQu4h1lWC8JnNKs5D8jUqzTM5K6Z3QmN2GIU46JpjhWCsUiHLhVaW\naRXA4hkgMeCKHaoKSaS8zjO15JQHlSrF3KxGw6TKbBVpdptfhnawuVbCYSJ0QofI\nfJeCwoVErw3Vj1z1CWNeSuivuhuBS9nD2sXCmy1ot58CsXjTOc5nLVqhqucpCTxU\nqOe+PT0E1n3cLjrhV+GevjHBpbro7Kc8D0aWCDpa5PKnOA==\n-----END CERTIFICATE-----",
                identifier => 'gZocpJ9ZUT9N_d9kpNQRFzFWj9w',
                issuer_dn => 'CN=GAMMA Signing CA,OU=ACME,DC=OpenXPKI,DC=ORG',
                issuer_identifier => '',
                loa => undef,
                notafter => '4294967295', # 2106-02-07T06:28:15
                notbefore => '1483228800', # 2017-01-01T00:00:00
                pki_realm => 'gamma',
                public_key => "Public-Key: (2048 bit)\nModulus:\n    00:ac:56:80:3f:44:98:bc:03:64:54:83:f6:ef:12:\n    49:ee:95:b1:2b:06:4b:71:57:cd:57:cb:66:ab:07:\n    fc:f3:c6:66:e0:90:0c:2b:ae:24:13:e5:c8:4a:75:\n    e7:23:9a:6f:52:d5:fc:f7:96:03:c3:91:62:ac:73:\n    6d:c1:90:63:cc:da:e3:54:1b:d2:5a:2c:54:20:9a:\n    89:12:70:45:6a:07:ea:f2:c6:c4:06:c3:7d:dc:4e:\n    1e:5a:40:3e:bb:03:e9:c8:97:a1:40:89:63:9b:bc:\n    6f:36:09:7b:7f:31:26:ad:78:69:33:50:97:62:7b:\n    fe:43:13:81:f6:c2:dd:d7:2e:3f:a8:70:32:fc:3a:\n    f6:65:4c:92:f6:41:a4:70:ac:f9:b9:21:ee:05:02:\n    44:71:81:e4:a8:2f:7e:61:63:d0:b8:0b:fc:01:e3:\n    4d:83:87:91:d1:80:a5:d8:63:63:88:04:c3:5e:b9:\n    87:5b:21:5e:32:43:8a:56:a3:1f:bb:49:73:e0:5d:\n    2c:e3:75:fb:5e:1d:97:5d:4f:7c:3f:4c:f9:5b:23:\n    11:92:75:c0:4d:e0:45:e1:e3:d4:bb:fd:3c:7c:05:\n    9a:d6:a9:fd:51:59:5e:a7:77:8a:9d:cb:f3:e3:a2:\n    65:0f:b6:c6:1b:40:64:0b:5e:78:e1:f7:e8:0b:b3:\n    b7:e3\nExponent: 65537 (0x10001)\n",
                req_key => undef,
                status => 'ISSUED',
                subject => 'CN=GAMMA Client Bob,OU=ACME,DC=OpenXPKI,DC=ORG',
                subject_key_identifier => '81:AD:5C:C4:BF:5E:01:1B:B1:46:89:EB:84:8B:1F:65:DC:F3:BF:D0',
            },
            db_alias => {
                alias => 'gamma-bob-1',
                generation => undef,
                group_id => undef,
            },
        ),
    };
}

__PACKAGE__->meta->make_immutable;
