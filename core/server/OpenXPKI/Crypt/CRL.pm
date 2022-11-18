package OpenXPKI::Crypt::CRL;

use Moose;

# some code imported from Crypt::X509::CRL

use English;

use Convert::ASN1;
use MIME::Base64;

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
        return "-----BEGIN X509 CRL-----\n$pem\n-----END X509 CRL-----";
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

has issuer => (
    is => 'rw',
    required => 0,
    isa => 'Str',
    reader => 'get_issuer',
    lazy => 1,
    builder => '__issuer_dn',
);

has version => (
    is => 'ro',
    isa => 'Int',
    required => 0,
    lazy => 1,
    default => sub {
        my $self = shift;
        my $version = $self->parsed()->{'tbsCertList'}->{'version'};
        # version is an ASN integer with 0x00 = v1
        return defined $version ? $version+1 : 0;
    }
);

has authority_key_id => (
    is => 'rw',
    required => 0,
    isa => 'Str|Undef',
    reader => 'get_authority_key_id',
    lazy => 1,
    builder => '__authority_key_id',
);

has crl_number => (
    is => 'ro',
    isa => 'Int|Undef',
    required => 0,
    lazy => 1,
    builder => '__crl_number',
);

has last_update => (
    is => 'ro',
    isa => 'Int',
    required => 0,
    lazy => 1,
    default => sub {
        my $self = shift;
        my $node = $self->parsed()->{'tbsCertList'}->{'thisUpdate'};
        return $node->{'utcTime'} // $node->{'generalTime'} // 0;
    }
);

has next_update => (
    is => 'ro',
    isa => 'Int',
    required => 0,
    lazy => 1,
    default => sub {
        my $self = shift;
        my $node = $self->parsed()->{'tbsCertList'}->{'nextUpdate'};
        return $node->{'utcTime'} // $node->{'generalTime'} // 0;
    }
);

has itemcnt => (
    is => 'ro',
    isa => 'Int',
    required => 0,
    lazy => 1,
    default => sub {
        my $self = shift;
        my $items = $self->parsed()->{'tbsCertList'}->{'revokedCertificates'};
        # items is undef if no certificates are on the CRL
        return $items ? scalar @{$items} : 0;
    },
);

has items => (
    is => 'ro',
    isa => 'HashRef',
    required => 0,
    lazy => 1,
    builder => '__revoked_certs_list',
);

has oidmap => (
    is => 'rw',
    isa => 'HashRef',
    required => 0,
    lazy => 1,
    default => sub { return {
        "2.5.4.3" => "CN",
        "2.5.4.6" => "C",
        "2.5.4.7" => "L",
        "2.5.4.8" => "ST",
        "2.5.4.10" => "O",
        "2.5.4.11" => "OU",
        "1.2.840.113549.1.9.1" => "emailAddress",
        "0.9.2342.19200300.100.1.1" => "UID",
        "0.9.2342.19200300.100.1.25" => "DC",
    }}
);

has crl_reason => (
    is => 'ro',
    isa => 'ArrayRef',
    required => 0,
    lazy => 1,
    default => sub {
        return [qw(unspecified keyCompromise cACompromise affiliationChanged superseded
                cessationOfOperation certificateHold removeFromCRL privilegeWithdrawn
                aACompromise)];
    }
);

around BUILDARGS => sub {

    my $orig  = shift;
    my $class = shift;
    my $data = shift;

    my $schema = "
   Attribute ::= SEQUENCE {
        type                    AttributeType,
        values                  SET OF AttributeValue
                -- at least one value is required --
        }

   AttributeType ::= OBJECT IDENTIFIER

   AttributeValue ::= DirectoryString  --ANY

   AttributeTypeAndValue ::= SEQUENCE {
        type                    AttributeType,
        value                   AttributeValue
        }

-- naming data types --

   Name ::= CHOICE { -- only one possibility for now
        rdnSequence             RDNSequence
        }

   RDNSequence ::= SEQUENCE OF RelativeDistinguishedName

   RelativeDistinguishedName ::=
        SET OF AttributeTypeAndValue  --SET SIZE (1 .. MAX) OF


-- Directory string type --

   DirectoryString ::= CHOICE {
        teletexString           TeletexString,  --(SIZE (1..MAX)),
        printableString         PrintableString,  --(SIZE (1..MAX)),
        bmpString               BMPString,  --(SIZE (1..MAX)),
        universalString         UniversalString,  --(SIZE (1..MAX)),
        utf8String              UTF8String,  --(SIZE (1..MAX)),
        ia5String               IA5String,  --added for EmailAddress,
        integer                 INTEGER
        }


-- CRL specific structures begin here

   CertificateList ::= SEQUENCE  {
        tbsCertList          TBSCertList,
        signatureAlgorithm   AlgorithmIdentifier,
        signatureValue       BIT STRING
        }


   TBSCertList ::= SEQUENCE  {
        version                 Version OPTIONAL,  -- if present, MUST be v2
        signature               AlgorithmIdentifier,
        issuer                  Name,
        thisUpdate              Time,
        nextUpdate              Time OPTIONAL,

        revokedCertificates     RevokedCertificatesCount OPTIONAL,
        crlExtensions           [0]  EXPLICIT Extensions OPTIONAL
        }

  -- create a sequence to count the items without parsing them
   RevokedCertificatesCount ::= SEQUENCE OF ANY

   RevokedCertificates ::= SEQUENCE OF RevokedCert

   RevokedCert ::= SEQUENCE  {
        userCertificate         CertificateSerialNumber,
        revocationDate          Time,
        crlEntryExtensions      Extensions OPTIONAL
        }

   -- Version, Time, CertificateSerialNumber, and Extensions
   -- are all defined in the ASN.1 in section 4.1

   -- AlgorithmIdentifier is defined in section 4.1.1.2

   Version ::= INTEGER  --{  v1(0), v2(1), v3(2)  }

   CertificateSerialNumber ::= INTEGER

   AlgorithmIdentifier ::= SEQUENCE {
        algorithm               OBJECT IDENTIFIER,
        parameters              ANY OPTIONAL
        }


   Name ::= CHOICE { -- only one possibility for now
        rdnSequence             RDNSequence
        }


   Time ::= CHOICE {
        utcTime                 UTCTime,
        generalTime             GeneralizedTime
        }

--extensions

   Extensions ::= SEQUENCE OF Extension  --SIZE (1..MAX) OF Extension

   Extension ::= SEQUENCE {
        extnID                  OBJECT IDENTIFIER,
        critical                BOOLEAN OPTIONAL,  --DEFAULT FALSE,
        extnValue               OCTET STRING
        }

   AuthorityKeyIdentifier ::= SEQUENCE {
      keyIdentifier             [0] KeyIdentifier            OPTIONAL,
      authorityCertIssuer       [1] GeneralNames             OPTIONAL,
      authorityCertSerialNumber [2] CertificateSerialNumber  OPTIONAL }
    -- authorityCertIssuer and authorityCertSerialNumber shall both
    -- be present or both be absent

   KeyIdentifier ::= OCTET STRING

   GeneralNames ::= SEQUENCE OF GeneralName

   GeneralName ::= CHOICE {
     otherName                       [0]     AnotherName,
     rfc822Name                      [1]     IA5String,
     dNSName                         [2]     IA5String,
     x400Address                     [3]     ANY, --ORAddress,
     directoryName                   [4]     Name,
     ediPartyName                    [5]     EDIPartyName,
     uniformResourceIdentifier       [6]     IA5String,
     iPAddress                       [7]     OCTET STRING,
     registeredID                    [8]     OBJECT IDENTIFIER }

-- AnotherName replaces OTHER-NAME ::= TYPE-IDENTIFIER, as
-- TYPE-IDENTIFIER is not supported in the 88 ASN.1 syntax

   AnotherName ::= SEQUENCE {
     type    OBJECT IDENTIFIER,
     value      [0] EXPLICIT ANY } --DEFINED BY type-id }

   EDIPartyName ::= SEQUENCE {
     nameAssigner            [0]     DirectoryString OPTIONAL,
     partyName               [1]     DirectoryString }

-- id-ce-issuingDistributionPoint OBJECT IDENTIFIER ::= { id-ce 28 }

   issuingDistributionPoint ::= SEQUENCE {
        distributionPoint          [0] DistributionPointName OPTIONAL,
        onlyContainsUserCerts      [1] BOOLEAN OPTIONAL,  --DEFAULT FALSE,
        onlyContainsCACerts        [2] BOOLEAN OPTIONAL,  --DEFAULT FALSE,
        onlySomeReasons            [3] ReasonFlags OPTIONAL,
        indirectCRL                [4] BOOLEAN OPTIONAL,  --DEFAULT FALSE,
        onlyContainsAttributeCerts [5] BOOLEAN OPTIONAL   --DEFAULT FALSE
        }

   DistributionPointName ::= CHOICE {
     fullName                [0]     GeneralNames,
     nameRelativeToCRLIssuer [1]     RelativeDistinguishedName }

   ReasonFlags ::= BIT STRING --{
   --     unused                  (0),
   --     keyCompromise           (1),
   --     cACompromise            (2),
   --     affiliationChanged      (3),
   --     superseded              (4),
   --     cessationOfOperation    (5),
   --     certificateHold         (6),
   --     privilegeWithdrawn      (7),
   --     aACompromise            (8) }

-- id-ce-cRLNumber OBJECT IDENTIFIER ::= { id-ce 20 }

   cRLNumber ::= INTEGER --(0..MAX)

-- id-ce-cRLReason OBJECT IDENTIFIER ::= { id-ce 21 }

   -- reasonCode ::= { CRLReason }

   CRLReason ::= ENUMERATED {
        unspecified             (0),
        keyCompromise           (1),
        cACompromise            (2),
        affiliationChanged      (3),
        superseded              (4),
        cessationOfOperation    (5),
        certificateHold         (6),
        removeFromCRL           (8),
        privilegeWithdrawn      (9),
        aACompromise           (10) }

-- id-ce-holdInstructionCode OBJECT IDENTIFIER ::= { id-ce 23 }

   holdInstructionCode ::= OBJECT IDENTIFIER

-- holdInstruction    OBJECT IDENTIFIER ::=
--                  { iso(1) member-body(2) us(840) x9-57(10040) 2 }
--
-- id-holdinstruction-none   OBJECT IDENTIFIER ::= {holdInstruction 1}
-- id-holdinstruction-callissuer
--                           OBJECT IDENTIFIER ::= {holdInstruction 2}
-- id-holdinstruction-reject OBJECT IDENTIFIER ::= {holdInstruction 3}

-- id-ce-invalidityDate OBJECT IDENTIFIER ::= { id-ce 24 }

   invalidityDate ::=  GeneralizedTime

-- id-ce-certificateIssuer   OBJECT IDENTIFIER ::= { id-ce 29 }

   certificateIssuer ::=     GeneralNames
    ";

    my $asn = Convert::ASN1->new;
    $asn->prepare($schema) or die( "Internal error in " . __PACKAGE__ . ": " . $asn->error );
    my $parser = $asn->find('CertificateList');

    if ($data =~ m{-----BEGIN\ ([^-]+)-----\s*(.*)\s*-----END\ \1-----}xms) {
        $data = decode_base64($2);
    }

    my $top = $parser->decode( $data ) or
      die( "decode: " . $parser->error .
           "Cannot handle input or missing ASN.1 definitions" );

    return $class->$orig( data => $data, _asn1 => $asn, parsed => $top );

};


sub __crl_number {

    my $self = shift;
    foreach my $extension ( @{ $self->parsed()->{'tbsCertList'}->{'crlExtensions'} } ) {
        if ( $extension->{'extnID'} eq '2.5.29.20' ) { # OID for CRLNumber
            my $parser = $self->_asn1()->find('cRLNumber'); # get a parser for this
            return $parser->decode( $extension->{'extnValue'} ); # decode the value
        }
    }
}

sub __authority_key_id {

    my $self = shift;
    foreach my $extension ( @{ $self->parsed()->{'tbsCertList'}->{'crlExtensions'} } ) {
        if ( $extension->{'extnID'} eq '2.5.29.35' ) { # OID for CRLNumber
            my $parser = $self->_asn1()->find('AuthorityKeyIdentifier'); # get a parser for this
            my $aki = $parser->decode( $extension->{'extnValue'} ); # decode the value
            # is a hash, we only support keyIdentifier
            if ($aki->{'keyIdentifier'}) {
                return uc join ':', ( unpack '(A2)*', unpack ("H*", $aki->{'keyIdentifier'}));
            }
            return undef;
        }
    }
}

sub __issuer_dn {

    my $self = shift;
    my $map = $self->oidmap();
    my @subject;
    foreach my $rdn (@{$self->parsed()->{'tbsCertList'}->{'issuer'}->{'rdnSequence'}}) {
        my $t = $rdn->[0]->{type};
        $t = $map->{$t} if ($map->{$t});
        my @v = values %{$rdn->[0]->{value}};
        push @subject, "$t=$v[0]";
    }
    return join ",", reverse @subject;

}

# Returns a HashRef of revoked certificates:
#    {
#        CERT_SERIAL => [ REVOCATION_TIMESTAMP, REASON ],
#        CERT_SERIAL => [ REVOCATION_TIMESTAMP, REASON ],
#        ...
#    }
sub __revoked_certs_list {

    my $self = shift;
    my $crl = {};
    my $items = $self->parsed()->{'tbsCertList'}->{'revokedCertificates'};
    return {} unless ($items);
    my $parser = $self->_asn1()->find('CRLReason');
    my $crl_reason_list = $self->crl_reason();
    foreach my $crl_item (@{$items}) {
        my $cert = $self->_asn1()->find('RevokedCert')->decode( $crl_item );
        my @v = ($cert->{'revocationDate'}->{'generalTime'} // $cert->{'revocationDate'}->{'utcTime'} // 0, undef);
        foreach my $ext (@{$cert->{crlEntryExtensions}}) {
            if ( $ext->{'extnID'} eq '2.5.29.21' ) { # OID for crlReason
                my $reason = $parser->decode( $ext->{'extnValue'} );
                if (!$parser->error && defined $reason) {
                    $v[1] = $crl_reason_list->[$reason];
                }
                last;
            }
        }
        $crl->{ $cert->{userCertificate} } = \@v; # userCertificate = serial number
    }
    return $crl;
}

sub to_hash {

    my $self = shift;
    return {
        'issuer' => $self->get_issuer(),
        #'signature_algorithm',
        'next_update' => $self->next_update(),
        'last_update' => $self->last_update(),
        'version'  => $self->version(),
        'itemcnt'  => $self->itemcnt(),
        'serial' => $self->crl_number(),
    };

}

__PACKAGE__->meta->make_immutable;

__END__;

