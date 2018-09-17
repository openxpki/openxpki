package OpenXPKI::Server::API2::Plugin::Cert::get_crl_list;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Cert::get_crl_list

=cut

# Project modules
use Data::Dumper;
use OpenXPKI::Debug;
use MIME::Base64;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;


=head1 COMMANDS

=head2 get_crl_list

List all CRL issued in the given realm. If no realm is given, use the
realm of the current session. You can add issuer_identifier (cert_identifier)
in which case you get only the CRLs issued by this issuer.
The result is an arrayref of matching entries ordered by last_update,
newest first. I<limit> has a default of 25.

To find CRLs valid within a certain period in time, you can query on the
last_update/next_update fields using valid_after/valid_before and
expires_after/expires_before (expect epoch).

B<Parameters>

=over

=item * C<format>

Determines the return format.

Possible values for format are:

=over

=item * PEM

=item * DER

=item * DBINFO - unmodified result from the database (without PEM data)

=back

=item issuer_identifier

Get only the CRLs for the provided issuer. If not set CRLs for all issuers
in the current realm are returned.

=item limit

=item pki_realm

=item valid_after

=item valid_before

=item expires_after

=item expires_before

=back

B<Changes compared to API v1:>

Format TXT and HASH/FULLHASH have been removed, DBINFO returns lowercased
keys with some modifications. See get_crl for details.

I<valid_at> was replaced by the more detailed time filters.

=cut

command "get_crl_list" => {
    format     => { isa => 'AlphaPunct', matching => qr{ \A ( PEM | DER | DBINFO ) \Z }x, default => "DBINFO" },
    pki_realm  => { isa => 'AlphaPunct', },
    valid_after              => {isa => 'Int', },
    valid_before             => {isa => 'Int', },
    expires_after            => {isa => 'Int', },
    expires_before           => {isa => 'Int', },
#    issuer_dn                => {isa => 'Value' },
    issuer_identifier        => {isa => 'Value',},
    limit                    => {isa => 'Int', default => 25 },
} => sub {

    my ($self, $params) = @_;

    ##! 2: "initialize arguments"

    my $limit      = $params->limit;
    my $format     = $params->format;
    my $pki_realm  = $params->pki_realm;

    $pki_realm =  CTX('session')->data->pki_realm unless $pki_realm;

    my $where = {};
    if ($params->has_valid_before && $params->has_valid_after) {
        $where->{'last_update'} = { -between => [ $params->valid_after, $params->valid_before ] };
    } elsif ($params->has_valid_before) {
        $where->{'last_update'} = { '<', $params->valid_before }
    } elsif ($params->has_valid_after) {
        $where->{'last_update'} = { '>', $params->valid_after }
    }

    if ($params->has_expires_before && $params->has_expires_after) {
        $where->{'next_update'} = { -between => [ $params->expires_after, $params->expires_before ] };
    } elsif ($params->has_expires_before) {
        $where->{'next_update'} = { '<', $params->expires_before }
    } elsif ($params->has_expires_after) {
        $where->{'next_update'} = { '>', $params->expires_after }
    }

    if ($params->issuer_identifier) {
        $where->{'issuer_identifier'} = $params->issuer_identifier;
    } else {
        $where->{'pki_realm'} = $pki_realm;
    }

    my $db_results = CTX('dbi')->select(
        from => 'crl',
        columns => ( $format eq 'DBINFO' ? ['*'] : ['data'] ),
        where => $where,
        order_by => '-last_update',
        limit => $limit,
    );

    my @result;
    if ( $format eq 'DER' ) {

        while (my $entry = $db_results->fetchrow_hashref) {
            $entry->{data} =~ m{-----BEGIN[^-]*-----(.+)-----END[^-]*-----}xms;
            push @result, decode_base64($1);
        }

    } elsif($format eq 'PEM') {

        while (my $entry = $db_results->fetchrow_hashref) {
            push @result, $entry->{data};
        }

    } else {
        while (my $entry = $db_results->fetchrow_hashref) {
            delete $entry->{data};
            push @result, $entry;
        }
    }

    return \@result;

};


__PACKAGE__->meta->make_immutable;


