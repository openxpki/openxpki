package OpenXPKI::Crypt::PubKey;

use strict;
use warnings;
use English;

use Digest::SHA qw(sha1_base64 sha1_hex);
use MIME::Base64;
use Moose;

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
        my $pem = encode_base64($self->data());
        $pem =~ s{\s}{}g;
        $pem =~ s{ (.{64}) }{$1\n}xmsg;
        return "-----BEGIN PUBLIC KEY-----\n$pem\n-----END PUBLIC KEY-----";
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

has subject_key_id => (
    is => 'rw',
    required => 0,
    isa => 'Str',
    reader => 'get_subject_key_id',
    lazy => 1,
    default => sub {
        my $self = shift;
        return uc join ':', ( unpack '(A2)*', sha1_hex( $self->parsed()->{subjectPublicKey}[0] ));
    }

);

around BUILDARGS => sub {

    my $orig  = shift;
    my $class = shift;
    my $data = shift;

    my $schema = "
        Algorithms ::= ANY

        AlgorithmIdentifier ::= SEQUENCE {
          algorithm  OBJECT IDENTIFIER,
          parameters Algorithms OPTIONAL}

        SubjectPublicKeyInfo ::= SEQUENCE {
          algorithm        AlgorithmIdentifier,
          subjectPublicKey BIT STRING}

        rsaKey ::= SEQUENCE {
            modulus         INTEGER,
            publicExponent  INTEGER}

        dsaKey  ::= INTEGER

        dsaPars ::= SEQUENCE {
            P               INTEGER,
            Q               INTEGER,
            G               INTEGER}

        eccName ::= OBJECT IDENTIFIER

        ecdsaSigValue ::= SEQUENCE {
            r               INTEGER,
            s               INTEGER}
    ";

    my $asn = Convert::ASN1->new;
    $asn->prepare($schema) or die( "Internal error in " . __PACKAGE__ . ": " . $asn->error );
    my $parser = $asn->find('SubjectPublicKeyInfo');

    if ($data =~ m{-----BEGIN\ ([^-]+)-----\s*(.*)\s*-----END\ \1-----}xms) {
        $data = decode_base64($2);
    }

    my $top = $parser->decode( $data ) or
      die( "decode: " . $parser->error .
           "Cannot handle input or missing ASN.1 definitions" );

    return $class->$orig( data => $data, _asn1 => $asn, parsed => $top );

};


1;


__END__;
