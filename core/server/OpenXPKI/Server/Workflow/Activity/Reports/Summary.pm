package OpenXPKI::Server::Workflow::Activity::Reports::Summary;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use Data::Dumper;
use OpenXPKI::DateTime;
use DateTime;

sub execute {
    my $self = shift;
    my $workflow = shift;

    ##! 1: 'Start'
    my $context = $workflow->context();
    my $pki_realm = CTX('session')->data->pki_realm;

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
        req_key => { '!=' => undef },
        pki_realm => $pki_realm,
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
    my $recent_expiry_validity = $self->param('recent_expiry') || '-000030';
    $expiry_cutoff = OpenXPKI::DateTime::get_validity({
        REFERENCEDATE => $valid_at,
        VALIDITY => $recent_expiry_validity,
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


    ##! 32: 'Report result ' . Dumper $result
    $context->param( $result );

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

=item valid_at

Parseable OpenXPKI::Datetime value (autodetected) used as based for all
date related calculations. Default is now.

=item cutoff_notbefore (not implemented yet)

Parseable OpenXPKI::Datetime value (autodetected), hide certificates where
notbefore is below given date.

=item cutoff_notafter (not implemented yet)

Parseable OpenXPKI::Datetime value (autodetected), hide certificates where
notafter is above given date.

=back

=head2 Context parameters

After completion the following context parameters will be set:

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

=back
