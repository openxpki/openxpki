package OpenXPKI::Server::API2::Command::Cert::Actions;
use Moose;

=head1 Name

OpenXPKI::Server::API2::Command::Cert::Actions - utility functions that do some
work for API commands

=cut

sub __search_cert_db_query {
    ##! 1: "start"
    my ($self, $args) = @_;

    my $where = {};
    my $params = {
        where => $where,
    };

    ##! 2: "initialize arguments"
    ##! 32: 'Arguments ' . Dumper $args

    if ( $args->{CERT_SERIAL} ) {
        my $serial = $args->{CERT_SERIAL};
        # autoconvert hexadecimal serial, needs to have 0x as prefix!
        if ($serial =~ /^0x/i) {
            my $sn = Math::BigInt->new( $serial );
            $serial = $sn->bstr();
        }
        $where->{'certificate.cert_key'} = $serial;
    }

    if ( defined $args->{LIMIT} ) {
        $params->{limit} = $args->{LIMIT};
        $params->{offset} = $args->{START} if $args->{START};
    }

    # only list entities issued by this ca
    if ($args->{ENTITY_ONLY}) {
        $where->{'certificate.req_key'} = { "!=" => undef };
    }

    # pki realm
    if (not $args->{PKI_REALM}) {
        $where->{'certificate.pki_realm'} = CTX('session')->data->pki_realm;
    } elsif ($args->{PKI_REALM} !~ /_any/i) {
        $where->{'certificate.pki_realm'} = $args->{PKI_REALM};
    }

    # Custom ordering
    my $desc = "-"; # not set or 0 means: DESCENDING, i.e. "-"
    $desc = "" if defined $args->{REVERSE} and $args->{REVERSE} == 0;
    # TODO #legacydb Code that removes table name prefix
    $args->{ORDER} =~ s/^CERTIFICATE\.// if $args->{ORDER};
    $params->{order_by} = sprintf "%s%s", $desc, ($args->{ORDER} // 'cert_key');

    # Handle status
    if ($args->{STATUS} and $args->{STATUS} eq 'EXPIRED') {
        delete $args->{STATUS};
        $where->{'certificate.status'} = 'ISSUED';
        $where->{'certificate.notafter'} = { '<', time() };
    }

    $where->{'certificate.identifier'}                = $args->{IDENTIFIER} if $args->{IDENTIFIER};
    $where->{'certificate.issuer_identifier'}         = $args->{ISSUER_IDENTIFIER} if $args->{ISSUER_IDENTIFIER};
    $where->{'certificate.req_key'}                   = $args->{CSR_SERIAL} if $args->{CSR_SERIAL};
    $where->{'certificate.status'}                    = $args->{STATUS} if $args->{STATUS};
    $where->{'certificate.subject_key_identifier'}    = $args->{SUBJECT_KEY_IDENTIFIER} if $args->{SUBJECT_KEY_IDENTIFIER};
    $where->{'certificate.authority_key_identifier'}  = $args->{AUTHORITY_KEY_IDENTIFIER} if $args->{AUTHORITY_KEY_IDENTIFIER};

    # sanitize wildcards (don't overdo it...)
    for my $key (qw( SUBJECT ISSUER_DN )) {
        next unless defined $args->{$key};
        $args->{$key} =~ s/\*/%/g;
        $args->{$key} =~ s/%%+/%/g;
    }
    $where->{'certificate.subject'}                   = { -like => $args->{SUBJECT} } if $args->{SUBJECT};
    $where->{'certificate.issuer_dn'}                 = { -like => $args->{ISSUER_DN} } if $args->{ISSUER_DN};

    if ( defined $args->{VALID_AT} ) {
        $where->{'certificate.notbefore'} = { '<=', $args->{VALID_AT} };
        $where->{'certificate.notafter'} =  { '>=', $args->{VALID_AT} };
    }

    # notbefore/notafter should only be used for timestamps outside
    # the validity interval, therefore the operators are fixed
    if ($args->{NOTBEFORE} ) {
        # TODO #legacydb search_cert's NOTBEFORE allows old DB layer syntax
        $where->{'certificate.notbefore'} = ref $args->{NOTBEFORE} eq 'HASH'
            ? OpenXPKI::Server::Database::Legacy->convert_dynamic_cond($args->{NOTBEFORE})
            : { '<', $args->{NOTBEFORE} };
    }

    if ($args->{NOTAFTER} ) {
        # TODO #legacydb search_cert's NOTAFTER allows old DB layer syntax
        $where->{'certificate.notafter'} = ref $args->{NOTAFTER} eq 'HASH'
            ? OpenXPKI::Server::Database::Legacy->convert_dynamic_cond($args->{NOTAFTER})
            : { '>', $args->{NOTAFTER} };
    }

    my @join_spec = ();

    # handle certificate attributes (such as SANs)
    if ( defined $args->{CERT_ATTRIBUTES} ) {
        if ( ref $args->{CERT_ATTRIBUTES} ne 'ARRAY' ) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_API_OBJECT_SEARCH_CERT_INVALID_CERT_ATTRIBUTES_ARGUMENTS',
                params => { 'TYPE' => ref $args->{CERT_ATTRIBUTES}, },
            );
        }

        # we need to join over the certificate_attributes table
        my $ii = 0;
        foreach my $attrib ( @{ $args->{CERT_ATTRIBUTES} } ) {
            ##! 16: 'certificate attribute: ' . Dumper $entry
            my $table_alias = "certattr$ii";

            # add join table
            push @join_spec, ( 'certificate.identifier=identifier', "certificate_attributes|$table_alias" );

            # add search constraint
            $where->{ "$table_alias.attribute_contentkey" } = $attrib->{KEY};

            $attrib->{OPERATOR} //= 'LIKE';
            # sanitize wildcards (don't overdo it...)
            if ($attrib->{OPERATOR} eq 'LIKE' && !(ref $attrib->{VALUE})) {
                $attrib->{VALUE} =~ s/\*/%/g;
                $attrib->{VALUE} =~ s/%%+/%/g;
            }
            # TODO #legacydb search_cert's CERT_ATTRIBUTES allows old DB layer syntax
            $where->{ "$table_alias.attribute_value" } =
                OpenXPKI::Server::Database::Legacy->convert_dynamic_cond($attrib);

            $ii++;
        }
    }

    if ( $args->{PROFILE} ) {
        push @join_spec, qw( certificate.req_key=req_key csr );
        $where->{ 'csr.profile' } = $args->{PROFILE};
    }

    if (scalar @join_spec) {
        $params->{from_join} = join " ", 'certificate', @join_spec;
    }
    else {
        $params->{from} = 'certificate',
    };

    return $params;
}

__PACKAGE__->meta->make_immutable;
