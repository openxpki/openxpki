## OpenXPKI::Server::API::Housekeeping.pm
##
## Written 2016 by Scott Hardin for the OpenXPKI project
##
## Based on work by Michael Bell and Martin Bartosch
## Copyright (C) 2005-2016 by The OpenXPKI Project

package OpenXPKI::Server::API::Housekeeping;

use strict;
use warnings;
use utf8;
use English;
use Class::Std;

use OpenXPKI::Server::Context qw( CTX );

sub START {
    # somebody tried to instantiate us, but we are just an
    # utility class with static methods
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_API_SUBCLASSES_CAN_NOT_BE_INSTANTIATED',
    );
}

sub get_utc_time {
    my $t = shift || time;
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
        gmtime($t);
    $year += 1900;
    $mon++;
    my $time;
    my $microseconds = 0;
    eval { # if Time::HiRes is available, use it to get microseconds
        use Time::HiRes qw( gettimeofday );
        my ($seconds, $micro) = gettimeofday();
        $microseconds = $micro;
    };
    $time = sprintf("%04d%02d%02d%02d%02d%02d%06d", $year, $mon, $mday, $hour, $min, $sec, $microseconds);

    return $time;
}

sub purge_application_log {
    my ($self, $args)  = @_;
    ##! 1: "purge_application_log"

    my $maxage = $args->{MAXAGE} // 60*60*24*180;  #  180 days
    my $maxutc = $args->{LEGACY} ? get_utc_time( time - $maxage ) : (time - $maxage);

    return CTX('dbi')->delete(
        from => 'application_log',
        where => { logtimestamp => { "<", $maxutc } },
    );
}

1;

__END__

=head1 Name

OpenXPKI::Server::API::Housekeeping

=head1 Description

This is the housekeeping interface which should be used by all user interfaces of OpenXPKI.
A user interface MUST NOT access the server directly. The only allowed
access is via this API. Any function which is not available in this API is
not for public use.
The API gets access to the server via the 'server' context object. This
object must be set before instantiating the API.

=head1 Functions

=head2 new

Default constructor created by Class::Std.

=head2 purge_application_log

Purges old records from the application_log table.

Named parameters:

=over

=item * MAXAGE

The maximum age (in seconds) of the application log entries to preserve.
[default: 1 year (60*60*24*365)]

=item * LEGACY

Boolean, set to 1 to use the old timestamp format when purging.

=back

Examples:

  $api->purge_application_log( { MAXAGE => 60*60*24*180 } );

