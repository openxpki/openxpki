package OpenXPKI::Server::API2::Plugin::Cert::get_cert;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Cert::get_cert

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



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

=item * TXT

=item * TXTPEM

=item * HASH - the default value

=item * DBINFO - information from the certificate and attributes table

=back

=back

B<Changes compared to API v1:>

When called with C<format =E<gt> "DBINFO"> the returned I<HashRef> contains
lowercase keys. Additionally the following keys changed:

    CERTIFICATE_SERIAL      --> cert_key
    CERTIFICATE_SERIAL_HEX  --> cert_key_hex
    PUBKEY                  --> public_key
    CSR_SERIAL              --> req_key

=cut
command "get_cert" => {
    identifier => { isa => 'Base64', required => 1, },
    format     => { isa => 'AlphaPunct', matching => qr{ \A ( PEM | DER | TXT | TXTPEM | HASH | DBINFO ) \Z }x, default => "HASH" },
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
        return OpenXPKI::Crypt::X509->new( $cert->{data} )->data;
    }

    #
    # Format: "DBINFO"
    #
    if ('DBINFO' eq $format) {
        ##! 2: "Preparing output for DBINFO format"
        delete $cert->{data};
        my $extended_info = {};

        # Hex Serial
        my $serial = Math::BigInt->new($cert->{cert_key});
        $extended_info->{cert_key_hex} = $serial->as_hex;
        $extended_info->{cert_key_hex} =~ s{\A 0x}{}xms;

        # Expired Status
        $cert->{status} = 'EXPIRED' if $cert->{status} eq 'ISSUED' and $cert->{notafter} < time();

        # Fetch certificate attributes
        $extended_info->{cert_attributes} = {};
        my $cert_attr = $dbi->select(
            columns => [ qw(
                attribute_contentkey
                attribute_value
            ) ],
            from => 'certificate_attributes',
            where => { identifier => $identifier },
        );
        while (my $attr = $cert_attr->fetchrow_hashref) {
            my $key = $attr->{attribute_contentkey};
            my $val = $attr->{attribute_value};
            $extended_info->{cert_attributes}->{$key} //= [];
            push @{$extended_info->{cert_attributes}->{$key}}, $val;
        }

        return {
            %{ $cert },
            'cert_attributes' => $extended_info->{cert_attributes},
            'cert_key_hex'    => $extended_info->{cert_key_hex},
        };
    }

    ##! 2: "Requesting crypto token via API and creating X509 object"
    my $token = CTX('api')->get_default_token();

    if ($format eq 'TXT' || $format eq 'TXTPEM') {
        my $result = $token->command ({
            COMMAND => "convert_cert",
            DATA    => $cert->{data},
            OUT     => $format
        });
        return $result;
    };

    if ('PKCS7' eq $format) {
        my $result = $token->command({
            COMMAND          => 'convert_cert',
            DATA             => [ $cert->{data} ],
            OUT              => 'PEM',
            CONTAINER_FORMAT => 'PKCS7',
        });
        return $result;
    }

    my $obj = OpenXPKI::Crypto::X509->new(TOKEN => $token, DATA => $cert->{data});

    ##! 2: "Preparing output for HASH format"
    my $result = $obj->get_parsed_ref;

    # NOTBEFORE and NOTAFTER are DateTime objects, which we do
    # not want to be serialized, so we just send out the stringified
    # version ...
    $result->{BODY}->{NOTBEFORE} = $result->{BODY}->{NOTBEFORE}->epoch();
    $result->{BODY}->{NOTAFTER}  = $result->{BODY}->{NOTAFTER}->epoch();
    $result->{STATUS}            = $cert->{status};
    $result->{IDENTIFIER}        = $cert->{identifier};
    $result->{ISSUER_IDENTIFIER} = $cert->{issuer_identifier};
    $result->{CSR_SERIAL}        = $cert->{req_key};
    $result->{PKI_REALM}         = $cert->{pki_realm};
    return $result;

};

__PACKAGE__->meta->make_immutable;
