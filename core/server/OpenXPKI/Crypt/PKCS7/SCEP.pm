package OpenXPKI::Crypt::PKCS7::SCEP;

use strict;
use warnings;
use English;
use MIME::Base64;
use Moose;
use Convert::ASN1 ':tag';
use Crypt::CBC;
use Crypt::Digest qw( digest_data );

use OpenXPKI::Debug;
use OpenXPKI::Random;
use OpenXPKI::Exception;
use OpenXPKI::Crypt::PKCS10;
use OpenXPKI::Crypt::X509;
use OpenXPKI::Crypt::PKCS7 qw(encode_tag decode_tag find_oid);
# CTX is only used to generate random for nonce and keys
use OpenXPKI::Server::Context qw( CTX );

with 'OpenXPKI::Role::IssuerSerial';

=head1 NAME

OpenXPKI::Crypt::PKCS7::SCEP

=head1 DESCRIPTION

This class parses and generates SCEP request messages and responses.

To parse an SCEP message, you can either pass the PKCS7 request message
as single argument to the I<new> method, or set it via I<message> later.
Call one of the C<create_*_response> methods to generate a response for
this request.

If you want to generate a response without having the request, you must
call new with all parameters that are required to initialize the class
as denoted below.

=head2 Parameters / Accessor methods

=cut


our $schema = "
";

our %mapMessageTypes = (
    '3' => 'CertRep',  # Response to certificate or CRL request
    '17' => 'RenewalReq', # Renewal Request
    '19' => 'PKCSReq',  # PKCS#10 certificate request
    '20' => 'GetCertInitial', # Certificate polling in manual enrollment
    '21' => 'GetCert', #Retrieve a certificate
    '22' => 'GetCRL', # Retrieve a CRL
);

our %mapFailInfo = (
    'badAlg' => 0, # Unrecognized or unsupported algorithm.
    'badMessageCheck' => 1, # Integrity check (meaning signature verification of the CMS message) failed.
    'badRequest' => 2, # Transaction not permitted or supported.
    'badTime' => 3, # The signingTime attribute from the CMS authenticatedAttributes was not sufficiently close to the system time (this failure code is present for legacy reasons and is unlikely to be encountered in practice).
    'badCertId' => 4 # No certificate could be identified matching the provided criteria.
);

has _asn1 => (
    is => 'ro',
    required => 1,
    isa => 'Convert::ASN1',
);

=head3 message

The outer PKCS7 (signedData) message as OpenXPKI::Crypt::PKCS7 object.
This is the parsed result of the data passed to the constructor.

=cut


has message => (
    is => 'rw',
    isa => 'OpenXPKI::Crypt::PKCS7',
    lazy => 1,
    predicate => 'has_message',
    default => sub { die "input message was not set - attributes not available"; }
);

=head3 request

Returns the inner PKCS7 (envelopedData) as OpenXPKI::Crypt::PKCS7 object

=cut

has request => (
    is => 'ro',
    isa => 'OpenXPKI::Crypt::PKCS7',
    lazy => 1,
    default => sub { return OpenXPKI::Crypt::PKCS7->new(shift->message->payload); },
);

=head3 message_type

Return the messageType from the envelope of the message (see mapMessageType)

=cut

has message_type => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub {
        return $mapMessageTypes{shift->message()->envelope()->{authAttr}->{messageType}};
    }
);

=head3 transaction_id

Returns the transaction_id of the request, must be passed to the
constructor when generating a new instances without a message.

=cut

has transaction_id => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub { return shift->message()->envelope()->{authAttr}->{transactionID}; }
);

=head3 request_nonce

Returns the value of the request nonce.

=cut

has request_nonce => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    predicate => 'has_request_nonce',
    default => sub { return shift->message()->envelope()->{authAttr}->{senderNonce}; }
);

=head3 reply_nonce

The nonce used to generate the response message. If not set a random
nonce is created when the response is created. Note that the nonce will
be generated only B<once> so subsequent calls to any generate_response
method will use the same nonce value! The RFC defines a 16 byte nonce
size but the size is adjusted to the sender nonce size in case this
differs to support devices using a 8 bytes nonce as reported on the
mailing list.

=cut

has reply_nonce => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => sub { return CTX('api2')->get_random( length => 16, binary => 1 ); }
);

=head3 digest_alg

Returns the name of the digest algorithm used.

Must be set when generating any response.

=cut

has digest_alg => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => sub { return shift->message()->envelope()->{digest_alg}; }
);

=head3 enc_alg

Returns the name of the (symmetric) encryption algorithm used.

Must be set when generating a success response.

=cut

has enc_alg => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => sub { return shift->request()->envelope()->{enc_alg}; }
);


=head3 key_alg

Returns the name of the key algorithm used to encrypt the payload key.

Must be set when generating a success response.

=cut

has key_alg => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => sub { return shift->request()->envelope()->{key_alg}->[0]; }
);

=head3 signer

A OpenXPKI::Crypt::X509 object representing the signer of the request.

This must be set before you can generate a success response.

=cut

has signer => (
    is => 'ro',
    isa => 'OpenXPKI::Crypt::X509',
    lazy => 1,
    builder => '__build_signer'
);

=head3 recipient

Returns the recipient information for the message, the return value is
an IssuerSerial hash as defined in OpenXPKI::Role::IssuerSerial

=cut

has recipient => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    builder => '__build_recipient'
);

=head3 payload

Reads the payload from the response, returns the decypted raw binary data.

=cut

has payload => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    builder => '__extract_payload',

);

=head3 ratoken

A OpenXPKI::Crypt::X509 object representing the SCEP RA certificate.

=cut

has ratoken => (
    is => 'rw',
    isa => 'OpenXPKI::Crypt::X509',
);

=head3 ratoken_key

A Crypt::PK::* or OpenXPKI::Crypto::Backend::API object holding the
private key of the RA, currently only Crypt::PK::RSA is supported.
You can pass both arguments at construction time or set them on the
instance.

=cut

has ratoken_key => (
    is => 'rw',
    predicate => 'has_key',
    #isa => 'Crypt::PK::RSA | Crypt::PK::ECC',
);

=head3 certs

An array ref holding the DER encoded certificates that will be set
as response to a certRep SUCCESS. The entity certificate must be the
first item.

=cut

has certs => (
    is => 'rw',
    isa => 'ArrayRef[Str]',
);

around BUILDARGS => sub {

    my $orig  = shift;
    my $class = shift;

    my $asn = Convert::ASN1->new( encoding => 'DER' );
    $asn->prepare( $OpenXPKI::Crypt::PKCS7::schema . $schema )
        or die( "Internal error in " . __PACKAGE__ . ": " . $asn->error );

    if (@_ == 1) {
        my $request = shift;
        # Base64 encoded without boundary markers
        # This regex is not exact but sufficient to be fast and
        # unambigous related to the expected data
        if ($request =~ m{\AM([[:print:]]|\s)+\z}) {
            ##! 64: 'base64 request without boundaries, decoding...'
            $request = decode_base64($request);            
        }
        my $outer = OpenXPKI::Crypt::PKCS7->new($request);
        ##! 128: $outer->parsed()
        return $class->$orig(_asn1 => $asn, message => $outer );
    }

    return $class->$orig( @_, _asn1 => $asn );

};


sub __build_signer {

    my $self = shift;
    my $certlist = $self->message()->certificates();

    # iterate over the certlist and check serial/issuer to find the right one
    my $serial = $self->message()->envelope()->{signer}->{serial};
    my $subject = $self->message()->envelope()->{signer}->{issuer}->get_subject();
    ##! 32: "Looking for $subject  / $serial"
    foreach my $cert (@$certlist) {
        ##! 64: "Checking cert " . $cert->get_subject()
        next unless ($cert->get_serial() eq $serial);
        next unless ($cert->get_issuer() eq $subject);
        return $cert;
    }

    OpenXPKI::Exception->throw(
        message => 'Unable to find signer certificate in enveloped message'
    );

}

sub __build_recipient {

    my $self = shift;
    my $rcptlist = $self->request()->recipients();
    return $rcptlist->[0];

}

sub __extract_payload {

    my $self = shift;
    ##! 1: 'start'
    my $req = $self->request()->parsed();
    my $ri = $req->{content}->{recipientInfos}->{riSet}->[0];

    my $skey = $self->ratoken_key();
    OpenXPKI::Exception->throw(
        message => 'You must set the ratoken_key before you can decode the payload'
    ) unless ($skey);


    my $key_alg = $self->key_alg();
    OpenXPKI::Exception->throw(
        message => 'Unsupported payload encrpytion algorithm used',
        params => { key_alg => $key_alg }
    ) unless ($key_alg =~ m{(rsaEncryption|rsaesOaep)});

    my $sym_key_enc = $ri->{encryptedKey};
    my $content_key;
    if (ref $skey eq 'OpenXPKI::Crypto::Backend::API') {
        ##! 64: 'Token api'
        my %padding;
        $padding{PADDING} = 'oaep' if ($key_alg eq 'rsaesOaep');

        $content_key = $skey->command({
            COMMAND => 'decrypt_digest',
            DATA => $sym_key_enc,
            %padding,
        });
    } elsif (ref $skey eq 'Crypt::PK::RSA') {
        ##! 64: 'RSA soft key'
        if ($key_alg eq 'rsaesOaep') {
            # we assume it is sha1 (no idea where to find what its really in?)
            $content_key = $skey->decrypt( $sym_key_enc, 'oaep' );
        } else {
            $content_key = $skey->decrypt( $sym_key_enc, 'v1.5' );
        }
    } else {
        OpenXPKI::Exception->throw( message => 'Invalid encryption key type', params => { skey => ref $skey } );
    }

    # AES and DES/3DES have a single value as IV in parameters
    my $cbc = $self->__get_cbc( $content_key,
        decode_tag($req->{content}->{contentInfo}->{contentEncryptionAlgorithm}->{parameters}) );

    OpenXPKI::Exception->throw( message => 'Unable to initialize decrpytion key' )
        unless ($cbc);

    return $cbc->decrypt( $self->request()->payload() );

}

=head3  pkcs10

Returns the PKCS10 request from a enrollment message as
OpenXPKI::Crypt::PKCS10 object.

=cut

sub pkcs10 {

    my $self = shift;
    return OpenXPKI::Crypt::PKCS10->new( $self->payload() );
}

=head3 issuer_serial

Returns a hash with issuer and serial extracted from the payload of a
GetCRL or GetCert request. See OpenXPKI::Role::IssuerSerial.

=cut

sub issuer_serial {

    my $self = shift;

    my $asn1 = $self->_asn1;
    my $parser = $asn1->find('IssuerAndSerialNumber') || die $asn1->error;
    my $iasn = $parser->decode($self->payload()) || die $parser->error;

    return iasn_from_hash( $iasn );
}

sub __get_cbc {

    my $self = shift;
    my $content_key = shift;
    my $content_iv = shift;

    my $enc_alg = $self->enc_alg();

    my $cipher;
    ##! 16: 'get cbc for ' . $enc_alg
    if ($enc_alg =~ m{\Aaes-(\d+)-cbc}) {
        $cipher = 'Cipher::AES';
        my $len = ($1/8);
        $content_key ||= CTX('api2')->get_random( length => $len, binary => 1 );
        $content_iv ||= CTX('api2')->get_random( length => 16, binary => 1 );
    } elsif ($enc_alg eq 'des-cbc') {
        $cipher = 'Cipher::DES';
        $content_key ||= CTX('api2')->get_random( length => 8, binary => 1 );
        $content_iv ||= CTX('api2')->get_random( length => 8, binary => 1 );
    } elsif ($enc_alg eq '3des-cbc') {
        $cipher = 'Cipher::DES_EDE';
        $content_key ||= CTX('api2')->get_random( length => 24, binary => 1 );
        $content_iv ||= CTX('api2')->get_random( length => 8, binary => 1 );
    } else {
        OpenXPKI::Exception->throw( message => 'Unknown content encryption algorithm',
            params => { enc_alg => $enc_alg } );
    }
    ##! 64: "IV: " . encode_base64($content_iv) . " - Key: " . encode_base64($content_key)

    my $cbc = Crypt::CBC->new(
        -cipher => $cipher,
        -key    => $content_key,
        -iv     => $content_iv,
        # for whatever reason the AES module needs the keysize
        -keysize => (length $content_key),
        -literal_key => 1,
        -header => 'none'
    );

    return ($cbc, $content_key, $content_iv) if (wantarray);

    return $cbc;

}

sub __generate_response {

    ##! 8: 'start response'
    my $self = shift;
    # content must be
    # a hash with the key "response" for success
    # a hash with the key "error" (integer) for failure, optional "status" (string)
    # undef for pending
    my $content = shift || {};

    my $asn1 = $self->_asn1;

    my $payload_digest = digest_data( uc($self->digest_alg()), $content->{response} || '');
    ##! 32: "Payload built - digest " . encode_base64($payload_digest)
    my @authAttr = (
        { 'type' => '2.16.840.1.113733.1.9.2', 'values' => [ encode_tag( '3', 'PrintableString') ] }, # messageType
        { 'type' => '2.16.840.1.113733.1.9.7', 'values' => [ encode_tag( $self->transaction_id(), 'PrintableString') ] }, # transactionID
        { 'type' => '1.2.840.113549.1.9.4', 'values' => [ encode_tag( $payload_digest ) ] }, # payload digest
        { 'type' => '1.2.840.113549.1.9.5', 'values' => [ encode_tag( DateTime->now()->strftime("%y%m%d%H%M%SZ"), 23) ] }, # signingTime
        { 'type' => '1.2.840.113549.1.9.3', 'values' => [ encode_tag( '1.2.840.113549.1.7.1', 'OID' ) ] }, # contentType (id-data)
    );

    my %payload;
    if ($content->{response}) {
        ##! 32: 'Response'
        ##! 128: 'PKCS7 Payload' . encode_base64($content->{response})
        push @authAttr, {
            'type' => '2.16.840.1.113733.1.9.3',
            'values' => [ encode_tag( '0', 'PrintableString') ]
        }; # pkiStatus
        $payload{content} = encode_tag($content->{response});
    } elsif ($content->{error}) {
        ##! 32: 'Error'
        push @authAttr, {
            'type' => '2.16.840.1.113733.1.9.3',
            'values' => [ encode_tag( '2', 'PrintableString') ]
        }; # pkiStatus = FAIILURE

        push @authAttr, {
            'type' => '2.16.840.1.113733.1.9.4',
            'values' => [ encode_tag( ($content->{error} // 2), 'PrintableString') ]
        }; # failInfo - default to badRequest (2)

        push @authAttr, {
            'type' => '1.3.6.1.5.5.7.24.1',
            'values' => [ encode_tag( $content->{status}, 'UTF8String') ]
        } if ($content->{status}); # failInfoText
    } else {
        ##! 32: 'Pending'
        push @authAttr, {
            'type' => '2.16.840.1.113733.1.9.3',
            'values' => [ encode_tag( '3', 'PrintableString') ]
        }; # pkiStatus = PENDING
    }

    # the request nonce is copied over as recipient nonce in case it is set
    if (my $nonce = $self->has_request_nonce()) {
        ##! 64: 'Adding request nonce'
        push @authAttr, {
            'type' => '2.16.840.1.113733.1.9.6',
            'values' => [ encode_tag( $self->request_nonce() ) ]
        };
        # The RFC defines 16 byte nonces but it seems that some older iOS
        # devices send and expect 8 bytes nonces so we force a non-compliant
        # nonce size in case the senders nonce is not 16 bytes
        my $len = length $self->request_nonce();
        if ($len && $len != 16) {
            ##! 16: 'Force non-compliant nonce length'
            $self->reply_nonce( CTX('api2')->get_random( length => $len, binary => 1 ));
        }
    }

    push @authAttr, {
        'type' => '2.16.840.1.113733.1.9.5',
        'values' => [ encode_tag( $self->reply_nonce() ) ]
    }; # senderNonce

    # The ASN1 spec demands that the elemements in authAttr needs to be "lexically sorted"
    # by their encoded value. We first walk the array and create the asn1 binary encoding

    map {
        # Encode type as OID and value as set (we only have single item lists)
        # and concatenate them into a sequence
        $_->{asn1} = encode_tag(
            encode_tag( $_->{type}, 'OID' ) . encode_tag( $_->{values}->[0], 0x31 )
        , 0x30 );
    } @authAttr;

    # Sort the array by shifting groups of 32 bits as integers from the left
    # and compare them until we got a difference, creates a helper structure
    # inline of the array to cache the values used for sorting
    @authAttr = sort {
        my $idx = 0;
        while(1) {
            # vec extracts bits from the left and converts them to an integer
            $a->{sort}->[$idx] ||= vec($a->{asn1},$idx,32);
            $b->{sort}->[$idx] ||= vec($b->{asn1},$idx,32);
            my $cmp = ($a->{sort}->[$idx] <=> $b->{sort}->[$idx]);
            # items like the nonces have a very similar ID and same tag/length
            # bytes so they differ late (bit 13) - so we try this for the
            # leftmost bits until they differs
            return $cmp if ($cmp);
            $idx++;
            # safety net, should never happen at least for our usage scenarios
            die "Unable to sort" if ($idx > 5);
        }
    } @authAttr;
    ##! 16: \@authAttr

    # The binary stream to sign is constructed from the list of the values
    # we already have the binary data from the helper so we just need to
    # add the outer "set of" tag (0x11 + 0x20 as it is constructed)
    my $attributeContent = encode_tag( join('', (map { $_->{asn1} } @authAttr) ), 0x31 );
    ##! 128: 'attribute content ' . encode_base64($attributeContent)

    ##! 128: 'Attribute Content ' . encode_base64($attributeContent)

    my $skey = $self->ratoken_key();
    my $racert = $self->ratoken();

    my ($sigAlg, $signature);
    # ECC is very uncommon so we allow RSA only for now
    $sigAlg = '1.2.840.113549.1.1.1'; # rsa

    if (ref $skey eq 'OpenXPKI::Crypto::Backend::API') {
        # as we are unable to get the key details from the token we
        # check the signer certificate for the used pubkey algorithm
        my $pkAlg = $racert->_cert()->PubKeyAlg();
        OpenXPKI::Exception->throw(
            message => 'Unsupported RA key type', params => { type => $pkAlg }
        ) unless ($pkAlg eq 'RSA');

        ##! 64: 'Token API'
        my $attribute_digest = digest_data( uc($self->digest_alg()), $attributeContent);
        ##! 128: 'Attribute Content ' . encode_base64($attribute_digest)
        $signature = $skey->command({
            COMMAND => 'sign_digest',
            DIGEST => $attribute_digest,
        });
    } elsif (ref $skey eq 'Crypt::PK::RSA') {
        ##! 64: 'RSA soft key'
        $signature = $skey->sign_message($attributeContent, uc($self->digest_alg()), 'v1.5');
    } else {
        OpenXPKI::Exception->throw( message => 'Invalid signature key type', params => { skey => ref $skey } );
    }

    my $digestAlg = find_oid($self->digest_alg());
    ##! 128: 'signature done'
    my $parser = $asn1->find('PKCS7ContentInfoSignedData');
    my $pkcs7sig = $parser->encode({
        contentType => '1.2.840.113549.1.7.2', # pkcs7-signedData
        content => {
            version => 1,
            digestAlgorithms => { daSet => [ { algorithm => $digestAlg }] }, # sha256
            contentInfo   => {
                contentType  => '1.2.840.113549.1.7.1', # id-data
                %payload  # this is only set if a payload exists
            },
            certificates => { 'certSet' => [ { 'certificate' =>  $racert->data() } ] },
            signerInfos  => { siSet => [{
                    version => 1,
                    sid => { issuerAndSerialNumber => {
                        issuer => $racert->_cert()->{'tbsCertificate'}->{'issuer'}->{'rdnSequence'},
                        serialNumber => $racert->get_serial(),
                    }},
                    authenticatedAttributes => { 'aaSet' => \@authAttr },
                    digestAlgorithm       => { algorithm => $digestAlg }, # sha256
                    digestEncryptionAlgorithm  => { algorithm => $sigAlg },
                    encryptedDigest => $signature,
            }]},
        }
    }) || die $parser->error;
    ##! 128: 'response ' . encode_base64($pkcs7sig)
    return $pkcs7sig;

}

=head2 Response Generation

There is an individual method to generate success, pending and failure
responses. They all require that the class was either initiated with an
incoming PKCS7 message or that the ratoken, transaction_id and digest
algorithm are set.

All methods returned the DER encoded PKCS7 message as binary data.

=head3 create_cert_response

Generate a success response, requires that I<certs> was set to contain
the expected return data, I<signer> is set to the recipient
certificate and I<enc_alg> is provided.

=cut

sub create_cert_response {

    ##! 8: 'start response'
    my $self = shift;
    my $asn1 = $self->_asn1;
    my $parser = $asn1->find('PKCS7ContentInfoSignedData');

    # this is the "real" return payload - a degenerated PKCS7 container
    my @certs = map { {'certificate' => $_ } } @{$self->certs};

    OpenXPKI::Exception->throw(
        message => 'You must add the certificates for the response to the certs attribute'
    ) unless (@certs);

    my $payload = $parser->encode({
        'contentType' => '1.2.840.113549.1.7.2', # signed data
        'content' => {
            'version' => 1,
            'contentInfo' => { 'contentType' => '1.2.840.113549.1.7.1' }, # id-data
            'digestAlgorithms' => {'daSet' => [] },
            'signerInfos' => { 'siSet' => [] },
            'certificates' => { 'certSet' => \@certs }
        }
    }) || die $parser->error;

    # the inner message is the payload encrypted with a random DES/AES key and the
    # public key of the receipient - this is stored in the signer attribute

    my ($cbc, $content_key, $iv) = $self->__get_cbc();

    my $cert = $self->signer();
    my $rkey = $cert->_cert()->pubkey();
    my $pkAlg = $cert->_cert()->PubKeyAlg();
    my ($encryptedKey, $keyEncAlg);
    if ($pkAlg eq 'RSA') {
        if ($self->key_alg() eq 'rsaesOaep') {
            $keyEncAlg = '1.2.840.113549.1.1.7';
            $encryptedKey = Crypt::PK::RSA->new(\$rkey)->encrypt( $content_key, 'oaep' );
        } else {
            $keyEncAlg = '1.2.840.113549.1.1.1';
            $encryptedKey = Crypt::PK::RSA->new(\$rkey)->encrypt( $content_key, 'v1.5' );
        }
    # TODO - Support for ECC
    } else {
        die "Unsupported key algorithm for recipient";
    }

    $parser = $asn1->find('PKCS7ContentInfoEnvelopedData');
    my $pkcs7enc = $parser->encode({
        'contentType' => '1.2.840.113549.1.7.3', # enveloped data
        'content' => {
            'version' => 0,
            'recipientInfos' => {
                'riSet' => [{
                    'keyEncryptionAlgorithm' => {
                        'algorithm' => $keyEncAlg,
                        'parameters' => ''
                    },
                    'version' => 0,
                    'encryptedKey' => $encryptedKey,
                    'issuerAndSerialNumber' => {
                        issuer => $cert->_cert()->{'tbsCertificate'}->{'issuer'}->{'rdnSequence'},
                        serialNumber => $cert->get_serial(),
                    }
                }]
            },
            'contentInfo' => {
                'content' => encode_tag( $cbc->encrypt($payload), 0x80 ),
                'contentType' => '1.2.840.113549.1.7.1', #id-data
                'contentEncryptionAlgorithm' => {
                    'algorithm' => find_oid( $self->enc_alg() ),
                    'parameters' => encode_tag($iv) # iv
                }
            }
        }
    }) || die $parser->error;

    return $self->__generate_response( { response => $pkcs7enc } );

}

=head3 create_pending_response

Generate a pending response from the transaction_id passed to the
constructor. Returns the binary DER encoded response.

=cut

sub create_pending_response {

    my $self = shift;
    return $self->__generate_response();

}

=head3 create_failure_response

Generate a failure response using the transaction_id passed to the
constructor and the error value passed as argument. The error can
be given either a integer or one of the defined error codes
I<badAlg, badMessageCheck, badRequest, badTime, badCertId>

Returns the binary DER encoded response.

=cut

sub create_failure_response {

    my $self = shift;
    my $error = shift // 2;

    if ($error !~ m{\d}) {
        $error = $mapFailInfo{$error} // 2;
    }
    return $self->__generate_response( { error => $error } );

}


1;
