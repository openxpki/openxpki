package OpenXPKI::Server::Workflow::Activity::Reports::Summary;
use OpenXPKI;

use parent qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::DateTime;
use DateTime;

sub execute {
    my $self = shift;
    my $workflow = shift;

    ##! 1: 'Start'
    my $context = $workflow->context();
    my $pki_realm = CTX('session')->data->pki_realm;

    my $target_key = $self->param('target_key');

    my $valid_at;
    if ($self->param('valid_at')) {
       $valid_at = OpenXPKI::DateTime::get_validity({
            VALIDITY =>  $self->param('valid_at'),
            VALIDITYFORMAT => 'detect',
        });
    } else {
       $valid_at = DateTime->now();
    }

    my $epoch = $valid_at->epoch();

    # For special data types see:
    #  - https://metacpan.org/pod/SQL::Abstract::More#BIND-VALUES-WITH-TYPES
    #  - https://metacpan.org/pod/DBI#bind_param
    my %base_query = (
        from => 'certificate',
    );
    my %base_conditions = (
        'certificate.req_key' => { '!=' => undef },
        'certificate.pki_realm' => $pki_realm,
    );

    my $db = CTX('dbi');
    my $tuple;
    my $result = {};

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
            notbefore => { '<' => $epoch },
            notafter  => { '>' => $epoch },
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
            notafter => { '<' => $epoch },
        }
    );
    $result->{total_expired} = sprintf "%01d", $tuple->{amount} + 0;


    # Valid
    $tuple = $db->select_one(%base_query,
        columns  => [ 'COUNT(identifier)|amount' ],
        where => {
            %base_conditions,
            status => 'ISSUED',
            notbefore => { '<' => $epoch },
            notafter  => { '>' => $epoch },
        }
    );
    $result->{valid_count} = sprintf "%01d", $tuple->{amount} + 0;


    # Valid distinct
    $tuple = $db->select_one(%base_query,
        columns  => [ 'COUNT(DISTINCT subject)|amount' ],
        where => {
            %base_conditions,
            status => 'ISSUED',
            notbefore => { '<' => $epoch },
            notafter  => { '>' => $epoch },
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
            notbefore => { '<' => $epoch },
            notafter  => { '>' => $epoch },
        },
        group_by => 'csr.profile',
    );
    ##! 1: $tuple
    $result->{by_profile} = { map { $_->[0] => $_->[1]  } @{$tuple} };

    # Near expiry
    my $near_expiry_validity = $self->param('near_expiry') || '+000030';
    my $expiry_cutoff = OpenXPKI::DateTime::get_validity({
        REFERENCEDATE => $valid_at,
        VALIDITY => $near_expiry_validity,
        VALIDITYFORMAT => 'detect',
    })->epoch();

    $tuple = $db->select_one(%base_query,
        columns  => [ 'COUNT(identifier)|amount' ],
        where => {
            %base_conditions,
            status => 'ISSUED',
            notafter  => { -between => [ $epoch, $expiry_cutoff  ] },
        }
    );
    $result->{near_expiry} = sprintf "%01d", $tuple->{amount} + 0;


    # Recent expiry
    $expiry_cutoff = OpenXPKI::DateTime::get_validity({
        REFERENCEDATE => $valid_at,
        VALIDITY => $self->param('recent_expiry') || '-000030',
        VALIDITYFORMAT => 'detect',
    })->epoch();

    $tuple = $db->select_one(%base_query,
        columns  => [ 'COUNT(identifier)|amount' ],
        where => {
            %base_conditions,
            status => 'ISSUED',
            notafter  => { -between => [ $expiry_cutoff, $epoch ] },
        }
    );
    $result->{recent_expiry} = sprintf "%01d", $tuple->{amount};

    $expiry_cutoff = OpenXPKI::DateTime::get_validity({
        REFERENCEDATE => $valid_at,
        VALIDITY => $self->param('recent_renewal') || '-000030',
        VALIDITYFORMAT => 'detect',
    })->epoch();

    $tuple = $db->select_one(
        from_join => 'certificate certificate.identifier=identifier certificate_attributes|ca',
        columns  => [ 'COUNT(certificate.identifier)|amount' ],
        where => {
            %base_conditions,
            notafter  => { -between => [ $expiry_cutoff, $epoch ] },
            attribute_contentkey => 'system_renewal_cert_identifier',
        }
    );
    $result->{recent_renewed} = sprintf "%01d", $tuple->{amount};

    ##! 32: 'Report result ' . Dumper $result
    if ($target_key) {
        $context->param( $target_key => $result );
    } else {
        $context->param( $result );
    }

}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Reports::Summary

=head1 Description

Collect statistics about certificate counts, the resulting numbers are
written into the context, see below.

=head1 Configuration

=head2 Activity parameters

=over

=item near_expiry

Parseable OpenXPKI::Datetime value (autodetected), certificates expiring
before the given date are shown as "near_expiry".
Default is +000030 (30 days).

=item recent_expiry

Parseable OpenXPKI::Datetime value (autodetected), certificates which are
expired after the given date are shown as "recent_expiry".
Default is -000030 (30 days in the past).

=item recent_renewal

Parseable OpenXPKI::Datetime value (autodetected), certificates which have
been issued as renewal to a predecessor certificate after the given date
are shown as "recent_renewal".
Default is -000030 (30 days in the past).

=item valid_at

Parseable OpenXPKI::Datetime value (autodetected) used as based for all
date related calculations. Default is now.

=item target_key

If set, the result is written into this single context value as a hash
using the keys named below as keys in the hash.

=item cutoff_notbefore (not implemented yet)

Parseable OpenXPKI::Datetime value (autodetected), hide certificates where
notbefore is below given date.

=item cutoff_notafter (not implemented yet)

Parseable OpenXPKI::Datetime value (autodetected), hide certificates where
notafter is above given date.

=back

=head2 Result

After completion the following parameters will be set in the context or
as key/value pairs of the hash written to I<target_key>.

=over 12

=item total_count

Total number of certificates.

=item total_revoked

Number of certificates in revoked status (includes CRL pending).

=item total_expired

Number of expired certificates (without revoked)

=item total_distinct

Number of distinct subjects (includes revoked)

=item valid_count

Number of valid certificates (in validity window and not revoked)

=item valid_distinct

Number of distinct subjects within valid certificates

=item valid_revoked

Number of certificates that are in validity window but revoked.

=item near_expiry

Number of valid (not revoked) certificates that will expiry within
the given window.

=item recent_expiry

Number of valid (not revoked) certificates that have been expired
within the given window.

=item recent_renewed

Number of certificates that have been issued within the given window
as a renewal to a predecessor certificate.

=item by_profile

Contains the share of certificate profiles of all valid certificates as
a key/value map. The key is the internal name of the profile and the value
is the absolute number of valid, issued certificates using this profile.

=back
