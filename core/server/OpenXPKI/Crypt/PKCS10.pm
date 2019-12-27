package OpenXPKI::Crypt::PKCS10;

use strict;
use warnings;
use English;

use OpenXPKI::DN;
use Math::BigInt;
use Digest::SHA qw(sha1_base64 sha1_hex);
use OpenXPKI::DateTime;
use MIME::Base64;
use Moose;
use Crypt::PKCS10 1.8;

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
        chomp $pem;
        return "-----BEGIN CERTIFICATE REQUEST-----\n$pem\n-----END CERTIFICATE REQUEST-----";
    },
);

has _pkcs10 => (
    is => 'ro',
    required => 1,
    isa => 'Crypt::PKCS10',
);

has subject => (
    is => 'ro',
    required => 0,
    isa => 'Str',
    reader => 'get_subject',
    lazy => 1,
    default => sub {
        my $self = shift;
        # we should improve Crypt::PKCS10 to return the desired format directly
        my $subject = $self->_pkcs10()->subject;
        return OpenXPKI::DN::convert_openssl_dn( $subject ) ;
    }
);

has subject_key_id => (
    is => 'rw',
    required => 0,
    isa => 'Str',
    reader => 'get_subject_key_id',
    lazy => 1,
    default => sub {
        my $self = shift;
        return uc join ':', ( unpack '(A2)*', sha1_hex( $self->_pkcs10()->{certificationRequestInfo}{subjectPKInfo}{subjectPublicKey}[0] ) );
    }
);

has csr_identifier => (
    is => 'rw',
    init_arg => undef,
    isa => 'Str',
    reader => 'get_csr_identifier',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $csr_identifier = sha1_base64($self->data);
        ## RFC 3548 URL and filename safe base64
        $csr_identifier =~ tr/+\//-_/;
        return $csr_identifier;
    },
);

has transaction_id => (
    is => 'rw',
    init_arg => undef,
    isa => 'Str',
    reader => 'get_transaction_id',
    lazy => 1,
    default => sub {
        my $self = shift;
        return sha1_hex($self->data);
    },
);

around BUILDARGS => sub {

    my $orig  = shift;
    my $class = shift;
    my $data = shift;

    Crypt::PKCS10->setAPIversion(1);
    my $pkcs10 = Crypt::PKCS10->new( $data, ignoreNonBase64 => 1, verifySignature => 0);
    if (Crypt::PKCS10->error) {
        die Crypt::PKCS10->error;
    }

    return $class->$orig( data => $pkcs10->csrRequest(), _pkcs10 => $pkcs10 );

};


1;


__END__;
