package OpenXPKI::Server::Workflow::Condition::IsWrappedRequest;

use strict;
use warnings;
use English;

use base qw( OpenXPKI::Server::Workflow::Condition );
use Convert::ASN1 ':tag';
use Crypt::PKCS10;
use MIME::Base64;
use Workflow::Exception qw( condition_error configuration_error );

use OpenXPKI::Debug;
use OpenXPKI::Crypt::PKCS7;
use OpenXPKI::Server::Context qw( CTX );


sub _evaluate {
    ##! 1: 'start'
    my ( $self, $workflow ) = @_;

    my $context  = $workflow->context();
    ##! 64: 'context: ' . Dumper($context)

    my $data = $self->param('data') ||
        configuration_error('You must provide the request in the parameter data');

    $data =~ m{-----BEGIN[^-]*REQUEST-----(.+?)-----END[^-]*REQUEST-----}xms;
    configuration_error('Does not look like a PEM formatted request container') unless($1);
    my $binary = decode_base64($1);

    # renewal requests generated from Windows machines have the
    # BEGIN CERTIFICATE REQUEST header but contain a PKCS7 structure
    # While a real PKCS10 container has a SEQUENCE tag at the second
    # node a PKCS7 container has the OID for signed data here.

    # get the lenght of the outer SEQUENCE tag
    my ($tagbytes, $tag) = asn_decode_tag($binary);
    my ($lengthbytes, $length) = asn_decode_length(substr($binary, $tagbytes));

    Crypt::PKCS10->setAPIversion(1);
    # both lenghtbytes are the offset for the second tag
    # we directly check if this is another SEQUENCE tag
    if (substr($binary, $tagbytes+$lengthbytes, 1) eq "\x30") {
        Crypt::PKCS10->new( $binary, verifySignature => 0 ) ||
            configuration_error('Looks like a regular PKCS10 but does not parse: ' . Crypt::PKCS10->error );

        condition_error('Looks like a regular PKCS10 container');
    # or the encoded OID for signedData
    } elsif (substr($binary, $tagbytes+$lengthbytes, 11) eq "\x06\x09\x2A\x86\x48\x86\xF7\x0D\x01\x07\x02")  {
        my $payload;
        eval{
            $payload = OpenXPKI::Crypt::PKCS7->new($binary)->payload();
        };
        configuration_error('Looks like a PKCS7 structure but does not parse: ' . $EVAL_ERROR) unless($payload);
        ##! 1: encode_base64($pkcs10)
        Crypt::PKCS10->new( $payload, verifySignature => 0 ) ||
            configuration_error('Found PKCS7 but payload does not look like PKCS10 ' . Crypt::PKCS10->error);

    } else {
        configuration_error('Does neither look like PKCS10 nor like a PKCS7 container');
    }

    return 1;
    ##! 16: 'end'
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::IsWrappedRequest

=head1 DESCRIPTION

This condition checks whether a given PEM formatted certificate
PKCS10 inside a PKCS7 container or a "plain" PKCS10 structure.

The condition neither checks the signature on the PKCS10 container nor
the signature of the outer PKCS7 structure and also does not check any
relation between the PKCS7 and the PKCS10.

The condition is true, if the given PEM data is a PKCS7 SignedData with
a payload that can be parsed as PKCS10 container. It is false if the
data can be parsed as PKCS10 request directly.

The conditions throws a configuration error if it is not able to
find a parsable PKCS10 container.

=head2 Parameters

The request to parse must be given in the context key I<data>.