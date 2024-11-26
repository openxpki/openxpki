package OpenXPKI::Crypt::PKCS7;
use OpenXPKI -class;

with 'OpenXPKI::Role::IssuerSerial';

use MIME::Base64;
use Convert::ASN1 ':tag';
use Exporter qw( import );
use OpenXPKI::Crypt::DN;
use OpenXPKI::Crypt::X509;

# Symbols to export by default
# (we avoid Moose::Exporter's import magic because that switches on all warnings again)
our @EXPORT = qw( decode_tag encode_tag find_oid );

our %oids = (
    # pkcs7 data types
    '1.2.840.113549.1.7.0' => 'module',
    '1.2.840.113549.1.7.1' => 'id-data',
    '1.2.840.113549.1.7.2' => 'signedData',
    '1.2.840.113549.1.7.3' => 'envelopedData',
    '1.2.840.113549.1.7.4' => 'signedAndEnvelopedData',
    '1.2.840.113549.1.7.5' => 'digestedData',
    '1.2.840.113549.1.7.6' => 'encryptedData',
    '1.2.840.113549.1.7.7' => 'dataWithAttributes',
    '1.2.840.113549.1.7.8' => 'encryptedPrivateKeyInfo',

    # attribute extension
    '2.16.840.1.113733.1.9.2' => 'messageType',
    '2.16.840.1.113733.1.9.3' => 'pkiStatus',
    '2.16.840.1.113733.1.9.4' => 'failInfo',
    '2.16.840.1.113733.1.9.5' => 'senderNonce',
    '2.16.840.1.113733.1.9.6' => 'recipientNonce',
    '2.16.840.1.113733.1.9.7' => 'transactionID',
    '2.16.840.1.113733.1.9.8' => 'extensionReq',
    # used in SCEP/CMS, from PKCS#9
    '1.2.840.113549.1.9.3'    => 'contentType',
    '1.2.840.113549.1.9.4'    => 'messageDigest',
    '1.2.840.113549.1.9.5'    => 'signingTime',
    '1.2.840.113549.1.9.52'   => 'id-aa-CMSAlgorithmProtection',

    # signature digests
    '1.2.840.113549.2.5' => 'md5',
    '1.3.14.3.2.26' => 'sha1',
    '2.16.840.1.101.3.4.2.1' => 'sha256',
    '2.16.840.1.101.3.4.2.2' => 'sha384',
    '2.16.840.1.101.3.4.2.3' => 'sha512',
    '2.16.840.1.101.3.4.2.4' => 'sha224',

    # signature algorithms
    '1.2.840.10045.4.1'   => 'ecdsa-with-sha1',
    '1.2.840.10045.4.3.1' => 'ecdsa-with-sha224',
    '1.2.840.10045.4.3.2' => 'ecdsa-with-sha256',
    '1.2.840.10045.4.3.3' => 'ecdsa-with-sha384',
    '1.2.840.10045.4.3.4' => 'ecdsa-with-sha512',

    # encryption algorithms
    '1.3.14.3.2.7' => 'des-cbc',
    '1.2.840.113549.3.7' => '3des-cbc',
    '2.16.840.1.101.3.4.1.2' => 'aes-128-cbc',
    '2.16.840.1.101.3.4.1.22' => 'aes-192-cbc',
    '2.16.840.1.101.3.4.1.42' => 'aes-256-cbc',
    '1.2.840.113549.1.9.16.3.18' => 'chacha20-poly1305',

    # encryption key types
    '1.2.840.113549.1.1.1' => 'rsaEncryption',
    '1.2.840.113549.1.1.7' => 'rsaesOaep',
    '1.2.840.10045.2.1' => 'ecPublicKey',
    '1.3.101.110' => 'curve25519',
    '1.3.101.112' => 'ed25519',

);

our $schema = "
    PKCS7TypeOnlyInfo ::= SEQUENCE {
        contentType ContentType,
        content     ANY
    }

    PKCS7ContentInfoSignedData ::= SEQUENCE {
        contentType ContentType,
        content     [0] EXPLICIT SignedData OPTIONAL
    }

    PKCS7ContentInfoEnvelopedData ::= SEQUENCE {
        contentType ContentType,
        content     [0] EXPLICIT EnvelopedData OPTIONAL
    }

    ContentType ::= OBJECT IDENTIFIER

    EnvelopedData ::= SEQUENCE {
        version         INTEGER,
        recipientInfos  RecipientInfos,
        contentInfo EncryptedContentInfo
    }

    RecipientInfos ::= CHOICE {
        riSet       SET OF RecipientInfo,
        riSequence  SEQUENCE OF RecipientInfo
    }

    EncryptedContentInfo ::= SEQUENCE {
        contentType ContentType,
        contentEncryptionAlgorithm AlgorithmIdentifier,
        content ANY
    }

    EncryptedContent ::= OCTET STRING

    RecipientInfo ::= SEQUENCE {
        version                 INTEGER,
        issuerAndSerialNumber   IssuerAndSerialNumber,
        keyEncryptionAlgorithm  AlgorithmIdentifier,
        encryptedKey            EncryptedKey
    }

    EncryptedKey ::= OCTET STRING

    SignedData ::= SEQUENCE {
        version             INTEGER,
        digestAlgorithms    DigestAlgorithmIdentifiers,
        contentInfo         SignedContentInfo,
        certificates        CHOICE {
            certSet         [0] IMPLICIT ExtendedCertificatesAndCertificates,
            certSequence    [2] IMPLICIT Certificates
        },
        crls                [1] IMPLICIT CertificateRevocationLists OPTIONAL,
        signerInfos     SignerInfos
    }

    SignedContentInfo ::= SEQUENCE {
        contentType ContentType,
        content     [0] EXPLICIT Data OPTIONAL
    }

    Data ::= ANY

    DigestAlgorithmIdentifiers ::= CHOICE {
        daSet           SET OF AlgorithmIdentifier,
        daSequence      SEQUENCE OF AlgorithmIdentifier
    }

    --
    -- Certificates and certificate lists
    --
    ExtendedCertificatesAndCertificates ::= SET OF ExtendedCertificateOrCertificate

    ExtendedCertificateOrCertificate ::= CHOICE {
      certificate       Certificate,                -- X.509
      extendedCertificate   [0] IMPLICIT ExtendedCertificate    -- PKCS#6
    }

    ExtendedCertificate ::= Certificate -- cheating

    Certificates ::= SEQUENCE OF Certificate

    CertificateRevocationLists ::= SET OF ANY

    Certificate ::= ANY

    --
    -- Signer information
    --
    SignerInfos ::= CHOICE {
        siSet       SET OF SignerInfo,
        siSequence  SEQUENCE OF SignerInfo
    }

    SignerInfo ::= SEQUENCE {
        version                     INTEGER,
        sid                         SignerIdentifier, -- CMS variant, not PKCS#7
        digestAlgorithm             AlgorithmIdentifier,
        authenticatedAttributes     AuthenticatedAttributesChoice OPTIONAL,
        digestEncryptionAlgorithm   AlgorithmIdentifier,
        encryptedDigest             EncryptedDigest,
        unauthenticatedAttributes   UnauthenticatedAttributesChoice OPTIONAL
    }

    AuthenticatedAttributesChoice ::= CHOICE {
        aaSet       [0] IMPLICIT SetOfAuthenticatedAttribute,
        aaSequence  [2] EXPLICIT SEQUENCE OF AuthenticatedAttribute
            -- Explicit because easier to compute digest on
            -- sequence of attributes and then reuse encoded
            -- sequence in aaSequence.
    }

    UnauthenticatedAttributesChoice ::= CHOICE {
        uaSet       [1] IMPLICIT SET OF UnauthenticatedAttribute,
        uaSequence  [3] IMPLICIT SEQUENCE OF UnauthenticatedAttribute
    }

    SignerIdentifier ::= CHOICE {
        -- RFC5652 sec 5.3
        issuerAndSerialNumber IssuerAndSerialNumber,
        subjectKeyIdentifier [0] IMPLICIT SubjectKeyIdentifier
    }

    IssuerAndSerialNumber ::= SEQUENCE {
        issuer          Name,
        serialNumber    CertificateSerialNumber
    }

    CertificateSerialNumber ::= INTEGER

    SubjectKeyIdentifier ::= OCTET STRING

    SetOfAuthenticatedAttribute ::= SET OF AuthenticatedAttribute

    AuthenticatedAttribute ::= SEQUENCE {
        type            OBJECT IDENTIFIER,
        values          SET OF ANY
    }

    UnauthenticatedAttribute ::= SEQUENCE {
        type            OBJECT IDENTIFIER,
        values          SET OF ANY
    }

    AlgorithmIdentifier ::= SEQUENCE {
        algorithm       OBJECT IDENTIFIER,
        parameters      ANY OPTIONAL
    }

    EncryptedDigest ::= OCTET STRING

    ---
    --- X.500 Name
    ---
    Name ::= SEQUENCE OF RelativeDistinguishedName

    RelativeDistinguishedName ::= SET OF AttributeTypeAndValue

    AttributeTypeAndValue ::= SEQUENCE {
        type  OBJECT IDENTIFIER,
        value DirectoryString
    }

    DirectoryString ::= CHOICE {
      teletexString   TeletexString,
      printableString PrintableString,
      bmpString       BMPString,
      universalString UniversalString,
      utf8String      UTF8String,
      ia5String       IA5String,
      integer         INTEGER
    }
";

has data => (
    is => 'ro',
    required => 1,
    isa => 'Str',
);

has pem => (
    is => 'ro',
    required => 0,
    isa => 'Str',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $pem = encode_base64($self->data(), '');
        $pem =~ s{ (.{64}) }{$1\n}xmsg;
        chomp $pem;
        return "-----BEGIN PKCS7-----\n$pem\n-----END PKCS7-----";
    },
);

has _asn1 => (
    is => 'ro',
    required => 1,
    isa => 'Convert::ASN1',
);

has parsed => (
    is => 'ro',
    required => 1,
    isa => 'HashRef',
);

has type => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $oid = $self->parsed()->{contentType};
        return $oids{$oid} || $oid;
    }
);

has payload => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    builder => '__build_payload',
);

has envelope => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    builder => '__build_envelope',
);

has certificates => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy => 1,
    builder => '__build_certlist',
);

has recipients => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy => 1,
    builder => '__build_rcptlist',
);


around BUILDARGS => sub {

    my $orig  = shift;
    my $class = shift;
    my $data = shift;

    my $asn = Convert::ASN1->new;
    $asn->prepare($schema) or die( "Internal error in " . __PACKAGE__ . ": " . $asn->error );

    if ($data =~ m{\A(?!\x06)-----BEGIN\ ([^-]+)-----\s*(.*)\s*-----END\ \1-----}xms) {
        ##! 8: 'PEM data - decoding'
        $data = decode_base64($2);
    }

    ##! 64: 'Incoming data ' . encode_base64($data,'');
    my $parser = $asn->find('PKCS7TypeOnlyInfo');
    my $type = $parser->decode( $data ) or
      die( "decode: " . $parser->error .
           "Cannot handle input or missing ASN.1 definitions" );

    # signedData
    if ($type->{contentType} eq '1.2.840.113549.1.7.2') {
        ##! 32: 'Signed data'
        $parser = $asn->find('PKCS7ContentInfoSignedData');
    } elsif ($type->{contentType} eq '1.2.840.113549.1.7.3') {
        ##! 32: 'Enveloped data'
        $parser = $asn->find('PKCS7ContentInfoEnvelopedData');
    }

    my $content = $parser->decode( $data ) or
        die( "decode: " . $parser->error .
           "Cannot handle input or missing ASN.1 definitions" );

    return $class->$orig( data => $data, _asn1 => $asn, parsed => $content );

};

sub __build_envelope {

    my $self = shift;
    if ($self->type() eq 'signedData') {
        return $self->__build_envelope_signed_data();
    }
    if ($self->type() eq 'envelopedData') {
        return $self->__build_envelope_enveloped_data();
    }
    return;
}

sub __build_envelope_signed_data {

    my $self = shift;
    my $cc = $self->parsed()->{content};
    my $si = $cc->{signerInfos}->{siSequence}->[0] || $cc->{signerInfos}->{siSet}->[0] ;

    my $digest_oid = $si->{digestAlgorithm}->{algorithm};
    my $sig_oid = $si->{digestEncryptionAlgorithm}->{algorithm};
    my $mapattrib = sub {
        my $attr = shift;
        my %attrib = map {
            my $t = $oids{$_->{type}} || $_->{type};
            my $v = (@{$_->{values}} > 1) ? $_->{values} : decode_tag($_->{values}->[0]);
            $t => $v;
        } @{$attr};
        return \%attrib;
    };

    my $aa = $si->{authenticatedAttributes}->{aaSet} || $si->{authenticatedAttributes}->{aaSequence};
    my $attrib = $mapattrib->($aa) if ($aa);

    my $ua = $si->{unauthenticatedAttributes}->{uaSet} || $si->{unauthenticatedAttributes}->{uaSequence};
    my $uattrib = $mapattrib->($ua) if ($ua);

    return {
        digest_alg => $oids{$digest_oid} || $digest_oid,
        sig_alg =>  $oids{$sig_oid} || $sig_oid,
        signature => $si->{encryptedDigest},
        signer => iasn_from_hash( $si->{sid}->{issuerAndSerialNumber} ),
        authAttr => $attrib,
        unauthAttr => $uattrib,
    };

}

sub __build_envelope_enveloped_data {

    my $self = shift;
    my $cc = $self->parsed()->{content};

    my $enc_oid = $cc->{contentInfo}->{contentEncryptionAlgorithm}->{algorithm};
    my $ri = $cc->{'recipientInfos'}->{riSet} || $cc->{'recipientInfos'}->{riSequence};
    my %key_enc_oid = map { $_->{keyEncryptionAlgorithm}->{algorithm} => 1 } @{$ri};

    return {
        enc_alg => $oids{$enc_oid} || $enc_oid,
        key_alg => [ map { $oids{$_} || $_ } keys %key_enc_oid ],
        recipient => $self->recipients()
    };

}

sub __build_certlist {
    my $self = shift;
    my $cc = $self->parsed()->{content}->{certificates};
    # TODO: we need to verify that extended certificates can be parsed by this class
    my $certs = $cc->{certSet}|| $cc->{certSequence};
    return [ map { OpenXPKI::Crypt::X509->new( $_->{certificate} ) } @{$certs} ];
}

sub __build_rcptlist {
    my $self = shift;
    my $ri = $self->parsed()->{content}->{'recipientInfos'}->{riSet} || $self->parsed()->{content}->{'recipientInfos'}->{riSequence};
    return [ map {
        iasn_from_hash( $_->{issuerAndSerialNumber} );
    } @{$ri} ];
}

sub __build_payload {
    my $self = shift;
    return decode_tag( $self->parsed()->{content}->{contentInfo}->{content} );
}

sub find_oid {
    my $name = shift;
    my %rmap = reverse %OpenXPKI::Crypt::PKCS7::oids;
    return $rmap{$name} || $name;
}

# static methods that are also exported
sub decode_tag {

    my $raw = shift;

    # return undef if we dont get any data
    return unless($raw);

    # the raw content starts with tag and length as bytes sequences
    # the length of each sequence is itself encoded in the first bit
    # tagbytes is the number of bytes that are used to encode the tag
    my ($tagbytes, $tag) = asn_decode_tag($raw);

    # length starts after the tag so we need to use tagbytes as offset
    my ($lengthbytes, $length) = asn_decode_length(substr($raw, $tagbytes));

    # offset at the head of the first segment
    my $offset = $tagbytes + $lengthbytes;

    # return directly if it this is not a constructed tag (Bit6 is set)
    # we are not interessted in the actual values of tag and length but
    # just strip the header of the raw buffer
    return substr($raw, $offset) unless ($tag & 0x20);
    # constructed mode means that the buffer contains multiple segments
    # where each one is an encoded tag with tag, length, value
    # [[tag, length][seg1][seg2][seg3]...
    $tag &= 0xDF;

    # inifinite length encoding - the value has two null bytes at the end
    # the proper size of the raw value is already handled by the asn1 parser
    # the while loop is a safety net, itag == 0 should be seen in any case
    $length = length($raw)-2 if ($length == -1);
    my $buffer;
    while ($offset < $length) {
        # read the tag header from the segment at offset
        my ($tagbytes, $itag) = asn_decode_tag(substr($raw, $offset));

        # the tag contains a constructed structure we do not want to parse
        # so we return the binary tag data without any conversions
        if (($itag & 0x20 && !$buffer)) {
            $buffer = $raw;
            last;
        }

        last if ($itag == 0);
        # The inner and outer tags must be the same - it might be possible
        # to have nested constructed tags but we dont want to support this now
        # tag == 128 is a context specific outer tag with no lower tag number
        die sprintf("Inner (%02d) and outer (%02d) tag do not match!?", $itag, $tag)
            unless($tag == 128 || $itag == $tag);

        # set offset to the right end of the tag header of the current segment
        $offset += $tagbytes;
        # ...and decode the length header of the segment
        my ($lengthbytes, $length) = asn_decode_length(substr($raw, $offset));
        # forward offset beyond the length header to the left end of the value
        $offset += $lengthbytes;

        # An infinite lenght should not be possible here but lets check it
        die "Infinite length found in constructed item" if ($length == -1);
        $buffer .= substr($raw, $offset, $length);
        $offset += $length;
    }
    return $buffer;
}

=head2 encode_tag

Takes a value and a class and encodes value as ASN1 tag. The class can
be any valid class number (integer) or a class name from the following
list. OIDs can be given as byte string or in dotted decimal notation.

=over

=item INTEGER

=item BIT STRING

=item OCTET STRING

=item NULL

=item OBJECT IDENTIFIER

=item UTF8String

=item SEQUENCE

=item SET

=item PrintableString

=item T61String

=item IA5String

=item UTCTime

=back

=cut

sub encode_tag {
    my $value = shift;
    my $class = shift || 4;

    my %tagmap = (
        'INTEGER' => 2,
        'BIT STRING' => 3,
        'OCTET STRING' => 4,
        'NULL' => 5,
        'OBJECT IDENTIFIER' => 6,
        'OID' => 6,
        'UTF8String' => 12,
        'SEQUENCE' => 16,
        'SET' => 17,
        'PrintableString' => 19,
        'T61String' => 20,
        'IA5String' => 22,
        'UTCTime' => 23
    );

    if ($class !~ m{\A\d+\z}) {
        $class = $tagmap{$class} || die "Invalid class name given";
    }

    # object identifier in dottet decimal notation
    if ($class == 6 && $value =~ m{\A\d+\.}) {
        # this code is borrowed from Convert::BER
        my @data = ($value =~ /(\d+)/g);
        # the first two digits are combined into one character
        my $first = $data[1] + ($data[0] * 40);
        splice(@data,0,2,$first);
        # values >128 are encoded with variable length where each character
        # holds seven bits of value, the end of the digit is encoded with
        # the last character having MSB=0 and all others have MSB=1
        # Example: 840 = 110|1001000 =  10000110 + 01001000
        @data = map {
            my @d = ($_);
            if($_ >= 0x80) {
                @d = ();
                my $v = 0 | $_; # unsigned
                while($v) {
                unshift(@d, 0x80 | ($v & 0x7f));
                $v >>= 7;
                }
                $d[-1] &= 0x7f;
            }
            @d;
        } @data;
        $value = CORE::pack("C*", @data);
    }

    return asn_encode_tag($class).asn_encode_length(length($value)).$value;
}

__PACKAGE__->meta->make_immutable;

__END__;
