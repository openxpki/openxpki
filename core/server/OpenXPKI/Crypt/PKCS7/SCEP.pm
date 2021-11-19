package OpenXPKI::Crypt::PKCS7::SCEP;

use strict;
use warnings;
use English;
use Data::Dumper;
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

This class generate Full PKI Response structures based on RFC5272.

=head2 Parameters

=over

=item signer

A OpenXPKI::Crypt::X509 object representing the signer certificate.

=item signer_key

A Crypt::PK::* or OpenXPKI::Crypto::Backend::API object holding the
private key of the signer, currently only Crypt::PK::RSA and
Crypt::PK::ECC are supported. You can pass both arguments at
construction time or set them on the instance.

=back

print Dumper $req->request()->envelope()->{recipient};

=cut


our $schema = "
";

our %mapMessageTypes = (
    '3' => 'CertRep',  # Response to certificate or CRL request
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

has message => (
    is => 'rw',
    isa => 'OpenXPKI::Crypt::PKCS7',
    lazy => 1,
    predicate => 'has_message',
    default => sub { die "input message was not set - attributes not available"; }
);

has request => (
    is => 'ro',
    isa => 'OpenXPKI::Crypt::PKCS7',
    lazy => 1,
    default => sub { return OpenXPKI::Crypt::PKCS7->new(shift->message->payload); },
);

has message_type => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub {
        return $mapMessageTypes{shift->message()->envelope()->{authAttr}->{messageType}};
    }
);

has transaction_id => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub { return shift->message()->envelope()->{authAttr}->{transactionID}; }
);

has request_nonce => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    predicate => 'has_request_nonce',
    default => sub { return shift->message()->envelope()->{authAttr}->{senderNonce}; }
);

has reply_nonce => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub { return CTX('api2')->get_random( length => 16, binary => 1 ); }
);

has digest_alg => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => sub { return shift->message()->envelope()->{digest_alg}; }
);

has enc_alg => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => sub { return shift->request()->envelope()->{enc_alg}; }
);

has signer => (
    is => 'ro',
    isa => 'OpenXPKI::Crypt::X509',
    lazy => 1,
    builder => '__build_signer'
);

has recipient => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    builder => '__build_recipient'
);

has payload => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    builder => '__extract_payload',

);

has ratoken => (
    is => 'rw',
    isa => 'OpenXPKI::Crypt::X509',
);

# set for response, entity must be the first
has certs => (
    is => 'rw',
    isa => 'ArrayRef[Str]',
);

has ratoken_key => (
    is => 'rw',
    predicate => 'has_key',
    #isa => 'Crypt::PK::RSA | Crypt::PK::ECC',
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
        if ($request =~ m{\AMII([[:print:]]|\s)+\z}) {
            $request = decode_base64($request);
        }
        my $outer = OpenXPKI::Crypt::PKCS7->new($request);
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

    my $sym_key_enc = $ri->{encryptedKey};

    my $skey = $self->ratoken_key();
    OpenXPKI::Exception->throw(
        message => 'You must set the ratoken_key before you can decode the payload'
    ) unless ($skey);

    my $content_key;
    if (ref $skey eq 'OpenXPKI::Crypto::Backend::API') {
        ##! 64: 'Token api'
        $content_key = $skey->command({
            COMMAND => 'decrypt_digest',
            DATA => $sym_key_enc,
        });
    } elsif (ref $skey eq 'Crypt::PK::RSA') {
        ##! 64: 'RSA soft key'
        $content_key = $skey->decrypt( $sym_key_enc, 'v1.5' );
    } else {
        OpenXPKI::Exception->throw( message => 'Invalid encryption key type', params => { skey => ref $skey } );
    }

    # AES and DES/3DES have a single value as IV in parameters
    my $cbc = $self->__get_cbc( $content_key,
        decode_tag($req->{content}->{contentInfo}->{contentEncryptionAlgorithm}->{parameters}) );

    OpenXPKI::Exception->throw( message => 'Unable to initialize decrpytion key' )
        unless ($cbc);

    return $cbc->decrypt( $req->{content}->{contentInfo}->{content} );

}

sub pkcs10 {

    my $self = shift;
    return OpenXPKI::Crypt::PKCS10->new( $self->payload() );
}

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
        { 'type' => '1.2.840.113549.1.9.5', 'values' => [ encode_tag( DateTime->now()->strftime("%Y%m%d%H%M%SZ"), 23) ] }, # signingTime
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
        if ($len != 16) {
            ##! 16: 'Force non-compliant nonce length'
            $self->reply_nonce( CTX('api2')->get_random( length => $len, binary => 1 ));
        }
    }

    push @authAttr, {
        'type' => '2.16.840.1.113733.1.9.5',
        'values' => [ encode_tag( $self->reply_nonce() ) ]
    }; # senderNonce

    my $parser = $asn1->find('SetOfAuthenticatedAttribute') || die $asn1->error;
    my $attributeContent = $parser->encode(\@authAttr) || die $parser->error;

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
        $signature = $skey->command({
            COMMAND => 'sign_digest',
            DIGEST => digest_data( uc($self->digest_alg()), $attributeContent),
        });
    } elsif (ref $skey eq 'Crypt::PK::RSA') {
        ##! 64: 'RSA soft key'
        $signature = $skey->sign_message($attributeContent, uc($self->digest_alg()), 'v1.5');
    } else {
        OpenXPKI::Exception->throw( message => 'Invalid signature key type', params => { skey => ref $skey } );
    }

    my $digestAlg = find_oid($self->digest_alg());
    ##! 128: 'signature done'
    $parser = $asn1->find('PKCS7ContentInfoSignedData');
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
        $keyEncAlg = '1.2.840.113549.1.1.1';
        $encryptedKey = Crypt::PK::RSA->new(\$rkey)->encrypt( $content_key, 'v1.5' );
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
                'content' => $cbc->encrypt($payload),
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

sub create_pending_response {

    my $self = shift;
    return $self->__generate_response();

}

sub create_failure_response {

    my $self = shift;
    my $error = shift // 2;

    if ($error !~ m{\d}) {
        $error = $mapFailInfo{$error} // 2;
    }
    return $self->__generate_response( { error => $error } );

}


1;


#492b6b6d3032314a57334471397264674562596d473936334f775173574d42650a
#openssl aes-256-cbc  -in inner.raw  -d -iv 5868736b6b444a6d614e44537131795 -K 492b6b3032314a57334471397264674562596d473936334f775173574d42650
