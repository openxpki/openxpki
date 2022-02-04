package OpenXPKI::Server::API2::Plugin::Import::import_crl;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Import::import_crl

=cut


# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::Crypt::CRL;


=head1 COMMANDS

=head2 import_crl

Import a CRL into the current realm. This should be used only within realms that
work as a proxy to external CA systems or use external CRL signer tokens.

The issuer is extracted from the CRL. Note that the issuer must be defined as
alias in the C<certsign> group.

A check for duplicate CRLs is done based on C<issuer> and C<crl_number>, in
case the given CRL has no CRL Number extension, it is considered as
duplicate if an existing CRL without number and the same value for
C<last_update> and C<next_update> exists.

By default, the method throws an exception if the given CRL exists already,
you can set I<skip_duplicate> to silently ignore duplicates in which case no
new record will be created and the existing one will be returned.

The content of the CRL is NOT parsed, therefore the certificate status of
revoked certificates is NOT changed in the database!

Returns a I<HashRef> with the CRL informations inserted into the database, e.g.:

    {
        crl_key => '6655',
        profile => undef, 
        issuer_identifier => 'RE35XR3XIBXiIbAu8P5aGMCmH7o',
        last_update => 1521556123,
        next_update => 3098356123,
        pki_realm => 'democa',
        publication_date => 0,
        items =>  42,
        crl_number  => 1234567,
    }

B<Parameters>

=over

=item * C<data> I<Str> - PEM formated CRL. Required.

=item * C<profile> I<Str> - sets the profile field for the CRL, optional.

=item * C<skip_duplicate> I<Bool>

=item * C<nosigner> I<Bool> - import CRLs for issuers not in the certsign group

=back

B<Changes compared to API v1:>

The previously unused parameter C<ISSUER> was removed.

=cut
command "import_crl" => {
    data   => { isa => 'PEM', required => 1, },
    profile  => { isa => 'Ident' },
    skip_duplicate => { isa => 'Bool', default=> 0, },
    nosigner => { isa => 'Bool', default=> 0, },
} => sub {
    my ($self, $params) = @_;

    my $pki_realm = CTX('session')->data->pki_realm;
    my $dbi = CTX('dbi');

    my $crl = OpenXPKI::Crypt::CRL->new( $params->data );

    # Find the issuer certificate
    my $issuer_aik = $crl->get_authority_key_id();
    my $issuer_dn = $crl->get_issuer();

    my $issuer;
    # by default a CRL must match a signer certificate
    if ($params->nosigner) {
        $issuer = $dbi->select_one(
            from => 'certificate',
            columns => [ 'identifier' ],
            where => {
                $issuer_aik
                    ? ('subject_key_identifier' => $issuer_aik)
                    : ('subject' => $issuer_dn),
            }
        ) or OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_UI_IMPORT_CRL_ISSUER_NOT_FOUND',
            params => { issuer_dn => $issuer_dn , issuer_aik => $issuer_aik },
        );

    } else {

        # We need the group name for the alias group
        my $group = CTX('config')->get(['crypto', 'type', 'certsign']);

        ##! 16: 'Look for issuer ' . $issuer_aik . '/' . $issuer_dn . ' in group ' . $group

        my $where = {
            'aliases.pki_realm' => $pki_realm,
            'aliases.group_id' => $group,
            $issuer_aik
                ? ('certificate.subject_key_identifier' => $issuer_aik)
                : ('certificate.subject' => $issuer_dn),
        };

        $issuer = $dbi->select_one(
            from_join => 'certificate  identifier=identifier aliases',
            columns => [ 'certificate.identifier' ],
            where => $where
        ) or OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_UI_IMPORT_CRL_ISSUER_NOT_FOUND',
            params => { issuer_dn => $issuer_dn , group => $group, issuer_aik => $issuer_aik },
        );
    }
    ##! 32: 'Issuer ' . Dumper $issuer

    my $serial = $dbi->next_id('crl');
    my $ca_identifier = $issuer->{identifier};

    my $data = {
        pki_realm         => $pki_realm,
        issuer_identifier => $ca_identifier,
        crl_key           => $serial,
        crl_number        => $crl->crl_number() // '',
        last_update       => $crl->last_update(),
        next_update       => $crl->next_update(),
        publication_date  => 0,
        items             => $crl->itemcnt(),
        data              => $crl->pem(),
    };

    if ( $params->profile ) {
        $data->{profile} = $params->profile;
    }

    my $where_duplicate = {
        pki_realm         => $pki_realm,
        issuer_identifier => $ca_identifier,
        crl_number => $data->{crl_number},
    };

    if (!$data->{crl_number}) {
        $where_duplicate->{last_update} = $data->{last_update};
        $where_duplicate->{next_update} = $data->{next_update};
    }

    ##! 64: 'Duplicate query ' . Dumper $where_duplicate
    my $duplicate = $dbi->select_one(
        from => 'crl',
        columns => $params->skip_duplicate ?
            [ 'pki_realm', 'issuer_identifier', 'crl_key', 'crl_number', 'items', 'last_update', 'next_update', 'publication_date' ] :
            [ 'crl_key' ],
        where => $where_duplicate,
    );

    if (!$duplicate) {
        $dbi->insert( into => 'crl', values => $data );
        delete $data->{data};
        CTX('log')->application()->info("Imported CRL for issuer $issuer_dn");
    } elsif ($params->skip_duplicate) {
        CTX('log')->application()->info("CRL is already in database and skip_duplicate is set");
        $data = $duplicate;
    } else {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_UI_IMPORT_CRL_DUPLICATE',
            params => {
                'issuer_identifier' => $ca_identifier,
                'last_update' => $data->{last_update},
                'next_update' => $data->{next_update},
                'crl_key' => $duplicate->{crl_key},
            },
        );
    }


    ##! 32: 'CRL Data ' . Dumper $data
    return $data;
};

__PACKAGE__->meta->make_immutable;
