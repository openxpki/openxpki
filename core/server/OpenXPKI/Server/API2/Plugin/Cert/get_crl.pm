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
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;


=head1 COMMANDS

=head2 get_crl

returns a CRL.

If no parameter is set at all, the newest CRL of the active signer token
in the current realm is selected. To get the latest CRL of another issuer,
set I<issuer_identifier>, to select a particular CRL set I<crl_serial>.
Both works across realms.

The default is to return the PEM encoded CRL, other formats can be
selected setting I<format>.

B<Parameters>

=over

=item crl_serial

the serial (crl_key) of the database table

=item issuer_identifier

certificate identifier of the issuer, if set the latest crl of this
issuer is returned.

=item ignore_expired

Will return undef if the next_update timestamp of the lastest crl found
is in the past. Ineffective when used with I<crl_serial>.

=item profile

CRL profile. For security reasons you must set this also when requesting a
non-default CRL by its serial number!

=item format

=over

=item * PEM (default)

=item * DER

=item * TXT

=item * HASH - detailed information parsed from the CRL object

=item * FULLHASH also adds the list of revocation entries (this might
        become a very expensive task if your CRL is large!).

=item * DBINFO - unmodified result from the database

=back

=back

B<Changes compared to API v1:>

When called with C<format =E<gt> "DBINFO"> the returned I<HashRef> contains
lowercase keys. Additionally the following keys changed:

    crl_serial              --> crl_key

=cut

command "get_crl" => {
    crl_serial => { isa => 'Int', },
    profile  => { isa => 'Ident' },
    format     => { isa => 'AlphaPunct', matching => qr{ \A ( PEM | DER | TXT | HASH | FULLHASH | DBINFO ) \Z }x, default => "PEM" },
    issuer_identifier => { isa => 'Value', },
    ignore_expired =>  { isa => 'Bool', },
} => sub {

    my ($self, $params) = @_;

    ##! 2: "initialize arguments"

    my $crl_key    = $params->crl_serial;
    my $format     = $params->format;
    my $issuer_identifier = $params->issuer_identifier;


    my $db_results;

    my @columns = ($format eq 'DBINFO') ?
        ( 'pki_realm', 'last_update', 'next_update', 'crl_key', 'publication_date', 'issuer_identifier', 'items', 'crl_number' ) :
        ( 'pki_realm', 'data', 'crl_key' );


    if ($crl_key) {
        ##! 16: 'Load crl by db serial ' . $crl_key
        $db_results = CTX('dbi')->select_one(
            from => 'crl',
            columns => [ @columns, 'profile' ],
            where => {
                crl_key => $crl_key,
            },
        );

        my $profile = $params->profile || '';
        my $crl_profile = $db_results->{profile} || '';
        if ($crl_profile ne $profile) {
            OpenXPKI::Exception->throw(
                message => 'CRLs profile does not match requested profile',
                params => { crl_profile => $crl_profile, requested => $profile }
            );
        }

    } else {

        if (!$issuer_identifier) {
            my $ca_alias = $self->api->get_token_alias_by_type( type => 'certsign' );
            ##! 16: 'Load crl by date, ca alias ' . $ca_alias
            my $ca_hash = $self->api->get_certificate_for_alias( alias => $ca_alias );
            $issuer_identifier = $ca_hash->{identifier};
        }

        $db_results = CTX('dbi')->select_one(
            from => 'crl',
            columns => \@columns,
            where => {
                issuer_identifier => $issuer_identifier,
                profile => $params->profile ? $params->profile : undef,
            },
            order_by => '-last_update'
        );

        if ($db_results && $params->ignore_expired) {
            return if ($db_results->{next_update} < time());
        }
    }

    ##! 32: 'DB Result ' . Dumper $db_results

    if ( not $db_results ) {
        OpenXPKI::Exception->throw(
            message => 'No CRL found for the given query',
            params => {
                issuer_identifier => $issuer_identifier,
                crl_key => $crl_key,
            } );
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
                message => 'Unable to convert crl',
            );
        }
    }
    elsif ( $format eq 'HASH' or $format eq 'FULLHASH' ) {

        my $crl = OpenXPKI::Crypt::CRL->new($pem_crl);
        $output = $crl->to_hash();
        $output->{issuer_identifier} = $db_results->{issuer_identifier};
        $output->{crl_key} = $db_results->{crl_key};

        # this can be VERY expensive in large CRLs
        if ($format eq 'FULLHASH') {
            $output->{items} = $crl->items();
        }

    } else {
        $output = $pem_crl;
    }
    ##! 16: 'output: ' . Dumper $output
    return $output;
};

__PACKAGE__->meta->make_immutable;
