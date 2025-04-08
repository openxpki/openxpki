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
} => sub {
    my ($self, $params) = @_;

    my $db = CTX('dbi');
    my $tuple;
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

    # total count
    $tuple = $db->select_one(%base_query,
        columns  => [ 'COUNT(identifier)|amount' ],
        where => {
            %base_conditions
        }
    );
    $result->{total_count} = sprintf "%01d", $tuple->{amount};

    # Revoked
    $tuple = $db->select_one(%base_query,
        columns  => [ 'COUNT(identifier)|amount' ],
        where => {
            %base_conditions,
            status => [ 'REVOKED', 'CRL_ISSUANCE_PENDING' ],
        }
    );
    $result->{total_revoked} = sprintf "%01d", $tuple->{amount} + 0;


    # valid revoked
    $tuple = $db->select_one(%base_query,
        columns  => [ 'COUNT(identifier)|amount' ],
        where => {
            %base_conditions,
            status => [ 'REVOKED', 'CRL_ISSUANCE_PENDING' ],
            notbefore => { '<' => $valid_at },
            notafter  => { '>' => $valid_at },
        }
    );
    $result->{valid_revoked} = sprintf "%01d", $tuple->{amount} + 0;


    # Distinct
    $tuple = $db->select_one(%base_query,
        columns  => [ 'COUNT(DISTINCT subject)|amount' ],
        where => {
            %base_conditions,
        }
    );
    $result->{total_distinct} = sprintf "%01d", $tuple->{amount} + 0;


    # Expired
    $tuple = $db->select_one(%base_query,
        columns  => [ 'COUNT(identifier)|amount' ],
        where => {
            %base_conditions,
            status => 'ISSUED',
            notafter => { '<' => $valid_at },
        }
    );
    $result->{total_expired} = sprintf "%01d", $tuple->{amount} + 0;


    # Valid
    $tuple = $db->select_one(%base_query,
        columns  => [ 'COUNT(identifier)|amount' ],
        where => {
            %base_conditions,
            status => 'ISSUED',
            notbefore => { '<' => $valid_at },
            notafter  => { '>' => $valid_at },
        }
    );
    $result->{valid_count} = sprintf "%01d", $tuple->{amount} + 0;


    # Valid distinct
    $tuple = $db->select_one(%base_query,
        columns  => [ 'COUNT(DISTINCT subject)|amount' ],
        where => {
            %base_conditions,
            status => 'ISSUED',
            notbefore => { '<' => $valid_at },
            notafter  => { '>' => $valid_at },
        }
    );
    $result->{valid_distinct} = sprintf "%01d", $tuple->{amount} + 0;


    # Valid by profile
    $tuple = $db->select_arrays(
        from_join => 'certificate {req_key=req_key,pki_realm=pki_realm} csr',
        columns  => [ 'profile', 'COUNT(identifier)|amount' ],
        where => {
            %base_conditions,
            status => 'ISSUED',
            notbefore => { '<' => $valid_at },
            notafter  => { '>' => $valid_at },
        },
        group_by => 'csr.profile',
    );
    ##! 1: $tuple
    $result->{by_profile} = { map { $_->[0] => $_->[1]  } @{$tuple} };

    # Near expiry
    my $expiry_cutoff = OpenXPKI::DateTime::get_validity({
        REFERENCEDATE => $ref_date,
        VALIDITY => $params->near_expiry,
        VALIDITYFORMAT => 'detect',
    })->epoch();

    $tuple = $db->select_one(%base_query,
        columns  => [ 'COUNT(identifier)|amount' ],
        where => {
            %base_conditions,
            status => 'ISSUED',
            notafter  => { -between => [ $valid_at, $expiry_cutoff  ] },
        }
    );
    $result->{near_expiry} = sprintf "%01d", $tuple->{amount} + 0;


    # Recent expiry
    $expiry_cutoff = OpenXPKI::DateTime::get_validity({
        REFERENCEDATE => $ref_date,
        VALIDITY => $params->recent_expiry,
        VALIDITYFORMAT => 'detect',
    })->epoch();

    $tuple = $db->select_one(%base_query,
        columns  => [ 'COUNT(identifier)|amount' ],
        where => {
            %base_conditions,
            status => 'ISSUED',
            notafter  => { -between => [ $expiry_cutoff, $valid_at ] },
        }
    );
    $result->{recent_expiry} = sprintf "%01d", $tuple->{amount};

    $expiry_cutoff = OpenXPKI::DateTime::get_validity({
        REFERENCEDATE => $ref_date,
        VALIDITY => $params->recent_renewal,
        VALIDITYFORMAT => 'detect',
    })->epoch();

    $tuple = $db->select_one(
        from_join => 'certificate certificate.identifier=identifier certificate_attributes|ca',
        columns  => [ 'COUNT(certificate.identifier)|amount' ],
        where => {
            %base_conditions,
            notafter  => { -between => [ $expiry_cutoff, $valid_at ] },
            attribute_contentkey => 'system_renewal_cert_identifier',
        }
    );
    $result->{recent_renewed} = sprintf "%01d", $tuple->{amount};

    return $result;

};

__PACKAGE__->meta->make_immutable;
