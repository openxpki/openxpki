package OpenXPKI::Server::API2::Plugin::Cert::get_crl;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Cert::get_crl

=cut

# Project modules
use Data::Dumper;
use MIME::Base64;
use OpenXPKI::Debug;
use OpenXPKI::Crypt::CRL;
use OpenXPKI::Crypto::CRL;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;


=head1 COMMANDS

=head2 get_crl

returns a CRL. The possible parameters are crl_serial, format and pki_realm.
crl_serial is the serial of the database table, the realm defaults to the
current realm and the default format is PEM.

If no serial is given, the most current CRL of the active signer token
in the current realm is returned.

Possible values for format are:

=over

=item * PEM

=item * DER

=item * TXT

=item * HASH - detailed information parsed from the CRL object

=item * FULLHASH also adds the list of revocation entries (this might
        become a very expensive task if your CRL is large!).

=item * DBINFO - unmodified result from the database

=back

B<Parameters>

=over

=item * C<XXX> I<Bool> - XXX. Default: XXX

=back

B<Changes compared to API v1:>

When called with C<format =E<gt> "DBINFO"> the returned I<HashRef> contains
lowercase keys. Additionally the following keys changed:

    crl_serial              --> crl_key

=cut

command "get_crl" => {
    crl_serial => { isa => 'Int', },
    format     => { isa => 'AlphaPunct', matching => qr{ \A ( PEM | DER | TXT | HASH | FULLHASH | DBINFO ) \Z }x, default => "PEM" },
    pki_realm  => { isa => 'AlphaPunct', },
} => sub {

    my ($self, $params) = @_;

    ##! 2: "initialize arguments"

    my $crl_key    = $params->crl_serial;
    my $format     = $params->format;
    my $pki_realm  = $params->pki_realm;

    $pki_realm =  CTX('session')->data->pki_realm unless $pki_realm;

    my $db_results;

    my $columns = ($format eq 'DBINFO') ?
        [ 'pki_realm', 'last_update', 'next_update', 'crl_key', 'publication_date', 'issuer_identifier', 'items', 'crl_number' ] :
        [ 'pki_realm', 'data', 'crl_key' ];


    if ($crl_key) {
        ##! 16: 'Load crl by db serial ' . $crl_key
        $db_results = CTX('dbi')->select_one(
            from => 'crl',
            columns => $columns,
            where => {
                'crl_key' => $crl_key,
            },
        );

    } else {

        my $ca_alias = $self->api->get_token_alias_by_type( type => 'certsign' );
        ##! 16: 'Load crl by date, ca alias ' . $ca_alias
        my $ca_hash = $self->api->get_certificate_for_alias( alias => $ca_alias );

        $db_results = CTX('dbi')->select_one(
            from => 'crl',
            columns => $columns,
            where => {
                issuer_identifier => $ca_hash->{identifier}
            },
            order_by => '-last_update'
        );
    }

    ##! 32: 'DB Result ' . Dumper $db_results

    if ( not $db_results ) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_CRL_NOT_FOUND', );
    }

    if ($pki_realm ne $db_results->{pki_realm}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_CRL_NOT_IN_REALM', );
    }

    my $pem_crl = $db_results->{data};

    my $output;
    if ($format eq 'DBINFO') {
        $output = $db_results;
    }
    elsif ( $format eq 'DER'  ) {

        $pem_crl =~ m{-----BEGIN[^-]*-----(.+)-----END[^-]*-----}xms;
        $output = decode_base64($1);

    }
    elsif ( $format eq 'TXT' ) {

        # convert the CRL
        my $default_token = $self->api->get_default_token();
        $output = $default_token->command({
            COMMAND => 'convert_crl',
            OUT     => $format,
            IN      => 'PEM',
            DATA    => $pem_crl,
        });
        if (!$output) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_API_OBJECT_GET_CRL_UNABLE_TO_CONVERT',
            );
        }
    }
    elsif ( $format eq 'HASH' or $format eq 'FULLHASH' ) {

        # parse CRL using OpenXPKI::Crypto::CRL
        my $default_token = $self->api->get_default_token();
        my $crl_obj = OpenXPKI::Crypto::CRL->new(
            TOKEN => $default_token,
            DATA  => $pem_crl,
            REVOKED => 0,
        );
        my $ref =  $crl_obj->get_parsed_ref();
        ##! 16: 'object: ' . Dumper $ref

        $output = {};
        map { $output->{lc($_)} = $ref->{BODY}->{$_};  }
            ('ISSUER', 'SIGNATURE_ALGORITHM', 'NEXT_UPDATE', 'LAST_UPDATE', 'VERSION', 'ITEMCNT', 'SERIAL');

        $output->{issuer_identifier} = $db_results->{issuer_identifier};
        $output->{crl_key} = $db_results->{crl_key};

        if ($format eq 'FULLHASH') {
            my $crl = OpenXPKI::Crypt::CRL->new( $pem_crl);
            $output->{items} = $crl->items();
        }

    } else {
        $output = $pem_crl;
    }
    ##! 16: 'output: ' . Dumper $output
    return $output;
};

__PACKAGE__->meta->make_immutable;
