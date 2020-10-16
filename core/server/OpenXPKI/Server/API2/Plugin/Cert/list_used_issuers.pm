package OpenXPKI::Server::API2::Plugin::Cert::list_used_issuers;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Profile::list_used_issuers

=head1 COMMANDS

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );

=head2 list_used_issuers

List the identifiers and optional names of all issuers used in a realm.

B<Parameters>

=over

=item * C<pki_realm> I<Str> - PKI realm to query, defaults to the session realm

=item * C<pki_realm> I<Str> - PKI realm to query, defaults to the session realm

=back

=cut
command "list_used_issuers" => {
    pki_realm => { isa => 'AlphaPunct' },
    format     => { isa => 'Str', matching => qr{ \A ( identifier | label ) \Z }x, default => 'identifier' },
} => sub {
    my ($self, $params) = @_;

    my $pki_realm = $params->has_pki_realm ? $params->pki_realm : CTX('session')->data->pki_realm;

    my @res;
    my $dbi = CTX('dbi');
    if ($params->format eq 'label') {

        my $result = $dbi->select_hashes(
            from   => 'certificate',
            columns => [ 'identifier', 'subject' ],
            where => {
                identifier => $dbi->subselect(IN => {
                    from   => 'certificate',
                    columns => [ -distinct => 'issuer_identifier' ],
                    where => {
                        pki_realm => $pki_realm,
                        req_key => { '!=' => undef },
                    },
                }),
            },
        );

        @res = map {{
            value => $_->{identifier},
            label => $_->{subject}
        }} @$result;

    } else {

        my $result = CTX('dbi')->select_hashes(
            from   => 'certificate',
            columns => [ -distinct => 'issuer_identifier' ],
            where => {
                pki_realm => $pki_realm,
                req_key => { '!=' => undef },
            },
        );

        @res = map { $_->{issuer_identifier} } @$result;

    }

    return \@res;
};

__PACKAGE__->meta->make_immutable;
