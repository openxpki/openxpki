package OpenXPKI::Server::API2::Plugin::Cert::get_cert;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Cert::get_cert

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::Crypto::X509;
use OpenXPKI::Crypt::X509;
use MIME::Base64;

=head1 COMMANDS

=head2 get_cert

returns the requested certificate.

B<Parameters>

=over

=item * identifier

=item * format

=over

=item * PEM

=item * DER

=item * PKCS7

=item * TXT

=item * TXTPEM

=item * HASH - the default value

=item * DBINFO - information from the certificate and attributes table

=back

=item attribute - expression for attributes to add, see get_cert_attributes

=back

B<Changes compared to API v1:>

The output of HASH has changed dramatically! The full content of BODY is no
longer part of the output, keys are all lowercased and relevant data from the
body was moved to keys on the first level.

When called with C<format =E<gt> "DBINFO"> the returned I<HashRef> contains
lowercase keys. Additionally the following keys changed:

    CERTIFICATE_SERIAL      --> cert_key
    CERTIFICATE_SERIAL_HEX  --> cert_key_hex
    PUBKEY                  --> public_key
    CSR_SERIAL              --> req_key

To get attributes for the certificate back with DBINFO you MUST pass the name
or "LIKE" "expression for the attributes keys as defined in get_cert_attributes.

=cut
command "get_cert" => {
    identifier => { isa => 'Base64', required => 1, },
    format     => { isa => 'AlphaPunct', matching => qr{ \A ( PEM | DER | TXT | TXTPEM | HASH | DBINFO | PKCS7 ) \Z }x, default => "HASH" },
    attribute  => { isa => 'Str', },
} => sub {
    my ($self, $params) = @_;

    my $dbi = CTX('dbi');

    my $identifier = $params->identifier;
    my $format     = $params->format;
    ##! 2: "Requested output format: $format"

    ##! 2: "Fetching certificate from database"
    my $cert = $dbi->select_one(
        columns => [ '*' ],
        from => 'certificate',
        where => { 'identifier' => $identifier },
    )
        or OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_CERT_CERTIFICATE_NOT_FOUND_IN_DB',
            params => { 'IDENTIFIER' => $identifier, },
        );

    if ($format eq 'PEM') {
        return $cert->{data};
    }

    if ($format eq 'DER') {
        $cert->{data} =~ m{-----BEGIN[^-]*CERTIFICATE-----(.+)-----END[^-]*CERTIFICATE-----}xms;
        my $base64_cert = $1;
        $base64_cert =~ s{\s}{}xms;
        return decode_base64($base64_cert);
    }

    if ($format eq 'TXT' || $format eq 'TXTPEM') {
        my $result = CTX('api2')->get_default_token->command ({
            COMMAND => "convert_cert",
            DATA    => $cert->{data},
            OUT     => $format
        });
        return $result;
    };

    if ('PKCS7' eq $format) {
        my $result = CTX('api2')->get_default_token->command({
            COMMAND          => 'convert_cert',
            DATA             => [ $cert->{data} ],
            OUT              => 'PEM',
            CONTAINER_FORMAT => 'PKCS7',
        });
        return $result;
    }

    # Hex Serial
    my $serial = Math::BigInt->new($cert->{cert_key});
    $cert->{cert_key_hex} = $serial->as_hex;
    $cert->{cert_key_hex} =~ s{\A 0x}{}xms;

    # Expired Status
    $cert->{status} = 'EXPIRED' if $cert->{status} eq 'ISSUED' and $cert->{notafter} < time();

    # Format: "DBINFO"
    if ($format eq 'DBINFO') {
        ##! 2: "Preparing output for DBINFO format"
        delete $cert->{data};

        if ($params->has_attribute) {
            $cert->{cert_attributes} = $self->api->get_cert_attributes( identifier => $identifier, attribute => $params->attribute );
        }

        return $cert;
    }

    my $x509 = OpenXPKI::Crypt::X509->new( $cert->{data} );

    ##! 2: "Preparing output for HASH format"
    my $result = {};
    $result->{serial_hex} = $cert->{cert_key_hex};
    $result->{serial} = $cert->{cert_key};
    $result->{subject} = $cert->{subject};
    $result->{subject_hash} = $x509->subject_hash();
    $result->{notbefore} = $cert->{notbefore};
    $result->{notafter}  = $cert->{notafter};
    $result->{status}            = $cert->{status};
    $result->{identifier}        = $cert->{identifier};
    $result->{issuer_identifier} = $cert->{issuer_identifier};
    $result->{issuer} = $cert->{issuer_dn};
    $result->{csr_serial}        = $cert->{req_key};
    $result->{pki_realm}         = $cert->{pki_realm};
    return $result;

};

__PACKAGE__->meta->make_immutable;
