package OpenXPKI::Role::CertAndReqParser;
use OpenXPKI -role;

=head1 NAME

OpenXPKI::Role::CertAndReqParser - Shared ASN.1 parser for X.509 certificates
and PKCS#10 certificate signing requests

=head1 DESCRIPTION

Provides a unified Convert::ASN1 schema, extension parsing, subject DN parsing
and public key extraction for both certificate and CSR objects.

Consuming classes must provide:

=over

=item C<_asn1_root_node> method - returns C<'Certificate'> or C<'CertificationRequest'>

=item C<_pem_type> method - returns the PEM type string, e.g. C<'CERTIFICATE'> or C<'CERTIFICATE REQUEST'>

=back

=cut

with 'OpenXPKI::Role::ASN1Parse';

requires '_pem_type';

use OpenXPKI::Types;
use Convert::ASN1 ':tag';
use Digest::SHA qw(sha1_base64 sha1_hex);
use MIME::Base64 qw(encode_base64 decode_base64);
use OpenXPKI::Crypt::DN;
use OpenXPKI::Crypt::Profile::DTO::BasicConstraints;
use OpenXPKI::Crypt::Profile::DTO::KeyUsage;
use OpenXPKI::Crypt::Profile::DTO::ExtendedKeyUsage;
use OpenXPKI::Crypt::Profile::DTO::ExtCertificateTemplate;

# OID for extensionRequest attribute in CSR attributes
use constant EXT_REQUEST_OID => '1.2.840.113549.1.9.14';

# Known signature algorithm OIDs → hash algorithm name
my %SIG_ALG_DIGEST = (
    '1.2.840.113549.1.1.4'  => 'md5',     # md5WithRSAEncryption
    '1.2.840.113549.1.1.5'  => 'sha1',    # sha1WithRSAEncryption
    '1.2.840.113549.1.1.11' => 'sha256',  # sha256WithRSAEncryption
    '1.2.840.113549.1.1.12' => 'sha384',  # sha384WithRSAEncryption
    '1.2.840.113549.1.1.13' => 'sha512',  # sha512WithRSAEncryption
    '1.2.840.113549.1.1.14' => 'sha224',  # sha224WithRSAEncryption
    '1.2.840.10045.4.3.1'   => 'sha224',  # ecdsa-with-SHA224
    '1.2.840.10045.4.3.2'   => 'sha256',  # ecdsa-with-SHA256
    '1.2.840.10045.4.3.3'   => 'sha384',  # ecdsa-with-SHA384
    '1.2.840.10045.4.3.4'   => 'sha512',  # ecdsa-with-SHA512
    '1.3.14.3.2.29'         => 'sha1',    # sha-1WithRSAEncryption (legacy)
    '1.2.840.113549.1.1.10'  => 'pss',    # rsassaPss
);

# Hash algorithm OIDs used inside RSASSA-PSS-params (NIST OIDs)
my %HASH_ALG_OID = (
    '1.3.14.3.2.26'          => 'SHA1',
    '2.16.840.1.101.3.4.2.4' => 'SHA224',
    '2.16.840.1.101.3.4.2.1' => 'SHA256',
    '2.16.840.1.101.3.4.2.2' => 'SHA384',
    '2.16.840.1.101.3.4.2.3' => 'SHA512',
);

# Known public key algorithm OIDs → normalized name
my %PUBKEY_ALG = (
    '1.2.840.113549.1.1.1'  => 'RSA',   # rsaEncryption
    '1.2.840.113549.1.1.10' => 'RSA',   # id-RSASSA-PSS (RSA-PSS key)
    '1.2.840.10045.2.1'     => 'EC',    # id-ecPublicKey
);

# Known EC curve OIDs → (curve_name, key_length_bits)
my %EC_CURVE = (
    '1.2.840.10045.3.1.7'    => ['prime256v1',     256],
    '1.3.132.0.34'           => ['secp384r1',       384],
    '1.3.132.0.35'           => ['secp521r1',       521],
    '1.3.132.0.33'           => ['secp224r1',       224],
    '1.3.132.0.10'           => ['secp256k1',       256],
    '1.2.840.10045.3.1.1'    => ['prime192v1',      192],
    # Brainpool r1
    '1.3.36.3.3.2.8.1.1.1'  => ['brainpoolP160r1', 160],
    '1.3.36.3.3.2.8.1.1.3'  => ['brainpoolP192r1', 192],
    '1.3.36.3.3.2.8.1.1.5'  => ['brainpoolP224r1', 224],
    '1.3.36.3.3.2.8.1.1.7'  => ['brainpoolP256r1', 256],
    '1.3.36.3.3.2.8.1.1.9'  => ['brainpoolP320r1', 320],
    '1.3.36.3.3.2.8.1.1.11' => ['brainpoolP384r1', 384],
    '1.3.36.3.3.2.8.1.1.13' => ['brainpoolP512r1', 512],
    # Brainpool t1 (twisted)
    '1.3.36.3.3.2.8.1.1.2'  => ['brainpoolP160t1', 160],
    '1.3.36.3.3.2.8.1.1.4'  => ['brainpoolP192t1', 192],
    '1.3.36.3.3.2.8.1.1.6'  => ['brainpoolP224t1', 224],
    '1.3.36.3.3.2.8.1.1.8'  => ['brainpoolP256t1', 256],
    '1.3.36.3.3.2.8.1.1.10' => ['brainpoolP320t1', 320],
    '1.3.36.3.3.2.8.1.1.12' => ['brainpoolP384t1', 384],
    '1.3.36.3.3.2.8.1.1.14' => ['brainpoolP512t1', 512],
);

# SAN type name mapping (ASN1 field name → OpenXPKI canonical name)
my %SAN_TYPE = (
    rfc822Name               => 'email',
    dNSName                  => 'DNS',
    uniformResourceIdentifier => 'URI',
    iPAddress                => 'IP',
    registeredID             => 'RID',
    directoryName            => 'dirName',
    otherName                => 'otherName',
);

# KeyUsage bit positions (index → name, bit 0 = MSB of first byte)
my @KEY_USAGE_BITS = qw(
    digitalSignature
    nonRepudiation
    keyEncipherment
    dataEncipherment
    keyAgreement
    keyCertSign
    cRLSign
    encipherOnly
    decipherOnly
);

# Known ExtendedKeyUsage OIDs → name
my %EKU_OID = (
    '1.3.6.1.5.5.7.3.1'       => 'serverAuth',
    '1.3.6.1.5.5.7.3.2'       => 'clientAuth',
    '1.3.6.1.5.5.7.3.3'       => 'codeSigning',
    '1.3.6.1.5.5.7.3.4'       => 'emailProtection',
    '1.3.6.1.5.5.7.3.8'       => 'timeStamping',
    '1.3.6.1.5.5.7.3.9'       => 'OCSPSigning',
    '1.3.6.1.5.5.7.3.21'      => 'sshClient',
    '1.3.6.1.5.5.7.3.22'      => 'sshServer',
    '1.3.6.1.5.2.3.5'         => 'keyPurposeKdc',
    '1.3.6.1.4.1.311.10.3.4'  => 'msEFS',
    '1.3.6.1.4.1.311.20.2.2'  => 'msSmartcardLogon',
    '1.3.6.1.4.1.311.10.3.12' => 'msDocumentSigning',
);

# Name → OID for certificate/CSR extensions (camelCase, lowercase first)
our %KNOWN_EXT = (
    certificatePolicies     => '2.5.29.32',
    subjectInfoAccess       => '1.3.6.1.5.5.7.1.11',
    certificateTemplate     => '1.3.6.1.4.1.311.21.7',
    certificateTemplateName => '1.3.6.1.4.1.311.20.2',
);

# Shared ASN.1 schema covering Certificate, CertificationRequest, and all common extensions
my $SCHEMA = q{
    DirectoryString ::= CHOICE {
        teletexString   TeletexString,
        printableString PrintableString,
        bmpString       BMPString,
        universalString UniversalString,
        utf8String      UTF8String,
        ia5String       IA5String,
        integer         INTEGER
    }

    AttributeTypeAndValue ::= SEQUENCE {
        type  OBJECT IDENTIFIER,
        value DirectoryString
    }
    RelativeDistinguishedName ::= SET OF AttributeTypeAndValue
    RDNSequence ::= SEQUENCE OF RelativeDistinguishedName
    Name ::= CHOICE { rdnSequence RDNSequence }

    Extension ::= SEQUENCE {
        extnID    OBJECT IDENTIFIER,
        critical  BOOLEAN OPTIONAL,
        extnValue OCTET STRING
    }
    Extensions ::= SEQUENCE OF Extension

    OtherName ::= SEQUENCE {
        type  OBJECT IDENTIFIER,
        value [0] EXPLICIT ANY
    }
    GeneralName ::= CHOICE {
        otherName     [0] IMPLICIT OtherName,
        rfc822Name    [1] IMPLICIT IA5String,
        dNSName       [2] IMPLICIT IA5String,
        x400Address   [3] ANY,
        directoryName [4] EXPLICIT Name,
        ediPartyName  [5] ANY,
        uniformResourceIdentifier [6] IMPLICIT IA5String,
        iPAddress     [7] IMPLICIT OCTET STRING,
        registeredID  [8] IMPLICIT OBJECT IDENTIFIER
    }
    GeneralNames ::= SEQUENCE OF GeneralName

    BasicConstraints ::= SEQUENCE {
        cA                BOOLEAN OPTIONAL,
        pathLenConstraint INTEGER OPTIONAL
    }

    ExtendedKeyUsage ::= SEQUENCE OF OBJECT IDENTIFIER

    SubjectKeyIdentifier ::= OCTET STRING

    AuthorityKeyIdentifier ::= SEQUENCE {
        keyIdentifier [0] OCTET STRING OPTIONAL
    }

    AccessDescription ::= SEQUENCE {
        accessMethod   OBJECT IDENTIFIER,
        accessLocation GeneralName
    }
    AuthorityInfoAccess ::= SEQUENCE OF AccessDescription

    DistributionPointName ::= CHOICE {
        fullName [0] IMPLICIT GeneralNames
    }
    DistributionPoint ::= SEQUENCE {
        distributionPoint [0] EXPLICIT DistributionPointName OPTIONAL,
        reasons           [1] ANY OPTIONAL,
        cRLIssuer         [2] ANY OPTIONAL
    }
    CRLDistributionPoints ::= SEQUENCE OF DistributionPoint

    CertificateTemplate ::= SEQUENCE {
        templateID           OBJECT IDENTIFIER,
        templateMajorVersion INTEGER OPTIONAL,
        templateMinorVersion INTEGER OPTIONAL
    }

    AlgorithmIdentifier ::= SEQUENCE {
        algorithm  OBJECT IDENTIFIER,
        parameters ANY OPTIONAL
    }
    EcParameters ::= OBJECT IDENTIFIER

    SubjectPublicKeyInfo ::= SEQUENCE {
        algorithm        AlgorithmIdentifier,
        subjectPublicKey BIT STRING
    }

    RSAPublicKey ::= SEQUENCE {
        modulus        INTEGER,
        publicExponent INTEGER
    }

    Time ::= CHOICE {
        utcTime     UTCTime,
        generalTime GeneralizedTime
    }
    Validity ::= SEQUENCE {
        notBefore Time,
        notAfter  Time
    }

    TBSCertificate ::= SEQUENCE {
        version              [0] EXPLICIT INTEGER OPTIONAL,
        serialNumber         INTEGER,
        signature            AlgorithmIdentifier,
        issuer               Name,
        validity             Validity,
        subject              Name,
        subjectPublicKeyInfo SubjectPublicKeyInfo,
        extensions           [3] EXPLICIT Extensions OPTIONAL
    }

    Certificate ::= SEQUENCE {
        tbsCertificate     TBSCertificate,
        signatureAlgorithm AlgorithmIdentifier,
        signature          BIT STRING
    }

    Attribute ::= SEQUENCE {
        attrType   OBJECT IDENTIFIER,
        attrValues SET OF ANY
    }
    Attributes ::= SET OF Attribute

    CertificationRequestInfo ::= SEQUENCE {
        version       INTEGER,
        subject       Name,
        subjectPKInfo SubjectPublicKeyInfo,
        attributes    [0] IMPLICIT Attributes OPTIONAL
    }

    CertificationRequest ::= SEQUENCE {
        certificationRequestInfo CertificationRequestInfo,
        signatureAlgorithm       AlgorithmIdentifier,
        signature                BIT STRING
    }

    CertificatePolicies ::= SEQUENCE OF PolicyInformation
    PolicyInformation ::= SEQUENCE {
        policyIdentifier  OBJECT IDENTIFIER,
        policyQualifiers  PolicyQualifiers OPTIONAL }
    PolicyQualifiers ::= SEQUENCE OF PolicyQualifierInfo
    PolicyQualifierInfo ::= SEQUENCE {
        policyQualifierId  OBJECT IDENTIFIER,
        qualifier          ANY }
    CPSuri ::= IA5String
    DisplayText ::= CHOICE {
        visibleString  VisibleString,
        bmpString      BMPString,
        utf8String     UTF8String }
    UserNotice ::= SEQUENCE {
        noticeRef     NoticeReference OPTIONAL,
        explicitText  DisplayText OPTIONAL }
    NoticeReference ::= SEQUENCE {
        organization  DisplayText,
        noticeNumbers SEQUENCE OF INTEGER }

    RsassaPssParams ::= SEQUENCE {
        hashAlgorithm    [0] EXPLICIT AlgorithmIdentifier OPTIONAL,
        maskGenAlgorithm [1] EXPLICIT AlgorithmIdentifier OPTIONAL,
        saltLength       [2] EXPLICIT INTEGER OPTIONAL,
        trailerField     [3] EXPLICIT INTEGER OPTIONAL }

};

=head1 ATTRIBUTES

=head2 data

The raw DER-encoded bytes of the certificate or CSR.

=cut

has data => (
    is       => 'ro',
    required => 1,
    isa      => 'Str',
);

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    my $data  = shift;
    my $type  = $class->_pem_type();
    if ($data =~ m{-----BEGIN[^-]*\Q$type\E-----(.+?)-----END[^-]*\Q$type\E-----}xms) {
        $data = decode_base64($1);
    }
    return $class->$orig(data => $data);
};

=head2 pem

The PEM-encoded certificate or CSR with type-specific headers, wrapped at 64 characters per line.

=cut

has pem => (
    is       => 'ro',
    init_arg => undef,
    isa      => 'Str',
    lazy     => 1,
    default  => sub {
        my $self = shift;
        my $type = $self->_pem_type();
        my $pem = encode_base64($self->data(), '');
        $pem =~ s{ (.{64}) }{$1\n}xmsg;
        chomp $pem;
        return "-----BEGIN $type-----\n$pem\n-----END $type-----";
    },
);

=head2 get_identifier

SHA1 base64 URL-safe hash over the raw DER data. Serves as C<cert_identifier> for
certificates and C<csr_identifier> for CSRs.

=cut

has identifier => (
    is       => 'ro',
    init_arg => undef,
    isa      => 'Str',
    reader   => 'get_identifier',
    lazy     => 1,
    default  => sub {
        my $id = sha1_base64(shift->data);
        $id =~ tr/+\//-_/;
        return $id;
    },
);

=head2 get_public_key_hash

SHA1 hash of the raw public key bytes, formatted as an uppercase colon-separated
hex string (e.g. C<AB:CD:EF:...>).

=cut

has public_key_hash => (
    is       => 'ro',
    init_arg => undef,
    isa      => 'Str',
    reader   => 'get_public_key_hash',
    lazy     => 1,
    default  => sub {
        my $self = shift;
        return uc join ':', (unpack '(A2)*', sha1_hex($self->get_pub_key()));
    },
);

# Returns a parser for the named ASN.1 node (cached singleton)
sub _asn1 {
    my ($self, $node) = @_;
    state $asn;
    unless ($asn) {
        $asn = Convert::ASN1->new;
        $asn->prepare($SCHEMA) or OpenXPKI::Exception->throw(
            message => 'ASN.1 schema preparation failed',
            params  => { error => $asn->error },
        );
    }
    my $parser = $asn->find($node)
        or OpenXPKI::Exception->throw(
            message => 'Unknown ASN.1 node',
            params  => { node => $node },
        );
    return $parser;
}

# Parsed top-level DER structure (Certificate or CertificationRequest)
has _parsed => (
    is       => 'ro',
    lazy     => 1,
    init_arg => undef,
    builder  => '_build_parsed',
);

sub _build_parsed {
    my $self = shift;
    my $parser = $self->_asn1($self->_asn1_root_node);
    my $result = $parser->decode($self->data)
        or OpenXPKI::Exception->throw(
            message => 'ASN.1 decode failed',
            params  => { error => $parser->error, type => $self->_asn1_root_node },
        );
    return $result;
}

# Internal: returns arrayref of {extnID, critical, extnValue} for all extensions
sub _raw_extensions {
    my $self = shift;
    if ($self->_asn1_root_node eq 'Certificate') {
        return $self->_parsed->{tbsCertificate}{extensions} // [];
    }
    else {
        my $attrs = $self->_parsed->{certificationRequestInfo}{attributes} // [];
        my ($ext_attr) = grep { $_->{attrType} eq EXT_REQUEST_OID } @$attrs;
        return [] unless $ext_attr;
        my $raw = $ext_attr->{attrValues}[0] or return [];
        my $exts = $self->_asn1('Extensions')->decode($raw) or return [];
        return $exts;
    }
}

# Internal: returns rdnSequence arrayref for subject
sub _raw_subject_rdn {
    my $self = shift;
    if ($self->_asn1_root_node eq 'Certificate') {
        return $self->_parsed->{tbsCertificate}{subject}{rdnSequence};
    } else {
        return $self->_parsed->{certificationRequestInfo}{subject}{rdnSequence};
    }
}

# Internal: returns SubjectPublicKeyInfo hashref
sub _raw_spki {
    my $self = shift;
    if ($self->_asn1_root_node eq 'Certificate') {
        return $self->_parsed->{tbsCertificate}{subjectPublicKeyInfo};
    } else {
        return $self->_parsed->{certificationRequestInfo}{subjectPKInfo};
    }
}

# Internal: returns the raw extension DER bytes for a given OID, or undef
sub _get_ext_der {
    my ($self, $oid) = @_;
    my $ext = $self->extensions->{$oid};
    return $ext ? $ext->{der} : undef;
}

=head2 extensions

HashRef mapping OID strings to C<{critical =E<gt> Bool, der =E<gt> Str}> hashrefs.
The C<der> value contains the raw DER bytes of the extension value (the content
of the extnValue OCTET STRING), suitable for further ASN.1 decoding.

=cut

has extensions => (
    is       => 'ro',
    isa      => 'HashRef',
    lazy     => 1,
    init_arg => undef,
    builder  => '_build_extensions',
);

sub _build_extensions {
    my $self = shift;
    my %map;
    for my $ext (@{$self->_raw_extensions}) {
        $map{$ext->{extnID}} = {
            critical => $ext->{critical} ? 1 : 0,
            der      => $ext->{extnValue},
        };
    }
    return \%map;
}

=head2 get_subject

Subject DN as RFC 2253 string (CN first).

=cut

has subject => (
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    init_arg => undef,
    reader   => 'get_subject',
    builder  => '_build_subject',
);

sub _build_subject {
    my $self = shift;
    my $rdn = $self->_raw_subject_rdn or return '';
    return OpenXPKI::Crypt::DN->new(sequence => $rdn)->get_subject();
}

=head2 subject_hash

Subject DN components as HashRef of uppercase key → ArrayRef of values.

=cut

has subject_hash => (
    is       => 'ro',
    isa      => 'HashRef',
    lazy     => 1,
    init_arg => undef,
    builder  => '_build_subject_hash',
);

sub _build_subject_hash {
    my $self = shift;
    my $rdn = $self->_raw_subject_rdn or return {};
    return OpenXPKI::Crypt::DN->new(sequence => $rdn)->as_hash();
}

=head2 get_subject_alt_name

ArrayRef of C<[$type, $value]> pairs from the subjectAltName extension.
Types: C<DNS>, C<email>, C<URI>, C<IP>, C<RID>, C<dirName>, C<otherName>.

=cut

has subject_alt_name => (
    is       => 'ro',
    isa      => 'ArrayRef',
    lazy     => 1,
    init_arg => undef,
    reader   => 'get_subject_alt_name',
    builder  => '_build_subject_alt_name',
);

sub _build_subject_alt_name {
    my $self = shift;
    my $der = $self->_get_ext_der('2.5.29.17') or return [];

    my $parser = $self->_asn1('GeneralNames');
    my $decoded = $parser->decode($der)
        or OpenXPKI::Exception->throw(
            message => 'Failed to decode subjectAltName extension',
            params  => { error => $parser->error },
        );

    my @result;
    for my $name (@$decoded) {
        for my $type (keys %$name) {
            my $san_type = $SAN_TYPE{$type} or next;
            my $val = $name->{$type};
            if ($type eq 'iPAddress') {
                $val = length($val) == 4
                    ? sprintf('%vd', $val)
                    : do { (my $hex = sprintf('%*v02X', ':', $val)) =~ s/([[:xdigit:]]{2}):([[:xdigit:]]{2})/$1$2/g; $hex };
            } elsif ($type eq 'directoryName') {
                # directoryName decoded as Name struct by EXPLICIT Name schema
            } elsif ($type eq 'otherName') {
                my ($tagval, $type) = decode_tag_as_string($val->{value});
                if (defined $type) {
                    $val = sprintf('%s;%s:%s', $val->{type}, $type, $tagval);
                } else {
                    $tagval = decode_tag($val->{value}) // encode_base64($val->{value},'') // '<unknown>';
                    $val = sprintf('%s;%s', $val->{type}, $tagval);
                }
                $val =~ s{[\x00-\x1F\x7F]}{X}g;
            }
            push @result, [$san_type, $val];
        }
    }
    return \@result;
}

=head2 get_cert_subject_parts

Merged HashRef of subject DN components (uppercase keys) and SAN entries
(C<SAN_DNS>, C<SAN_EMAIL>, etc.).

=cut

has cert_subject_parts => (
    is       => 'ro',
    isa      => 'HashRef',
    lazy     => 1,
    init_arg => undef,
    reader   => 'get_cert_subject_parts',
    builder  => '_build_cert_subject_parts',
);

sub _build_cert_subject_parts {
    my $self = shift;
    my $hash;

    # convert RDN keys to uppercase
    for my $rdn (keys $self->subject_hash->%*) {
        $hash->{uc($rdn)} = $self->subject_hash->{$rdn};
    }

    # add SAN_* items to hash
    for my $san ($self->get_subject_alt_name->@*) {
        my ($type, $value) = $san->@*;
        my $key = 'SAN_' . uc($type);
        $hash->{$key} = [] unless defined $hash->{$key};
        push @{$hash->{$key}}, $value;
    }
    return $hash;
}

=head2 get_key_usage

Returns a L<OpenXPKI::Crypt::Profile::DTO::KeyUsage> object, or C<undef> if
the keyUsage extension is not present.

=cut

has key_usage => (
    is       => 'ro',
    isa      => 'Maybe[OpenXPKI::Crypt::Profile::DTO::KeyUsage]',
    lazy     => 1,
    init_arg => undef,
    reader   => 'get_key_usage',
    builder  => '_build_key_usage',
);

sub _build_key_usage {
    my $self = shift;
    my $ext = $self->extensions->{'2.5.29.15'} or return undef;
    my $der = $ext->{der};

    # BIT STRING DER: tag(03) + length + unused_bits_count + data_bytes
    # Skip tag (1 byte) + length (1+ bytes) + unused_bits_count (1 byte)
    return undef unless length($der) >= 3;
    my $tag = unpack('C', $der);
    return undef unless $tag == 0x03;  # BIT STRING

    # Determine length byte count
    my $len_byte = unpack('C', substr($der, 1, 1));
    my $data_offset;
    if ($len_byte < 0x80) {
        $data_offset = 3;  # tag(1) + len(1) + unused_bits(1)
    } elsif ($len_byte == 0x81) {
        $data_offset = 4;  # tag(1) + len_marker(1) + len(1) + unused_bits(1)
    } else {
        $data_offset = 5;  # tag(1) + len_marker(1) + len(2) + unused_bits(1)
    }

    my $data = substr($der, $data_offset);
    my @data_bytes = unpack('C*', $data);
    my @bits;
    for my $i (0 .. $#KEY_USAGE_BITS) {
        my $byte_idx = int($i / 8);
        my $bit_pos  = 7 - ($i % 8);  # bit 0 = MSB
        push @bits, $KEY_USAGE_BITS[$i]
            if $byte_idx < @data_bytes && ($data_bytes[$byte_idx] >> $bit_pos) & 1;
    }

    return OpenXPKI::Crypt::Profile::DTO::KeyUsage->new(
        critical => $ext->{critical},
        bits     => \@bits,
    );
}

=head2 get_ext_key_usage

Returns a L<OpenXPKI::Crypt::Profile::DTO::ExtendedKeyUsage> object, or C<undef>.

=cut

has ext_key_usage => (
    is       => 'ro',
    isa      => 'Maybe[OpenXPKI::Crypt::Profile::DTO::ExtendedKeyUsage]',
    lazy     => 1,
    init_arg => undef,
    reader   => 'get_ext_key_usage',
    builder  => '_build_ext_key_usage',
);

sub _build_ext_key_usage {
    my $self = shift;
    my $ext = $self->extensions->{'2.5.29.37'} or return undef;

    my $oids = $self->_asn1('ExtendedKeyUsage')->decode($ext->{der}) or return undef;
    my @usages = map { $EKU_OID{$_} // $_ } @$oids;

    return OpenXPKI::Crypt::Profile::DTO::ExtendedKeyUsage->new(
        critical => $ext->{critical},
        usages   => \@usages,
    );
}

=head2 get_basic_constraints

Returns a L<OpenXPKI::Crypt::Profile::DTO::BasicConstraints> object, or C<undef>.

=cut

has basic_constraints => (
    is       => 'ro',
    isa      => 'Maybe[OpenXPKI::Crypt::Profile::DTO::BasicConstraints]',
    lazy     => 1,
    init_arg => undef,
    reader   => 'get_basic_constraints',
    builder  => '_build_basic_constraints',
);

sub _build_basic_constraints {
    my $self = shift;
    my $ext = $self->extensions->{'2.5.29.19'} or return undef;

    my $decoded = $self->_asn1('BasicConstraints')->decode($ext->{der}) or return undef;

    return OpenXPKI::Crypt::Profile::DTO::BasicConstraints->new(
        critical    => $ext->{critical},
        ca          => ($decoded->{cA} ? 1 : 0),
        path_length => $decoded->{pathLenConstraint},
    );
}

=head2 subject_key_id

Subject Key Identifier as uppercase colon-separated hex string, or C<undef>
if the extension is not present. Consuming classes may wrap this to add
a fallback (e.g., SHA1 of public key).

=cut

has subject_key_id => (
    is       => 'ro',
    isa      => 'Maybe[Str]',
    lazy     => 1,
    init_arg => undef,
    reader   => 'get_subject_key_id',
    builder  => '_build_subject_key_id',
);

sub _build_subject_key_id {
    my $self = shift;
    my $der = $self->_get_ext_der('2.5.29.14') or return undef;
    my $keyid = $self->_asn1('SubjectKeyIdentifier')->decode($der) or return undef;
    return uc join ':', (unpack '(A2)*', unpack 'H*', $keyid);
}

# Fall back to SHA1 of public key if no SubjectKeyIdentifier extension present
around '_build_subject_key_id' => sub {
    my ($orig, $self) = @_;
    return $self->$orig() // $self->get_public_key_hash();
};

=head2 certificate_policies

ArrayRef of hashrefs parsed from the certificatePolicies extension (OID 2.5.29.32).
Each entry has keys C<oid>, and optionally C<cps> (URI string) and C<user_notice> (text).
Returns C<undef> if the extension is not present.

=cut

has certificate_policies => (
    is       => 'ro',
    isa      => 'Maybe[ArrayRef]',
    lazy     => 1,
    init_arg => undef,
    builder  => '_build_certificate_policies',
);

sub _build_certificate_policies {
    my $self = shift;
    my $der = $self->_get_ext_der('2.5.29.32') or return undef;
    return $self->_decode_certificate_policies($der);
}

=head2 get_custom_extension

Returns an ArrayRef of hashrefs with keys C<oid>, C<encoding>, and C<value>
for all Private Enterprise Number (PEN) extensions (OID prefix 1.3.6.1.4.1.).

=cut

has custom_extension => (
    is       => 'ro',
    isa      => 'ArrayRef',
    lazy     => 1,
    init_arg => undef,
    reader   => 'get_custom_extension',
    builder  => '_build_custom_extension',
);

sub _build_custom_extension {
    my $self = shift;
    my @result;
    for my $oid (sort keys %{$self->extensions}) {
        next unless substr($oid, 0, 12) eq '1.3.6.1.4.1.';
        my $der  = $self->extensions->{$oid}{der};
        my $item = { oid => $oid };
        my ($val, $type_name) = decode_tag_as_string($der);
        if (defined $val && ref $val eq '') {
            $item->{encoding} = $type_name;
            $item->{value}    = $val;
        } else {
            $item->{value} = encode_base64($der,'');
        }
        push @result, $item;
    }
    return \@result;
}

=head2 get_pub_key

Raw binary bytes of the subject public key (content of the subjectPublicKey
BIT STRING, without the unused-bits prefix byte).

=cut

has pub_key => (
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    init_arg => undef,
    reader   => 'get_pub_key',
    builder  => '_build_pub_key',
);

sub _build_pub_key {
    my $self = shift;
    my $spki = $self->_raw_spki or return '';
    my $bits = $spki->{subjectPublicKey};
    # Convert::ASN1 decodes BIT STRING as [$data_bytes, $unused_bits_count]
    # where $data_bytes does NOT include the unused-bits-count byte.
    return ref $bits eq 'ARRAY' ? $bits->[0] : substr($bits, 1);
}

=head2 get_spki_der

DER-encoded SubjectPublicKeyInfo. Suitable for loading into C<Crypt::PK::RSA>,
C<Crypt::PK::ECC>, etc.

=cut

sub get_spki_der {
    my $self = shift;
    my $spki = $self->_raw_spki or return undef;
    return $self->_asn1('SubjectPublicKeyInfo')->encode($spki);
}

=head2 get_public_key_alg

Normalized public key algorithm string: C<RSA>, C<EC>, or C<unsupported>.

=cut

has public_key_alg => (
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    init_arg => undef,
    reader   => 'get_public_key_alg',
    builder  => '_build_public_key_alg',
);

sub _build_public_key_alg {
    my $self = shift;
    my $spki = $self->_raw_spki or return 'unsupported';
    my $oid  = $spki->{algorithm}{algorithm} // '';
    return $PUBKEY_ALG{$oid} // 'unsupported';
}

=head2 get_key_params

HashRef with C<key_length> (bits) and optionally C<curve_name> for EC keys.

=cut

has key_params => (
    is       => 'ro',
    isa      => 'HashRef',
    lazy     => 1,
    init_arg => undef,
    reader   => 'get_key_params',
    builder  => '_build_key_params',
);

sub _build_key_params {
    my $self = shift;
    my $alg  = $self->get_public_key_alg;
    my $spki = $self->_raw_spki or return { key_length => 0 };

    # get_pub_key returns the BIT STRING content without the unused-bits-count byte
    my $pub_der = $self->get_pub_key;

    if ($alg eq 'RSA') {
        require Crypt::PK::RSA;
        my $spki_der = $self->get_spki_der or return { key_length => 0 };
        my $pk = eval { Crypt::PK::RSA->new->import_key(\$spki_der) };
        return { key_length => $pk->size * 8 } if $pk;
        # Fallback for RSA-PSS keys: parse RSAPublicKey from raw key bytes
        my $rsa_pub = eval { $self->_asn1('RSAPublicKey')->decode($pub_der) };
        if ($rsa_pub && $rsa_pub->{modulus}) {
            my $bits = length($rsa_pub->{modulus}->as_bin) - 2;  # Math::BigInt bin = '0b...'
            return { key_length => $bits } if $bits > 0;
        }
        return { key_length => 0 };
    }

    if ($alg eq 'EC') {
        my $params_raw = $spki->{algorithm}{parameters};
        my $params_oid = ($params_raw && ref($params_raw) eq '')
            ? $self->_asn1('EcParameters')->decode($params_raw)
            : undef;
        if ($params_oid) {
            if (my $curve = $EC_CURVE{$params_oid}) {
                return { key_length => $curve->[1], curve_name => $curve->[0] };
            }
        }
        # Unknown curve: estimate from pub_der (uncompressed point = 04 + 2*key_bytes)
        my $point_len = length($pub_der);
        return { key_length => (($point_len - 1) / 2) * 8 };
    }

    return { key_length => 0 };
}

=head2 get_signature_digest

Hash algorithm used in the signature (e.g., C<sha256>, C<sha1>), or C<unknown>.

=cut

has signature_digest => (
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    init_arg => undef,
    reader   => 'get_signature_digest',
    builder  => '_build_signature_digest',
);

sub _build_signature_digest {
    my $self  = shift;
    my $oid   = $self->_parsed->{signatureAlgorithm}{algorithm} // '';
    return $SIG_ALG_DIGEST{$oid} // 'unknown';
}

=head2 get_cert_extension_parts

Returns a HashRef of custom extensions (PEN namespace C<1.3.6.1.4.1.*>), keyed by OID.

=cut

has cert_extension_parts => (
    is       => 'ro',
    init_arg => undef,
    isa      => 'HashRef',
    reader   => 'get_cert_extension_parts',
    lazy     => 1,
    default  => sub {
        return { map { ($_->{oid} => $_) } shift->get_custom_extension->@* };
    },
);

=head2 cn

Subject CN value.

=cut

sub cn { shift->subject_hash()->{CN}->[0] }

=head2 check_signature

Returns 1 if the embedded signature is cryptographically valid, 0 otherwise.
For PKCS#10 CSRs this verifies the self-signature using the embedded public key.

=cut

sub check_signature {
    my $self = shift;

    my $alg  = $self->get_public_key_alg;
    my $hash = $self->get_signature_digest;
    return 0 if $alg eq 'unsupported' || $hash eq 'unknown';

    my $tbs_der  = $self->_tbs_der;
    my $spki_der = $self->_asn1('SubjectPublicKeyInfo')->encode($self->_raw_spki)
        or return 0;

    my $sig_bits = $self->_parsed->{signature};
    # Convert::ASN1 returns BIT STRING as [$data, $unused_bits] where $data has
    # the unused-bits-count byte already stripped; for raw strings it's still present.
    my $sig = ref $sig_bits eq 'ARRAY' ? $sig_bits->[0] : substr($sig_bits, 1);

    if ($alg eq 'RSA') {
        require Crypt::PK::RSA;
        my $pk = eval { Crypt::PK::RSA->new->import_key(\$spki_der) };
        # Fallback for RSA-PSS keys whose SPKI uses a non-standard OID
        unless ($pk) {
            my $raw_pub = $self->get_pub_key;
            $pk = eval { Crypt::PK::RSA->new->import_key(\$raw_pub) };
        }
        return 0 unless $pk;
        my ($padding, $hash_name, @extra);
        if ($hash eq 'pss') {
            my ($pss_hash, $salt_len) = $self->_pss_params;
            $padding   = 'pss';
            $hash_name = $pss_hash;
            push @extra, $salt_len;
        } else {
            $padding   = 'v1.5';
            $hash_name = uc($hash);
        }
        return eval { $pk->verify_message($sig, $tbs_der, $hash_name, $padding, @extra) } ? 1 : 0;
    }
    if ($alg eq 'EC') {
        require Crypt::PK::ECC;
        my $pk = eval { Crypt::PK::ECC->new->import_key(\$spki_der) }
            or do { warn "EC key import failed: $@"; return 0 };
        return eval { $pk->verify_message($sig, $tbs_der, uc($hash)) } ? 1 : 0;
    }

    return 0;
}

# Extract the TBS (to-be-signed) DER from the raw outer structure.
# For Certificate: tbsCertificate; for CertificationRequest: certificationRequestInfo.
# Extracts the first inner element verbatim so re-encoding artefacts can't affect
# the cryptographic verification.
sub _tbs_der {
    my $self = shift;
    my $raw  = $self->data;
    my ($outer_tag_b)           = asn_decode_tag($raw);
    my ($outer_len_b)           = asn_decode_length(substr($raw, $outer_tag_b));
    my $inner                   = substr($raw, $outer_tag_b + $outer_len_b);
    my ($tbs_tag_b)             = asn_decode_tag($inner);
    my ($tbs_len_b, $tbs_len)   = asn_decode_length(substr($inner, $tbs_tag_b));
    return substr($inner, 0, $tbs_tag_b + $tbs_len_b + $tbs_len);
}

# Extract hash name and salt length from RSASSA-PSS-params DER.
# RFC 4055 defaults: SHA-1, salt length 20.
sub _pss_params {
    my $self = shift;
    my $params_der = $self->_parsed->{signatureAlgorithm}{parameters}
        or return ('SHA1', 20);
    my $pss = eval { $self->_asn1('RsassaPssParams')->decode($params_der) }
        or return ('SHA1', 20);
    my $hash = do {
        my $oid = $pss->{hashAlgorithm}{algorithm} // '';
        $HASH_ALG_OID{$oid} // 'SHA1';
    };
    my $salt = $pss->{saltLength} // 20;
    return ($hash, $salt);
}

sub _pss_hash_name { ($_[0]->_pss_params)[0] }

=head2 get_extension_value (name_or_oid)

Returns the value of a certificate or CSR extension. When called with a known
name (e.g. C<certificatePolicies>, C<certificateTemplate>), the ASN.1 value is
decoded and returned as a structured object, string, or arrayref. When called
with an OID string, the raw DER bytes are returned unchanged.

Returns C<undef> if the extension is not present or the name is unknown.

=cut

sub get_extension_value {
    my ($self, $name_or_oid) = @_;
    my $is_oid = ($name_or_oid =~ /^\d+(\.\d+)+$/);
    my $oid    = $is_oid ? $name_or_oid : ($KNOWN_EXT{$name_or_oid} // return undef);
    my $der    = $self->_get_ext_der($oid) // return undef;
    return $is_oid ? $der : $self->_decode_ext($oid, $der);
}

sub _decode_attr {
    my ($self, $oid, $values) = @_;
    my $der = ref $values eq 'ARRAY' ? $values->[0] : $values;
    return undef unless defined $der;

    # PKCS#9 string attributes — DirectoryString CHOICE
    if ($oid eq '1.2.840.113549.1.9.7'
     || $oid eq '1.2.840.113549.1.9.2'
     || $oid eq '1.2.840.113549.1.9.8') {
        return (decode_tag_as_string($der))[0];
    }

    return $self->_decode_known_der($oid, $der);
}

sub _decode_ext {
    my ($self, $oid, $der) = @_;

    # certificatePolicies — use cached lazy attr
    if ($oid eq '2.5.29.32') {
        return $self->certificate_policies;
    }
    # subjectInfoAccess — same structure as AuthorityInfoAccess
    if ($oid eq '1.3.6.1.5.5.7.1.11') {
        my $decoded = $self->_asn1('AuthorityInfoAccess')->decode($der) or return {};
        my %result;
        for my $desc (@$decoded) {
            next unless $desc->{accessLocation}{uniformResourceIdentifier};
            push @{$result{$desc->{accessMethod}}}, $desc->{accessLocation}{uniformResourceIdentifier};
        }
        return \%result;
    }
    return $self->_decode_known_der($oid, $der);
}

sub _decode_known_der {
    my ($self, $oid, $der) = @_;
    return $self->_decode_certificate_template($der) if $oid eq '1.3.6.1.4.1.311.21.7';
    return (decode_tag_as_string($der))[0]           if $oid eq '1.3.6.1.4.1.311.20.2';
    return undef;
}

sub _decode_certificate_template {
    my $self = shift;
    my $der  = shift;

    my $decoded = $self->_asn1('CertificateTemplate')->decode($der) or return undef;
    return OpenXPKI::Crypt::Profile::DTO::ExtCertificateTemplate->new(
        template_id   => $decoded->{templateID},
        major_version => $decoded->{templateMajorVersion},
        minor_version => $decoded->{templateMinorVersion},
    );
}

sub _decode_certificate_policies {
    my ($self, $der) = @_;
    my $decoded = $self->_asn1('CertificatePolicies')->decode($der) or return [];
    my @result;
    for my $policy (@$decoded) {
        my $entry = { oid => $policy->{policyIdentifier} };
        for my $qual (@{$policy->{policyQualifiers} // []}) {
            my $qid = $qual->{policyQualifierId};
            my $raw = $qual->{qualifier} or next;
            if ($qid eq '1.3.6.1.5.5.7.2.1') {
                $entry->{cps} = $self->_asn1('CPSuri')->decode($raw);
            } elsif ($qid eq '1.3.6.1.5.5.7.2.2') {
                my $notice = $self->_asn1('UserNotice')->decode($raw) or next;
                $entry->{user_notice} = (values %{$notice->{explicitText}})[0]
                    if $notice->{explicitText};
            }
        }
        push @result, $entry;
    }
    return \@result;
}

1;
