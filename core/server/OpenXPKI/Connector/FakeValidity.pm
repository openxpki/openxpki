package OpenXPKI::Connector::FakeValidity;

use strict;
use warnings;
use English;
use Moose;
use DateTime;
use OpenXPKI::DateTime;
use OpenXPKI::Server::Context qw( CTX );

extends 'Connector';

has cut_wday => (
    is  => 'ro',
    isa => 'Str',
    default => 6,
    );

has cut_time => (
    is  => 'ro',
    isa => 'Str',
    default => '17:00',
    );

sub get {
    my $self = shift;
    my $arg = shift;

    my $notafter = OpenXPKI::DateTime::get_validity({
        VALIDITY_FORMAT => 'detect',
        VALIDITY        => $self->LOCATION(),
    });

    my $org_notafter = $notafter->strftime("%Y-%m-%d %H:%M:%S");

    # In DateTime Sunday = 7 (not 0)
    my $wday = $notafter->day_of_week();

    my $cut_wday = $self->cut_wday();
    my @cut_time = split /:/, $self->cut_time();

    # Align time
    $notafter->set(
        hour      => $cut_time[0],
        minute    => $cut_time[1],
        second    => 0,
    );

    my $diff_day = ($cut_wday - $wday);
    if ($diff_day < 0) { $diff_day +=7; }

    # Add a full week if day matches but we are beyond the time limit
    my $hour = $notafter->hour();
    my $minute = $notafter->minute();
    $diff_day += 7 if ($wday == $cut_wday && $hour >= $cut_time[0] && $minute > $cut_time[1]);

    $notafter->add( days => $diff_day );

    CTX('log')->application()->debug("certificate validity adjusted from ". $org_notafter ." to ". $notafter->strftime("%Y-%m-%d %H:%M:%S"));


    return $notafter->strftime("%Y%m%d%H%M%S");
}

sub get_meta {

    my $self = shift;
    return {TYPE  => "scalar" };
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

OpenXPKI::Connector::FakeValidity;

=head1 DESCRIPTION

Connector to align a validity time spec to a fixed point in the week.

=head2 Configuration

=over

=item cut_wday

The day of week as used by perl DateTime, default is 6 (Saturday).
Note that Sunday is 7 (and not 0)!

=item cut_time

The time of the day, given as hh:mm, default is 17:00 (UTC)

=back

