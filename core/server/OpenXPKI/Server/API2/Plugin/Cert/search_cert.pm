package OpenXPKI::Server::API2::Plugin::Cert::search_cert;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Cert::search_cert

=head1 COMMANDS

=cut

# CPAN modules
use Regexp::Common;
use Data::Dumper;

# Project modules
use OpenXPKI::Debug;
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

=head2 search_cert

Search certificates by various attributes.

Returns an I<ArrayRef> of I<HashRefs>. The I<HashRefs> do not contain the data
field of the database to reduce the transport costs an avoid parser
implementations on the client.

B<Parameters>

All parameters are optional and can be used to filter the result list:

=over

=item * C<pki_realm> I<Str> - certificate realm. Specify "_any"
for a global search. Default: current session's realm

=item * C<entity_only> I<Bool> - certificate CA

=item * C<subject> I<Str> - subject pattern (does an SQL LIKE search
so you can use asterisk (*) as placeholder)

=item * C<issuer_dn> I<Str> - issuer pattern (does an SQL LIKE search
so you can use asterisk (*) as placeholder)

=item * C<cert_serial> I<Str> - serial number of certificate

=item * C<csr_serial> I<Str> - serial number of certificate request

=item * C<subject_key_identifier> I<Str> - X.509 certificate subject identifier

=item * C<issuer_identifier> I<Str> - issuer identifier

=item * C<authority_key_identifier> I<Str> - CA identifier

=item * C<identifier> I<Str> - internal certificate identifier (hash of PEM)

=item * C<profile> I<Str> - certificate profile name

=item * C<valid_before> I<Int> - certificate validity must start before this UNIX epoch timestamp

=item * C<valid_after> I<Int> - certificate validity must after before this UNIX epoch timestamp

=item * C<expires_before> I<Int> - certificate validity must end before this UNIX epoch timestamp

=item * C<expires_after> I<Int> - certificate validity must end after this UNIX epoch timestamp

=item * C<status> I<Str> - certificate status (for possible values see
L<OpenXPKI::Server::API2::Types/CertStatus>)

=item * C<cert_attributes> I<ArrayRef> - list of condition I<HashRefs> to search
in attributes (KEY, VALUE, OPERATOR). Operator can be "EQUAL", "LIKE" or
"BETWEEN".

=item * C<limit> I<Int> - result paging: only return the given number of results

=item * C<start> I<Int> - result paging: only return entries starting at given
index (can only be used if C<limit> was specified)

=item * C<order> I<Str> - order results by this table column (descending). Default: "cert_key"

=item * C<reverse> I<Bool> - order results ascending

=back

B<Changes compared to API v1:> The following parameters where removed in favor
of C<[valid|expires]_[before|after]>:

    valid_at
    notbefore
    notafter

=cut

command "search_cert" => {
    authority_key_identifier => {isa => 'Value',         matching => $re_alpha_string,      },
    cert_attributes          => {isa => 'ArrayRef',      },
    cert_serial              => {isa => 'Value',         matching => $re_int_or_hex_string, },
    csr_serial               => {isa => 'Value',         matching => $re_integer_string,    },
    entity_only              => {isa => 'Value',         matching => $re_boolean,           },
    expires_after            => {isa => 'Int', },
    expires_before           => {isa => 'Int', },
    identifier               => {isa => 'Value',         matching => $re_base64_string,     },
    issuer_dn                => {isa => 'Value' },
    issuer_identifier        => {isa => 'Value',         matching => $re_base64_string,     },
    limit                    => {isa => 'Value',         matching => $re_integer_string,    },
    order                    => {isa => 'Value' },
    pki_realm                => {isa => 'Value',         matching => $re_alpha_string,      },
    profile                  => {isa => 'Value',         matching => $re_alpha_string,      },
    reverse                  => {isa => 'Value',         matching => $re_boolean,           },
    start                    => {isa => 'Value',         matching => $re_integer_string,    },
    status                   => {isa => 'CertStatus' },
    subject                  => {isa => 'Value' },
    subject_key_identifier   => {isa => 'Value' },
    valid_after              => {isa => 'Int', },
    valid_before             => {isa => 'Int', },
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

Similar to L</cert_search> but only returns the number of matching rows.

B<Parameters>

All parameters are optional and can be used to filter the result list:

=over

=item * C<pki_realm> I<Str> - certificate realm. Specify "_any"
for a global search. Default: current session's realm

=item * C<entity_only> I<Bool> - certificate CA

=item * C<subject> I<Str> - subject pattern (does an SQL LIKE search
so you can use asterisk (*) as placeholder)

=item * C<issuer_dn> I<Str> - issuer pattern (does an SQL LIKE search
so you can use asterisk (*) as placeholder)

=item * C<cert_serial> I<Str> - serial number of certificate

=item * C<csr_serial> I<Str> - serial number of certificate request

=item * C<subject_key_identifier> I<Str> - X.509 certificate subject identifier

=item * C<issuer_identifier> I<Str> - issuer identifier

=item * C<authority_key_identifier> I<Str> - CA identifier

=item * C<identifier> I<Str> - internal certificate identifier (hash of PEM)

=item * C<profile> I<Str> - certificate profile name

=item * C<status> I<Str> - certificate status (for possible values see
L<OpenXPKI::Server::API2::Types/CertStatus>)

=item * C<cert_attributes> I<ArrayRef> - list of condition I<HashRefs> to search
in attributes (KEY, VALUE, OPERATOR). Operator can be "EQUAL", "LIKE" or
"BETWEEN".

=back

B<Changes compared to API v1:> The following parameters where removed in favor
of C<[valid|expires]_[before|after]>:

    valid_at
    notbefore
    notafter

=cut
command "search_cert_count" => {
    authority_key_identifier => {isa => 'Value',    matching => $re_alpha_string,      },
    cert_attributes          => {isa => 'ArrayRef', },
    cert_serial              => {isa => 'Value',    matching => $re_int_or_hex_string, },
    csr_serial               => {isa => 'Value',    matching => $re_integer_string,    },
    entity_only              => {isa => 'Value',    matching => $re_boolean,           },
    expires_after            => {isa => 'Int', },
    expires_before           => {isa => 'Int', },
    identifier               => {isa => 'Value',    matching => $re_base64_string,     },
    issuer_dn                => {isa => 'Value' },
    issuer_identifier        => {isa => 'Value',    matching => $re_base64_string,     },
    pki_realm                => {isa => 'Value',    matching => $re_alpha_string,      },
    profile                  => {isa => 'Value',    matching => $re_alpha_string,      },
    status                   => {isa => 'CertStatus' },
    subject                  => {isa => 'Value' },
    subject_key_identifier   => {isa => 'Value' },
    valid_after              => {isa => 'Int', },
    valid_before             => {isa => 'Int', },
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
    ##! 32: 'Arguments ' . Dumper $po

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

    if ($po->has_valid_before && $po->has_valid_after) {
        $where->{'certificate.notbefore'} = { -between => [ $po->valid_after, $po->valid_before ] };
    } elsif ($po->has_valid_before) {
        $where->{'certificate.notbefore'} = { '<', $po->valid_before }
    } elsif ($po->has_valid_after) {
        $where->{'certificate.notbefore'} = { '>', $po->valid_after }
    }

    if ($po->has_expires_before && $po->has_expires_after) {
        $where->{'certificate.notbefore'} = { -between => [ $po->expires_after, $po->expires_before ] };
    } elsif ($po->has_expires_before) {
        $where->{'certificate.notbefore'} = { '<', $po->expires_before }
    } elsif ($po->has_expires_after) {
        $where->{'certificate.notbefore'} = { '>', $po->expires_after }
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

    ##! 64: 'where ' . Dumper $where

    return $params;
}

__PACKAGE__->meta->make_immutable;
