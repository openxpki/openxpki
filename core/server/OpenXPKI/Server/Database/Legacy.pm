package OpenXPKI::Server::Database::Legacy;
use strict;
use warnings;
use utf8;

use Data::Dumper;

use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

=head1 Name

OpenXPKI::Server::Database::Legacy - Compatibility functions for the old database layer

=cut

my $certificate_map = {
    authority_key_identifier  => 'AUTHORITY_KEY_IDENTIFIER',
    cert_key                  => 'CERTIFICATE_SERIAL',
    data                      => 'DATA',
    identifier                => 'IDENTIFIER',
    issuer_dn                 => 'ISSUER_DN',
    issuer_identifier         => 'ISSUER_IDENTIFIER',
    loa                       => 'LOA',
    notafter                  => 'NOTAFTER',
    notbefore                 => 'NOTBEFORE',
    pki_realm                 => 'PKI_REALM',
    public_key                => 'PUBKEY',
    req_key                   => 'CSR_SERIAL',
    status                    => 'STATUS',
    subject                   => 'SUBJECT',
    subject_key_identifier    => 'SUBJECT_KEY_IDENTIFIER',
};

our $workflow_map = {
    workflow_id             => 'WORKFLOW_SERIAL',
    pki_realm               => 'PKI_REALM',
    workflow_type           => 'WORKFLOW_TYPE',
    workflow_state          => 'WORKFLOW_STATE',
    workflow_last_update    => 'WORKFLOW_LAST_UPDATE',
    workflow_proc_state     => 'WORKFLOW_PROC_STATE',
    workflow_wakeup_at      => 'WORKFLOW_WAKEUP_AT',
    workflow_count_try      => 'WORKFLOW_COUNT_TRY',
    workflow_reap_at        => 'WORKFLOW_REAP_AT',
    workflow_session        => 'WORKFLOW_SESSION',
    watchdog_key            => 'WATCHDOG_KEY',
};

our $csr_map = {
    req_key     => 'CSR_SERIAL',
    pki_realm   => 'PKI_REALM',
    format      => 'TYPE',
    profile     => 'PROFILE',
    loa         => 'LOA',
    subject     => 'SUBJECT',
    data        => 'DATA',
};

# Convert database result hash
# * $db_hash: HashRef to convert
# * $new_to_old: Conversion direction, 0 = to legacy, 1 = from legacy
# * $attr_map: HashRef which maps new attribute names to legacy names
# * $table: Optional table name (old DB layer) to be appended or removed
sub _convert {
    my ($self, $data, $new_to_old, $attr_map, $table) = @_;

    # to legacy
    if ($new_to_old) {
        return {
            map {
                my $key = $attr_map->{$_}
                    ? sprintf("%s%s", $table ? "$table." : "", $attr_map->{$_})
                    # keep old keys if they are unknown - installation with
                    # extra fields or meta columns like oracle rownum will break otherwise!
                    : $_;
                ( $key => $data->{$_} )
            }
            keys %$data
        };
    }
    # from legacy
    else {
        # create reverse $attr_map
        my $from_legacy = { map { ($attr_map->{$_} => $_ ) } keys %$attr_map };
        return {
            map {
                s/^\Q$table\E\.// if $table; # remove table name if any
                my $key = $from_legacy->{$_} or OpenXPKI::Exception->throw(
                    message => 'Unknown field name while trying to convert from legacy database attributes',
                    params  => { legacy_fieldname => $_ },
                    log => { priority => 'fatal', facility =>  'system', },
                );
                ( $key => $data->{$_} )
            }
            keys %$data
        };
    }
}

=head2 certificate_to_legacy

Converts the keys of the given data hash from SQL attribute names to legacy
attribute names.

Parameters:

=over

=item * B<$db_hash> database hash whose keys are to be converted

=back

=cut
sub certificate_to_legacy {
    my ($self, $db_hash) = @_;
    return $self->_convert($db_hash, 1, $certificate_map);
}

=head2 certificate_from_legacy

Converts the keys of the given data hash from legacy attributes names to SQL
attributes.

Parameters:

=over

=item * B<$db_hash> database hash whose keys are to be converted

=back

=cut
sub certificate_from_legacy {
    my ($self, $db_hash) = @_;
    return $self->_convert($db_hash, 0, $certificate_map);
}

=head2 workflow_to_legacy

Converts the keys of the given data hash from SQL attribute names to legacy
attribute names.

Parameters:

=over

=item * B<$db_hash> database hash whose keys are to be converted

=item * B<$prefix_table> optional: set to 1 to prefix field names with table name

=back

=cut
sub workflow_to_legacy {
    my ($self, $db_hash, $prefix_table) = @_;
    return $self->_convert($db_hash, 1, $workflow_map, $prefix_table ? "WORKFLOW" : undef);
}

=head2 csr_to_legacy

Converts the keys of the given data hash from SQL attribute names to legacy
attribute names.

Parameters:

=over

=item * B<$db_hash> database hash whose keys are to be converted

=item * B<$prefix_table> optional: set to 1 to prefix field names with table name

=back

=cut
sub csr_to_legacy {
    my ($self, $db_hash, $prefix_table) = @_;
    return $self->_convert($db_hash, 1, $csr_map, $prefix_table ? "CSR" : undef);
}

=head2 convert_dynamic_cond

Converts a dynamic condition in the old DB layer syntax to a condition of the
new DB layer. This method does NOT convert while WHERE clauses, only single
column conditions.

    $legacy->convert_dynamic_cond(
         { OPERATOR => "BETWEEN", VALUE => [ 2147483647, 2147485321 ] }
    )
    # results in:
    #     { -between => [ 2147483647, 2147485321 ] }

=cut
sub convert_dynamic_cond {
    my ($self, $condition) = @_;

    # Mostly taken from old DB layer: OpenXPKI::Server::DBI::SQL->select()
    my $op_map = {
        FROM            => '>=',
        TO              => '<=',
        NOT_EQUAL       => '!=',
        LESS_THAN       => '<',
        GREATER_THAN    => '>',
        EQUAL           => '=',
        BETWEEN         => 'dummy',
        LIKE            => 'dummy',
    };
    # Check required hash keys
    for my $attr (qw( OPERATOR VALUE )) {
        OpenXPKI::Exception->throw(
            message => "Legacy DB condition has unknown syntax: missing hash key '$attr'",
            params  => { CONDITION => Dumper($condition) },
        ) unless $condition->{$attr};
    }
    my $op  = $condition->{OPERATOR};
    my $val = $condition->{VALUE};
    # Check allowed operator name
    OpenXPKI::Exception->throw(
        message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_UNKNOWN_OPERATOR",
        params  => { CONDITION => Dumper($condition) }
    ) unless $op_map->{$op};

    # Convert
    if ('BETWEEN' eq $op) {
        if (ref $val ne 'ARRAY' or scalar @{$val} != 2) {
            OpenXPKI::Exception->throw(
                message => "I18N_OPENXPKI_SERVER_DBI_SQL_SELECT_WRONG_PARAM_FOR_BETWEEN",
                params  => { VALUE => Dumper($val) }
            );
        }
        return { -between => $val };
    }

    if ('LIKE' eq $op) {
        return { -like => $val };
    }

    return { $op_map->{$op} => $val };
}

1;

