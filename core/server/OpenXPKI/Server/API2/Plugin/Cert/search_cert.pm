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

has 'return_columns_default' => (
    isa => 'ArrayRef',
    is => 'rw',
    default => sub { return [qw(
        identifier
        issuer_dn
        issuer_identifier
        cert_key
        subject
        status
        notbefore
        notafter
    )]}
);

=head2 search_cert

Search certificates by various attributes.

Returns an I<ArrayRef> of I<HashRefs>. To save transport and
parsing cost, the I<HashRefs> only contain a subset of fields:

    identifier
    issuer_dn
    issuer_identifier
    cert_key
    subject
    status
    notbefore
    notafter
    pki_realm*

The field pki_realm is added if the query contains realm=_any and
I<return_column> is not set. If you want to receive another
fieldset, set the field names via I<return_column>.
Extra columns available with the default schema are:

    subject_key_identifier
    authority_key_identifier
    revocation_time
    reason_code
    invalidity_time
    reason_code
    req_key
    data

B<Note:> When I<cert_attributes> are used to search for attributes that are
not part of the I<return_attributes> list, possible duplicate matches are
eliminated using the "DISTINCT" keyword in the query. This requires that
columns used to order the result set are included in the list of columns.
This case is handled internally by the method but be aware that your result
set can contain those columns even if not explicitly specified.

There is also a limitation for some RDBMS that BLOB columns such as I<data>
can not be used with distinct. Requesting a BLOB columns while DISTINTCT is
used and will result in a server side exception.

B<Parameters>

All parameters are optional and can be used to filter the result list:

=over

=item * C<pki_realm> L<AlphaPunct|OpenXPKI::Server::API2::Types/AlphaPunct> - certificate realm. Specify "_any"
for a global search. Default: current session's realm

=item * C<entity_only> I<Bool> - certificate CA

=item * C<subject> I<Str> - subject pattern (does an SQL LIKE search
so you can use asterisk (*) as placeholder)

=item * C<issuer_dn> I<Str> - issuer pattern (does an SQL LIKE search
so you can use asterisk (*) as placeholder)

=item * C<cert_serial> L<IntOrHex|OpenXPKI::Server::API2::Types/IntOrHex> - serial number of certificate

=item * C<csr_serial> I<Int> - serial number of certificate request

=item * C<subject_key_identifier> I<Str> - X.509 certificate subject identifier

=item * C<issuer_identifier> L<Base64|OpenXPKI::Server::API2::Types/Base64> - issuer identifier

=item * C<authority_key_identifier> L<AlphaPunct|OpenXPKI::Server::API2::Types/AlphaPunct> - CA identifier

=item * C<identifier> L<Base64|OpenXPKI::Server::API2::Types/Base64> - internal certificate identifier (hash of PEM)

=item * C<profile> L<ArrayOrAlphaPunct|OpenXPKI::Server::API2::Types/ArrayOrAlphaPunct> - certificate profile name

=item * C<valid_before> I<Int> - certificate validity must start before this UNIX epoch timestamp

=item * C<valid_after> I<Int> - certificate validity must after before this UNIX epoch timestamp

=item * C<expires_before> I<Int> - certificate validity must end before this UNIX epoch timestamp

=item * C<expires_after> I<Int> - certificate validity must end after this UNIX epoch timestamp

=item * C<revoked_before> I<Int> - certificate revocation date is before this UNIX epoch timestamp

=item * C<revoked_after> I<Int> - certificate revocation date is after this UNIX epoch timestamp

=item * C<invalid_before> I<Int> - certificate invalidity date is before this UNIX epoch timestamp

=item * C<invalid_after> I<Int> - certificate invalidity  date is after this UNIX epoch timestamp

=item * C<status> L<CertStatus|OpenXPKI::Server::API2::Types/CertStatus> - certificate status

=item * C<cert_attributes> I<HashRef> - key is attribute name, value is passed
"as is" as where statement on value, see documentation of SQL::Abstract.

Legacy: I<ArrayRef> - list of condition I<HashRefs> to search
in attributes (KEY, VALUE, OPERATOR). Operator can be "EQUAL", "LIKE" or
"BETWEEN".

=item * C<limit> I<Int> - result paging: only return the given number of results

=item * C<start> I<Int> - result paging: only return entries starting at given
index (can only be used if C<limit> was specified)

=item * C<order> I<Str> - order results by this table column (descending).
Default: "notbefore" (+req_key to properly work with duplicates).
Set to the empty string to return the result unsorted.

=item * C<reverse> I<Bool> - order results ascending

=item * C<return_attributes> L<ArrayRefOrStr|OpenXPKI::Server::API2::Types/ArrayRefOrStr> - add the given attributes as
columns to the result set. Each attribute is added as extra column
using the attribute name as key.

Note: If the attribute is multivalued or you use an attribute query that
causes multiple result lines for a single certificate you will get more
than one line for the same certificate!

=item * C<return_columns> L<ArrayRefOrStr|OpenXPKI::Server::API2::Types/ArrayRefOrStr> - set the columns from the base
table that should be included in the returned hashref. By default this
replaces the default columns, if you want the columns to extend the default
set put the plus sign '+' as first column name.

  return_columns => [ '+', 'subject_key_identifier, .... ]

=back

B<Changes compared to API v1:> The following parameters where removed in favor
of C<[valid|expires]_[before|after]>:

    valid_at
    notbefore
    notafter

=cut

# parameters common for search_cert and search_cert_count
my %common_params = (
    authority_key_identifier => { isa => 'AlphaPunct' },
    cert_attributes          => { isa => 'ArrayRef|HashRef' },
    return_attributes        => { isa => 'ArrayRefOrStr', coerce => 1 },
    cert_serial              => { isa => 'IntOrHex', coerce => 1 },
    csr_serial               => { isa => 'Int' },
    entity_only              => { isa => 'Bool' },
    expires_after            => { isa => 'Int' },
    expires_before           => { isa => 'Int' },
    identifier               => { isa => 'Base64' },
    issuer_dn                => { isa => 'Str' },
    issuer_identifier        => { isa => 'Base64' },
    pki_realm                => { isa => 'AlphaPunct' },
    profile                  => { isa => 'AlphaPunct|ArrayOrAlphaPunct' },
    status                   => { isa => 'CertStatus' },
    subject                  => { isa => 'Str' },
    subject_key_identifier   => { isa => 'Str' },
    valid_after              => { isa => 'Int' },
    valid_before             => { isa => 'Int' },
    revoked_before           => { isa => 'Int' },
    revoked_after            => { isa => 'Int' },
    invalid_before           => { isa => 'Int' },
    invalid_after            => { isa => 'Int' },
);

command "search_cert" => {
    %common_params,
    return_columns           => { isa => 'ArrayRefOrStr', coerce => 1 },
    limit                    => { isa => 'Int' },
    order                    => { isa => 'Str' },
    reverse                  => { isa => 'Bool' },
    start                    => { isa => 'Int' },
} => sub {
    my ($self, $params) = @_;

    my $sql_params = $self->_make_db_query($params);

    # Note: columns might be already set if return attributes is used
    if ( $params->has_return_columns ) {
        # to avoid ambiguties when we merge with CSR or attributes
        my @col = map { 'certificate.'.lc($_) } @{$params->return_columns};
        if ($params->return_columns->[0] eq '+') {
            shift @col;
            map { push @{$sql_params->{columns}}, 'certificate.'.$_ } @{$self->return_columns_default()};
        }
        push @{$sql_params->{columns}}, @col;
    } else {
        map { push @{$sql_params->{columns}}, 'certificate.'.$_ } @{$self->return_columns_default()};
        if ($params->has_pki_realm && $params->pki_realm =~ /_any/i) {
            push @{$sql_params->{columns}}, 'certificate.pki_realm';
        }
    }

    if ( $params->has_limit ) {
        $sql_params->{limit} = $params->limit;
        $sql_params->{offset} = $params->start if $params->has_start;
    }

    # Custom ordering
    my $desc = "-"; # not set or 0 means: DESCENDING, i.e. "-"
    $desc = "" if $params->has_reverse and $params->reverse == 0;

    # if the query uses distinct the order column must be in the selected columns
    my %columns = map { $_ => 1 } @{$sql_params->{columns}};
    if ($params->has_order) {
        if ($params->order) {
            my $col = "certificate." . lc($params->order);
            $sql_params->{order_by} =  $desc.$col;
            if ($sql_params->{distinct} && !$columns{ $col }) {
                push @{$sql_params->{columns}}, $col;
            }
        }
    } else {
        if ($sql_params->{distinct}) {
            if (!$columns{'certificate.notbefore'}) { push @{$sql_params->{columns}}, 'certificate.notbefore'; }
            if (!$columns{'certificate.req_key'}) { push @{$sql_params->{columns}}, 'certificate.req_key'; }
        }
        if ($desc) {
            $sql_params->{order_by} = [ '-certificate.notbefore', '-certificate.req_key' ];
        } else {
            $sql_params->{order_by} = [ 'certificate.notbefore', 'certificate.req_key' ];
        }
    }


    ##! 32: 'Query ' . Dumper $sql_params

    my $result = CTX('dbi')->select(
        %{$sql_params}
    )->fetchall_arrayref({});

    ##! 128: 'Result ' . Dumper $result

    return $result;
};

=head2 search_cert_count

Similar to L</cert_search> but only returns the number of matching rows.

B<Parameters>

All parameters are optional and can be used to filter the result list:

see L</search_cert> for parameter list (except C<limit>, C<start>, C<order> and
C<reverse> parameters which are not used in C<search_cert_count>).

B<Changes compared to API v1:> The following parameters where removed in favor
of C<[valid|expires]_[before|after]>:

    valid_at
    notbefore
    notafter

=cut
command "search_cert_count" => {
    %common_params
} => sub {
    my ($self, $params) = @_;

    my $sql_params = $self->_make_db_query($params);

    # for counting the rows the return columns are irrelevant
    push @{$sql_params->{columns}}, 'certificate.identifier';

    ##! 32: 'Query ' . Dumper $sql_params
    return CTX('dbi')->count(
        %{$sql_params}
    );

};

sub _make_db_query {
    my ($self, $po) = @_;

    my $where = {};
    my $params = {
        columns => [],
        where => $where,
    };

    ##! 2: "initialize arguments"
    ##! 32: 'Arguments ' . Dumper $po

    if ( $po->has_cert_serial ) {
        $where->{'certificate.cert_key'} = $po->cert_serial;
    }

    # only list entities issued by this ca
    if ($po->has_entity_only && $po->entity_only) {
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
    } elsif ($po->has_status and $po->status eq 'VALID') {
        $po->clear_status;
        $where->{'certificate.status'} = 'ISSUED';
        $where->{'certificate.notafter'} = { '>', time() };
        $where->{'certificate.notbefore'} = { '<', time() };
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
        $where->{'certificate.notafter'} = { -between => [ $po->expires_after, $po->expires_before ] };
    } elsif ($po->has_expires_before) {
        $where->{'certificate.notafter'} = { '<', $po->expires_before }
    } elsif ($po->has_expires_after) {
        $where->{'certificate.notafter'} = { '>', $po->expires_after }
    }

    if ($po->has_revoked_before && $po->has_revoked_after) {
        $where->{'certificate.revocation_time'} = { -between => [ $po->revoked_after, $po->revoked_before ] };
    } elsif ($po->has_revoked_before) {
        $where->{'certificate.revocation_time'} = { '<', $po->revoked_before }
    } elsif ($po->has_revoked_after) {
        $where->{'certificate.revocation_time'} = { '>', $po->revoked_after }
    }

    if ($po->has_invalid_before && $po->has_invalid_after) {
        $where->{'certificate.invalidity_time'} = { -between => [ $po->invalid_after, $po->invalid_before ] };
    } elsif ($po->has_invalid_before) {
        $where->{'certificate.invalidity_time'} = { '<', $po->invalid_before }
    } elsif ($po->has_invalid_after) {
        $where->{'certificate.invalidity_time'} = { '>', $po->invalid_after }
    }


    my @join_spec = ();


    my $return_attrib = {};
    if ($po->has_return_attributes) {
        map { $return_attrib->{$_} = '' } @{$po->return_attributes};
    }

    my $ii = 0;
    # handle certificate attributes (such as SANs)
    if ( $po->has_cert_attributes ) {
        # we need to join over the certificate_attributes table

        # Legacy API
        if (ref $po->cert_attributes eq 'ARRAY') {

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
        } else {

            foreach my $key (keys %{$po->cert_attributes}) {

                my $table_alias = "certattr$ii";

                if (!defined $po->cert_attributes->{$key}) {
                    next;
                }

                push @join_spec, ( "certificate.identifier=identifier,$table_alias.attribute_contentkey='$key'", "certificate_attributes|$table_alias" );
                # add search constraint
                $where->{ "$table_alias.attribute_value" } = $po->cert_attributes->{$key};

                # if the attribute should be returned we add the table name used
                if (defined $return_attrib->{$key}) {
                    $return_attrib->{$key} = $table_alias;
                # if not, we need to add a group statement to suppress
                # as simple scalar query can never be multivalued we skip it
                } elsif (ref $po->cert_attributes->{$key}) {
                    ##! 32: 'Need group on ' .$key
                    $params->{distinct} = 1;
                }

                $ii++;

            }
        }
    }

    ##! 64: 'return_attrib ' . Dumper $return_attrib
    foreach my $key (keys %{$return_attrib}) {

        # if the attribute was used in the query, it is already joined
        my $table_alias = $return_attrib->{$key};

        if (!$table_alias) {
            $table_alias = "certattr$ii";
            # outer join to also get empty values
            push @join_spec, ( "=>certificate.identifier=identifier,$table_alias.attribute_contentkey='$key'", "certificate_attributes|$table_alias" );
            $ii++;
        }
        push @{$params->{columns}}, "$table_alias.attribute_value as $key";
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
