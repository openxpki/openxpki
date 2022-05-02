package OpenXPKI::Server::Workflow::Activity::Reports::Timeline;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::DateTime;
use DateTime;

sub execute {

    my $self = shift;
    my $workflow = shift;

    ##! 1: 'Start'
    my $context = $workflow->context();
    my $pki_realm = CTX('session')->data->pki_realm;

    my $target_key = $self->param('target_key');

    my $start_at = OpenXPKI::DateTime::get_validity({
        VALIDITY => $self->param('start_at') || '-01',
        VALIDITYFORMAT => 'detect',
    })->epoch();

    my $stop_at = time();
    $stop_at = OpenXPKI::DateTime::get_validity({
        VALIDITY => $self->param('stop_at'),
        VALIDITYFORMAT => 'detect',
    })->epoch()  if ($self->param('stop_at'));

    my $interval = { -between => [ $start_at, $stop_at ] };
    ##! 16: $interval

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

    if (my $issuer = $self->param('issuer')) {
        $base_conditions{issuer_identifier} = $issuer;
    }

    my $select_column = 'CONCAT(EXTRACT(YEAR FROM FROM_UNIXTIME(%s)),EXTRACT(MONTH FROM FROM_UNIXTIME(%1$s)))|ivl';
    my $group_query = 'EXTRACT(MONTH FROM FROM_UNIXTIME(%s)), EXTRACT(YEAR FROM FROM_UNIXTIME(%1$s))';

    my $db = CTX('dbi');
    my $series;

    my $first_group = $db->select_one(%base_query, columns => [ sprintf($select_column, $start_at) ]);
    my ($offset_year, $offset_month) = ($first_group->{ivl} =~ m{(\d{4})(\d+)});

    ##! 16: "$first_group->{ivl} / $offset_year / $offset_month"

    my $get_index = sub {
        my $value = shift;
        my ($year, $month) = ($value =~ m{(\d{4})(\d+)});
        return (($year - $offset_year) * 12)
             + ($month - $offset_month);
    };

    my $last_group = $db->select_one(%base_query, columns => [ sprintf($select_column, $stop_at) ]);
    ##! 64: $last_group
    my @initial_row = (0) x ($get_index->($last_group->{ivl}));

    my $map_result = sub {
        my $db_res  = shift;
        my $val = [ @initial_row ];
        map {
            $val->[ $get_index->($_->[0]) ] = $_->[1];
        } @{$db_res};
        return $val;
    };

    my $result = { '_meta' => { start => $start_at, stop => $stop_at, group => 'month' } };

    # issued
    $series = $db->select_arrays(%base_query,
        columns  => [ sprintf($select_column, 'notbefore'),'COUNT(identifier)|amount' ],
        where => {
            %base_conditions,
            notbefore => $interval,
        },
        group_by => sprintf($group_query, 'notbefore'),
    );
    ##! 32: $series
    $result->{issued} = $map_result->($series);


    # expired
    $series = $db->select_arrays(%base_query,
        columns  => [ sprintf($select_column, 'notafter'),'COUNT(notafter)|amount' ],
        where => {
            %base_conditions,
            notafter => $interval,
            status => 'ISSUED',
        },
        group_by => sprintf($group_query, 'notafter'),
    );
    ##! 32: $series
    $result->{expired} = $map_result->($series);


    # revoked
    $series = $db->select_arrays(%base_query,
        columns  => [ sprintf($select_column, 'revocation_time'),'COUNT(revocation_time)|amount' ],
        where => {
            %base_conditions,
            revocation_time => $interval,
        },
        group_by => sprintf($group_query, 'revocation_time'),
    );
    ##! 32: $series
    $result->{revoked} = $map_result->($series);

    # renewals
    $series = $db->select_arrays(
        from_join => 'certificate certificate.identifier=identifier certificate_attributes|ca',
        columns  => [ sprintf($select_column, 'notbefore'),'COUNT(notbefore)|amount' ],
        where => {
            %base_conditions,
            notbefore => $interval,
            attribute_contentkey => 'system_renewal_cert_identifier',
        },
        group_by => sprintf($group_query, 'notbefore'),
    );
    ##! 32: $series
    $result->{renewed} = $map_result->($series);

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

OpenXPKI::Server::Workflow::Activity::Reports::Timeline

=head1 Description

Collect statistics about certificate counts over time. The grouping
function is the calendar month, the default is to count certificates
for the last year from now but you can set I<start_at> and I<stop_at>
to any value accepted by OpenXPKI::DateTime.

The resulting numbers are written int the context in a way that can be
consumed by the grid and chart functions of the UI.

=head1 Configuration

=head2 Activity parameters

=over

=item start_at

Parseable OpenXPKI::Datetime value (autodetected) representing the lower
bound of the report interval. Default is -01 (one year)

=item stop_at

Parseable OpenXPKI::Datetime value (autodetected) representing the upper
bound of the report interval. Default is now.

=item target_key

If set, the result is written into this single context value as a hash
using the keys named below as keys in the hash.

=item issuer

The certificate identifier of the issuer, optional - the default is to
include all entity certificates from the current realm.

=back

=head2 Result

After completion the following parameters will be set in the context or
as key/value pairs of the hash written to I<target_key>. The value is an
arrayref holding the values for each month, the first array position is
equal to the month of I<start_at>. Note that when using the default
interval the first and last month will show only parts of the month.

=over 12

=item issued

The number of certificates where notbefore is in the given interval.

=item revoked

The number of certificates where revocation_time is in the given interval.

=item expired

The number of certificates where notafter is in the given interval and
the status is issued (certificates that have been revoked after their
expiry are not counted to save database ressources)

=item renewed

Number of certificates that have been issued as a predecessor to an
expiring certificate.

=back
