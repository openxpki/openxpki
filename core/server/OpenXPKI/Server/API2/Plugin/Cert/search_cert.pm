package OpenXPKI::Server::API2::Plugin::Cert::search_cert;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 Name

OpenXPKI::Server::API2::Plugin::Cert::search_cert - search certificates

=head1 Parameters

=cut

# CPAN modules
use Regexp::Common;

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Server::Database::Legacy;

my $re_all               = qr{ \A .* \z }xms;
my $re_alpha_string      = qr{ \A [ \w \- \. : \s ]* \z }xms;
my $re_integer_string    = qr{ \A $RE{num}{int} \z }xms;
my $re_int_or_hex_string = qr{ \A ([0-9]+|0x[0-9a-fA-F]+) \z }xms;
my $re_boolean           = qr{ \A [01] \z }xms;
my $re_base64_string     = qr{ \A [A-Za-z0-9\+/=_\-]* \z }xms;
my $re_cert_string       = qr{ \A [A-Za-z0-9\+/=_\-\ \n]+ \z }xms;
my $re_filename_string   = qr{ \A [A-Za-z0-9\+/=_\-\.]* \z }xms;
my $re_image_format      = qr{ \A (ps|png|jpg|gif|cmapx|imap|svg|svgz|mif|fig|hpgl|pcl|NULL) \z }xms;
my $re_cert_format       = qr{ \A (PEM|DER|TXT|PKCS7|HASH) \z }xms;
my $re_crl_format        = qr{ \A (PEM|DER|TXT|HASH|RAW|FULLHASH|DBINFO) \z }xms;
my $re_privkey_format    = qr{ \A (PKCS8_PEM|PKCS8_DER|OPENSSL_(PRIVKEY|RSA)|PKCS12|JAVA_KEYSTORE) \z }xms;
# TODO - consider opening up re_sql_string even more, currently this means
# that we can not search for unicode characters in certificate subjects,
# for example ...
my $re_sql_string        = qr{ \A [a-zA-Z0-9\@\-_\.\s\%\*\+\=\,\:\ ]* \z }xms;
my $re_sql_field_name    = qr{ \A [a-zA-Z0-9_\.]+ \z }xms;
my $re_approval_msg_type = qr{ \A (CSR|CRR) \z }xms;
my $re_approval_lang     = qr{ \A (de_DE|en_US|ru_RU) \z }xms;
my $re_csr_format        = qr{ \A (PEM|DER|TXT) \z }xms;
my $re_pkcs10            = qr{ \A [A-za-z0-9\+/=_\-\r\n\ ]+ \z}xms;

command "search_cert" => {
    authority_key_identifier => {isa => 'Value',         matching => $re_alpha_string,      },
    cert_attributes          => {isa => 'ArrayRef',      },
    cert_serial              => {isa => 'Value',         matching => $re_int_or_hex_string, },
    csr_serial               => {isa => 'Value',         matching => $re_integer_string,    },
    entity_only              => {isa => 'Value',         matching => $re_boolean,           },
    identifier               => {isa => 'Value',         matching => $re_base64_string,     },
    issuer_dn                => {isa => 'Value' },
    issuer_identifier        => {isa => 'Value',         matching => $re_base64_string,     },
    limit                    => {isa => 'Value',         matching => $re_integer_string,    },
    notafter                 => {isa => 'Value|HashRef', },
    notbefore                => {isa => 'Value|HashRef', },
    order                    => {isa => 'Value' },
    pki_realm                => {isa => 'Value',         matching => $re_alpha_string,      },
    profile                  => {isa => 'Value',         matching => $re_alpha_string,      },
    reverse                  => {isa => 'Value',         matching => $re_boolean,           },
    start                    => {isa => 'Value',         matching => $re_integer_string,    },
    status                   => {isa => 'CertStatus' },
    subject                  => {isa => 'Value' },
    subject_key_identifier   => {isa => 'Value' },
    valid_at                 => {isa => 'Value',         matching => $re_integer_string,    },
} => sub {
    my ($self, $params) = @_;

    my $sql_params = {
        %{ $self->_make_db_query($params) },
        %{ $self->_make_db_query_additional_params($params) },
    };

    my $result = CTX('dbi')->select(
        %{$sql_params},
        columns => [ 'certificate.*' ],
    )->fetchall_arrayref({});

    return $result;
};

=head2 search_cert_count

Same as cert_search, returns the number of matching rows

=cut
command "search_cert_count" => {
    authority_key_identifier => {isa => 'Value',    matching => $re_alpha_string,      },
    cert_attributes          => {isa => 'ArrayRef', },
    cert_serial              => {isa => 'Value',    matching => $re_int_or_hex_string, },
    csr_serial               => {isa => 'Value',    matching => $re_integer_string,    },
    entity_only              => {isa => 'Value',    matching => $re_boolean,           },
    identifier               => {isa => 'Value',    matching => $re_base64_string,     },
    issuer_dn                => {isa => 'Value' },
    issuer_identifier        => {isa => 'Value',    matching => $re_base64_string,     },
    notafter                 => {isa => 'Value|HashRef', },
    notbefore                => {isa => 'Value|HashRef', },
    pki_realm                => {isa => 'Value',    matching => $re_alpha_string,      },
    profile                  => {isa => 'Value',    matching => $re_alpha_string,      },
    status                   => {isa => 'CertStatus' },
    subject                  => {isa => 'Value' },
    subject_key_identifier   => {isa => 'Value' },
    valid_at                 => {isa => 'Value',    matching => $re_integer_string,    },
} => sub {
    my ($self, $params) = @_;

    my $sql_params = $self->_make_db_query($params);

    my $result = CTX('dbi')->select_one(
        %{$sql_params},
        columns => [ 'COUNT(certificate.identifier)|amount' ],
    );
    return $result->{amount};
};

# handle additional parameters only for search_cert: limit, order, reverse, start
sub _make_db_query_additional_params {
    my ($self, $po) = @_;

    my $params = {};

    if ( $po->has_limit ) {
        $params->{limit} = $po->limit;
        $params->{offset} = $po->start if $po->has_start;
    }

    # Custom ordering
    my $desc = "-"; # not set or 0 means: DESCENDING, i.e. "-"
    $desc = "" if $po->has_reverse and $po->reverse == 0;
    $params->{order_by} = sprintf "%scertificate.%s", $desc, lc($po->has_order ? $po->order : 'cert_key');

    return $params;
}

sub _make_db_query {
    my ($self, $po) = @_;

    my $where = {};
    my $params = {
        where => $where,
    };

    ##! 2: "initialize arguments"
    ##! 32: 'Arguments ' . Dumper $args

    if ( $po->has_cert_serial ) {
        my $serial = $po->cert_serial;
        # autoconvert hexadecimal serial, needs to have 0x as prefix!
        if ($serial =~ /^0x/i) {
            my $sn = Math::BigInt->new( $serial );
            $serial = $sn->bstr();
        }
        $where->{'certificate.cert_key'} = $serial;
    }

    # only list entities issued by this ca
    if ($po->has_entity_only) {
        $where->{'certificate.req_key'} = { "!=" => undef };
    }

    # pki realm
    if (not $po->has_pki_realm) {
        $where->{'certificate.pki_realm'} = CTX('session')->data->pki_realm;
    } elsif ($po->pki_realm !~ /_any/i) {
        $where->{'certificate.pki_realm'} = $po->pki_realm;
    }

    # Handle status
    if ($po->has_status and $po->status eq 'EXPIRED') {
        $po->clear_status;
        $where->{'certificate.status'} = 'ISSUED';
        $where->{'certificate.notafter'} = { '<', time() };
    }

    $where->{'certificate.identifier'}                = $po->identifier                 if $po->has_identifier;
    $where->{'certificate.issuer_identifier'}         = $po->issuer_identifier          if $po->has_issuer_identifier;
    $where->{'certificate.req_key'}                   = $po->csr_serial                 if $po->has_csr_serial;
    $where->{'certificate.status'}                    = $po->status                     if $po->has_status;
    $where->{'certificate.subject_key_identifier'}    = $po->subject_key_identifier     if $po->has_subject_key_identifier;
    $where->{'certificate.authority_key_identifier'}  = $po->authority_key_identifier   if $po->has_authority_key_identifier;

    # sanitize wildcards (don't overdo it...)
    for my $key (qw( subject issuer_dn )) {
        my $predicate = "has_$key";
        next unless $po->$predicate;
        my $tmp = $po->$key;
        $tmp =~ s/\*/%/g;
        $tmp =~ s/%%+/%/g;
        $po->$key($tmp);
    }
    $where->{'certificate.subject'}                   = { -like => $po->subject }       if $po->has_subject;
    $where->{'certificate.issuer_dn'}                 = { -like => $po->issuer_dn }     if $po->has_issuer_dn;

    if ($po->has_valid_at) {
        $where->{'certificate.notbefore'} = { '<=', $po->valid_at };
        $where->{'certificate.notafter'} =  { '>=', $po->valid_at };
    }

    # notbefore/notafter should only be used for timestamps outside
    # the validity interval, therefore the operators are fixed
    if ($po->has_notbefore) {
        # TODO #legacydb search_cert's NOTBEFORE allows old DB layer syntax
        $where->{'certificate.notbefore'} = ref $po->notbefore eq 'HASH'
            ? OpenXPKI::Server::Database::Legacy->convert_dynamic_cond($po->notbefore)
            : { '<', $po->notbefore };
    }

    if ($po->has_notafter ) {
        # TODO #legacydb search_cert's NOTAFTER allows old DB layer syntax
        $where->{'certificate.notafter'} = ref $po->notafter eq 'HASH'
            ? OpenXPKI::Server::Database::Legacy->convert_dynamic_cond($po->notafter)
            : { '>', $po->notafter };
    }

    my @join_spec = ();

    # handle certificate attributes (such as SANs)
    if ( $po->has_cert_attributes ) {
        # we need to join over the certificate_attributes table
        my $ii = 0;
        foreach my $attrib ( @{ $po->cert_attributes } ) {
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

    if ( $po->has_profile ) {
        push @join_spec, qw( certificate.req_key=req_key csr );
        $where->{ 'csr.profile' } = $po->profile;
    }

    if (scalar @join_spec) {
        $params->{from_join} = join " ", 'certificate', @join_spec;
    }
    else {
        $params->{from} = 'certificate',
    };

    return $params;
}

=over

=item * CERT_SERIAL

=item * LIMIT

=item * LAST

=item * FIRST

=item * CSR_SERIAL

=item * SUBJECT

=item * ISSUER_DN

=item * ISSUER_IDENTIFIER

=item * PKI_REALM (default is the sessions realm, _any for global search)

=item * PROFILE

=item * VALID_AT

=item * NOTBEFORE/NOTAFTER (with SCALAR searches "other side" of validity or pass HASH with operator)

=item * CERT_ATTRIBUTES list of conditions to search in attributes (KEY, VALUE, OPERATOR)
Operator can be "EQUAL", "LIKE" or "BETWEEN" and any other value will lead to
error "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_UNKNOWN_OPERATOR".

=item * ENTITY_ONLY (show only certificates issued by this ca)

=item * SUBJECT_KEY_IDENTIFIER

=item * AUTHORITY_KEY_IDENTIFIER

=back

The result is an array of hashes. The hashes do not contain the data field
of the database to reduce the transport costs an avoid parser implementations
on the client.

=cut


__PACKAGE__->meta->make_immutable;
