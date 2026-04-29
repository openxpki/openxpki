package OpenXPKI::Server::API2::Plugin::Cert::get_cert_statistic;
use OpenXPKI -plugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Cert::get_cert_statistic

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Types;

=head1 COMMANDS

=head2 get_cert_statistic

Get the count of certifcates in the current realm or globally
grouped by certain status criteria.

B<Parameters>

All interval parameters consume any string parsable by OpenXPKI::DateTime.
Default for all is 30 days.

=over

=item * near_expiry

Interval to consider a certificate near expiration.

=item * recent_expiry

Interval to consider a certificate recently expired.

=item * recent_renewal

Interval to consider a certificate recently renewed.

=item * by_issuer

If set, all counts are grouped by C<issuer_identifier>. The return value
changes from a flat hash to a nested hash with the C<issuer_identifier>
as keys on the first level. Missing stat values per issuer are filled
with C<0> (C<by_profile> with an empty hash).

=back

B<Return values>

=over

=back

=cut

command "get_cert_statistic" => {
    near_expiry     => { isa => 'Str', default => '+000030', },
    recent_expiry   => { isa => 'Str', default => '-000030', },
    recent_renewal  => { isa => 'Str', default => '-000030', },
    valid_at        => { isa => 'Int' },
    pki_realm       => { isa => 'Str' },
    by_issuer       => { isa => 'Bool', default => 0 },
} => sub {
    my ($self, $params) = @_;

    my $db = CTX('dbi');
    my $result = {};

    # For special data types see:
    #  - https://metacpan.org/pod/SQL::Abstract::More#BIND-VALUES-WITH-TYPES
    #  - https://metacpan.org/pod/DBI#bind_param
    my %base_query = (
        from => 'certificate',
    );
    my %base_conditions = (
        'certificate.req_key' => { '!=' => undef },
    );

    if (not $params->has_pki_realm) {
        $base_conditions{'certificate.pki_realm'} = CTX('session')->data->pki_realm;
    } elsif ($params->pki_realm !~ /_any/i) {
        $base_conditions{'certificate.pki_realm'} = $params->pki_realm;
    }

    my $valid_at = $params->valid_at // time();
    my $ref_date = DateTime->from_epoch( epoch => $valid_at );
    my $by_issuer = $params->by_issuer;

    # Helper: run a COUNT query either as a single scalar or grouped by issuer_identifier
    my $do_count = sub {
        my ($stat_name, $col, %args) = @_;
        if (!$by_issuer) {
            my $row = $db->select_one(%base_query, %args,
                columns => [ "COUNT($col)|amount" ],
            );
            $result->{$stat_name} = sprintf "%01d", $row->{amount} + 0;
        } else {
            my $rows = $db->select_arrays(%base_query, %args,
                columns  => [ 'issuer_identifier', "COUNT($col)|amount" ],
                group_by => 'issuer_identifier',
            );
            $result->{$_->[0]}{$stat_name} = $_->[1] + 0 for @$rows;
        }
    };

    # total count
    $do_count->('total_count', 'identifier',
        where => { %base_conditions },
    );

    # Revoked
    $do_count->('total_revoked', 'identifier',
        where => {
            %base_conditions,
            status => [ 'REVOKED', 'CRL_ISSUANCE_PENDING' ],
        },
    );

    # valid revoked
    $do_count->('valid_revoked', 'identifier',
        where => {
            %base_conditions,
            status    => [ 'REVOKED', 'CRL_ISSUANCE_PENDING' ],
            notbefore => { '<' => $valid_at },
            notafter  => { '>' => $valid_at },
        },
    );

    # Distinct
    $do_count->('total_distinct', 'DISTINCT subject',
        where => { %base_conditions },
    );

    # Expired
    $do_count->('total_expired', 'identifier',
        where => {
            %base_conditions,
            status   => 'ISSUED',
            notafter => { '<' => $valid_at },
        },
    );

    # Upcoming
    $do_count->('total_upcoming', 'identifier',
        where => {
            %base_conditions,
            status    => 'ISSUED',
            notbefore => { '>' => $valid_at },
        },
    );

    # Valid
    $do_count->('valid_count', 'identifier',
        where => {
            %base_conditions,
            status    => 'ISSUED',
            notbefore => { '<' => $valid_at },
            notafter  => { '>' => $valid_at },
        },
    );

    # Valid distinct
    $do_count->('valid_distinct', 'DISTINCT subject',
        where => {
            %base_conditions,
            status    => 'ISSUED',
            notbefore => { '<' => $valid_at },
            notafter  => { '>' => $valid_at },
        },
    );

    # Valid by profile
    if (!$by_issuer) {
        my $tuple = $db->select_arrays(
            from_join => 'certificate {req_key=req_key,pki_realm=pki_realm} csr',
            columns   => [ 'profile', 'COUNT(identifier)|amount' ],
            where     => {
                %base_conditions,
                status    => 'ISSUED',
                notbefore => { '<' => $valid_at },
                notafter  => { '>' => $valid_at },
            },
            group_by => 'csr.profile',
        );
        ##! 1: $tuple
        $result->{by_profile} = { map { $_->[0] => $_->[1] } @{$tuple} };
    } else {
        my $tuple = $db->select_arrays(
            from_join => 'certificate {req_key=req_key,pki_realm=pki_realm} csr',
            columns   => [ 'certificate.issuer_identifier', 'profile', 'COUNT(identifier)|amount' ],
            where     => {
                %base_conditions,
                status    => 'ISSUED',
                notbefore => { '<' => $valid_at },
                notafter  => { '>' => $valid_at },
            },
            group_by => [ 'certificate.issuer_identifier', 'csr.profile' ],
        );
        for my $row (@$tuple) {
            $result->{$row->[0]}{by_profile}{$row->[1]} = $row->[2] + 0;
        }
    }

    # Near expiry
    my $expiry_cutoff = OpenXPKI::DateTime::get_validity({
        REFERENCEDATE  => $ref_date,
        VALIDITY       => $params->near_expiry,
        VALIDITYFORMAT => 'detect',
    })->epoch();

    $do_count->('near_expiry', 'identifier',
        where => {
            %base_conditions,
            status   => 'ISSUED',
            notafter => { -between => [ $valid_at, $expiry_cutoff ] },
        },
    );

    # Recent expiry
    $expiry_cutoff = OpenXPKI::DateTime::get_validity({
        REFERENCEDATE  => $ref_date,
        VALIDITY       => $params->recent_expiry,
        VALIDITYFORMAT => 'detect',
    })->epoch();

    $do_count->('recent_expiry', 'identifier',
        where => {
            %base_conditions,
            status   => 'ISSUED',
            notafter => { -between => [ $expiry_cutoff, $valid_at ] },
        },
    );

    # Recent renewal
    $expiry_cutoff = OpenXPKI::DateTime::get_validity({
        REFERENCEDATE  => $ref_date,
        VALIDITY       => $params->recent_renewal,
        VALIDITYFORMAT => 'detect',
    })->epoch();

    if (!$by_issuer) {
        my $tuple = $db->select_one(
            from_join => 'certificate certificate.identifier=identifier certificate_attributes|ca',
            columns   => [ 'COUNT(certificate.identifier)|amount' ],
            where     => {
                %base_conditions,
                notafter             => { -between => [ $expiry_cutoff, $valid_at ] },
                attribute_contentkey => 'system_renewal_cert_identifier',
            }
        );
        $result->{recent_renewed} = sprintf "%01d", $tuple->{amount};
    } else {
        my $rows = $db->select_arrays(
            from_join => 'certificate certificate.identifier=identifier certificate_attributes|ca',
            columns   => [ 'certificate.issuer_identifier', 'COUNT(certificate.identifier)|amount' ],
            where     => {
                %base_conditions,
                notafter             => { -between => [ $expiry_cutoff, $valid_at ] },
                attribute_contentkey => 'system_renewal_cert_identifier',
            },
            group_by => 'certificate.issuer_identifier',
        );
        $result->{$_->[0]}{recent_renewed} = $_->[1] + 0 for @$rows;
    }

    return $result;

};

__PACKAGE__->meta->make_immutable;
