# OpenXPKI::DateTime.pm
# Written by Martin Bartosch for the OpenXPKI project
# Copyright (C) 2005-2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::DateTime;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use English;

use DateTime;
use Date::Parse;

# static function
sub convert_date {
    my $params = shift;

    my $outformat =
      exists $params->{OUTFORMAT}
      ? $params->{OUTFORMAT}
      : 'iso8601';

    my $date = $params->{DATE};

    if ( !defined $date ) {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_DATETIME_CONVERT_DATE_INVALID_DATE", );
    }

    # convert to UTC
    eval { $date->set_time_zone('UTC'); };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_DATETIME_CONVERT_DATE_INVALID_DATE",
            params  => { ERROR => $EVAL_ERROR, },
        );
    }

    return $date->epoch()                   if ( $outformat eq 'epoch' );
    return $date->iso8601()                 if ( $outformat eq 'iso8601' );
    return $date->strftime("%y%m%d%H%M%SZ") if ( $outformat eq 'openssltime' );
    return $date->strftime("%Y%m%d%H%M%SZ") if ( $outformat eq 'generalizedtime' );
    return $date->strftime("%Y%m%d%H%M%S")  if ( $outformat eq 'terse' );
    return $date->strftime("%F %T")         if ( $outformat eq 'printable' );

    OpenXPKI::Exception->throw(
        message => "I18N_OPENXPKI_DATETIME_CONVERT_DATE_INVALID_FORMAT",
        params  => { OUTFORMAT => $outformat, }
    );
}

sub get_validity {
    my $params = shift;

    my $validity =
      defined $params->{VALIDITY}
      ? $params->{VALIDITY}
      : "";

    my $validityformat =
      defined $params->{VALIDITYFORMAT}
      ? $params->{VALIDITYFORMAT}
      : 'relativedate';

    # referencedate is used for relative date computations
    my $refdate;
    if ( defined $params->{REFERENCEDATE} && ref $params->{REFERENCEDATE} ) {
        $refdate = $params->{REFERENCEDATE}->clone();
    }
    elsif ( $params->{REFERENCEDATE} ) {

        #parse from string
        $refdate = parse_date_utc( $params->{REFERENCEDATE} );

    }
    else {
        $refdate = DateTime->now( time_zone => 'UTC' );
    }

    if ( $validityformat eq 'detect' ) {
        if ( $validity =~ m{\A [+\-]}xms ) {
            $validityformat = 'relativedate';
        }
        # we hopefully wont have validities that far in the past
        # and I guess this software wont run if we reach the next epoch
        # so it should be safe to distinguish between terse date and epoch
        elsif ($validity =~ m{\A \d{9,10} \z }xms ) {
            $validityformat = 'epoch';

        # strip non-digits from iso date
        # also accept dates without time and missing "T" character
        } elsif ($validity =~ m{\A\d{4}-\d{2}-\d{2}([T\s]\d{2}:\d{2}:\d{2})?\z}) {
            $validity =~ s/[^0-9]//g;
            $validityformat = 'absolutedate';

        } elsif ($validity =~ m{\A\d{8}(\d{4}(\d{2})?)?\z}) {
            $validityformat = 'absolutedate';

        } else {
            OpenXPKI::Exception->throw(
                message => "Invalid format given to detect",
                params => {
                    VALIDITY  => $validity,
                },
            );
        }
    }

    if ( $validityformat eq 'epoch' ) {
         return DateTime->from_epoch( epoch => $validity );
    }

    if ( $validityformat eq 'days' ) {
        if ( $validity !~ m{ \A [+\-]?\d+ \z }xms ) {
            OpenXPKI::Exception->throw(
                message =>
                  "I18N_OPENXPKI_DATETIME_GET_VALIDITY_INVALID_VALIDITY",
                params => {
                    VALIDITYFORMAT => $validityformat,
                    VALIDITY       => $validity,
                },
            );
        }
        $refdate->add( days => $validity );

        return $refdate;
    }

    ##! 16: "$validityformat / $validity"
    if (   ( $validityformat eq 'absolutedate' )
        || ( $validityformat eq 'relativedate' ) )
    {

        my $relative = "";
        if ( $validityformat eq 'relativedate' ) {
            ( $relative, $validity ) =
              ( $validity =~ m{ \A ([+\-]?)(\d+) \z }xms );
            $relative ||= '+';
        }

        if ( ( !defined $validity ) || ( $validity eq "" ) ) {
            OpenXPKI::Exception->throw(
                message =>
                  "I18N_OPENXPKI_DATETIME_GET_VALIDITY_INVALID_VALIDITY",
                params => {
                    VALIDITYFORMAT => $validityformat,
                    VALIDITY       => $params->{VALIDITY},
                },
            );
        }

        my %date;

        # get year
        my $datelength = ( $relative eq "" ) ? 4 : 2;
        ( $date{year}, $validity ) =
          ( $validity =~ m{ \A (\d{$datelength}) (\d*) \z }xms );

        # month, day, hour, minute, second
        foreach my $item (qw ( month day hour minute second )) {
            if ( defined $validity ) {
                my $value;
                ( $value, $validity ) =
                  ( $validity =~ m{ \A (\d{2}) (\d*) \z }xms );
                if ( defined $value ) {
                    $date{$item} = $value;
                }
            }
        }
        ##! 32: \%date

        # e.g. if '+0' was given
        if (not defined $date{year}) {
            OpenXPKI::Exception->throw(
                message =>
                  "I18N_OPENXPKI_DATETIME_GET_VALIDITY_INVALID_VALIDITY",
                params => {
                    VALIDITYFORMAT => $validityformat,
                    VALIDITY       => $params->{VALIDITY},
                },
            );
        }

        # absolute validity
        if ( $relative eq "" ) {
            return DateTime->new( %date, time_zone => 'UTC', );
        }
        else {

            # append an 's' character to the has keys (year -> years)
            %date = map { $_ . 's' => $date{$_} } keys %date;

            if ( $relative eq "+" ) {
                $refdate->add(%date);
                return $refdate;
            }

            if ( $relative eq "-" ) {
                $refdate->subtract(%date);
                return $refdate;
            }
        }
    }

    OpenXPKI::Exception->throw(
        message =>
          "I18N_OPENXPKI_DATETIME_GET_VALIDITY_INVALID_VALIDITY_FORMAT",
        params => {
            VALIDITYFORMAT => $validityformat,
            VALIDITY       => $params->{VALIDITY},
        },
    );
}

sub parse_date_utc {

    my $date_string = shift;

    my ( $ss, $mm, $hh, $day, $month, $year, $zone ) = strptime($date_string);
    $month++;
    $year += 1900;
    return DateTime->new(
        (
            year      => $year,
            month     => $month,
            day       => $day,
            hour      => $hh,
            minute    => $mm,
            second    => int($ss), # support for microseconds in parsed date
            time_zone => $zone,
        ),
        time_zone => 'UTC',
    );
}

sub is_relative {
    my $datestring = shift;
    return $datestring =~ m{\A [+\-]}xms;
}

1;
__END__

=head1 Name

OpenXPKI::DateTime - tools to handle various date and timestamp formats.

=head1 Description

Tools for date/time manipulation.

=head1 Functions


=head2 convert_date

Converts a DateTime object to various date formats used throughout
OpenXPKI and returns the corresponding representation. Before converting
the object the Time Zone is adjusted to UTC.

If OUTFORMAT is not specified the output format defaults to iso8601.

Possible output formats:
  iso8601:     ISO 8601 formatted date (YYYY-MM-DDTHH:MM:SS), default
  epoch:       seconds since the epoch
  openssltime: time format used in OpenSSL index files (YYMMDDHHMMSSZ)
  generalizedtime: time format used in OpenSSL index files (YYYYMMDDHHMMSSZ)
  terse:       terse time format (YYYYMMDDHHMMSS)
  printable:   human readable ISO-like time format (YYYY-MM-DD HH:MM:SS)

=head3 Example

    my $dt = DateTime->now();

    print OpenXPKI::DateTime::convert_date({
        DATE      => $dt,
        OUTFORMAT => 'iso8601',
    });


=head2 get_validity

Returns a DateTime object that reflects the requested validity in UTC.

Possible validity formats (specified via VALIDITYFORMAT):

=over 4

=item *

'relativedate': the specified validity is interpreted as a relative
terse date string. The default is to calculate a date with a positive
offset (future date), to get a date in the past, add a minus sign as
prefix, e.g. to get current time yesterday I<-000001>. A leading
plus sign is also accepted but superfluous.

This is the default format.

=item *

'absolutedate': the specified validity is interpreted as an absolute
terse date string.

=item *

'days': the specified validity is interpreted as an integer number of days
(positive or negative) as an offset to the reference date.

=item *

'epoch': the specified validity is a unix epoch, used as absolute date.

=item *

'detect': tries to guess what it got, relativedate if it has a sign (+/-),
epoch if it has between 9 and 10 digits and absolutedate otherwise. Also
consumes iso8601 formated strings. Days can not be autodetected as they
look like relativedate.

'absolutedate' is only valid with eight (day only), 12 (minutes) or
14 (seconds) digits.

=back

=head3 Reference date

If a relative validity is specified the duration is added to a reference
date that defaults to the current time (UTC).

If the named parameter REFERENCEDATE is specified, this date is taken as the basis for calculating the relative
date. The parameter could either contain a DateTime object or a parsable date string
(i.e. '2012-05-24T08:33:47' see Date::Parse for a list of valid strings) which will be converted to an UTC DateTime object.

=head3 Terse date strings

The validity specification is passed in as the named parameter VALIDITY.

Absolute validities are specified in the format

  YYYYMMDD[HH[MM[SS]]]

Missing optional time specifications are replaced with '00'.
Example:

  2006031618   is interpreted as 2006-03-16 18:00:00 UTC


Relative validities are specified as a partial terse date string in
the format

  +YY[MM[DD[HH[MM[SS]]]]]   or
  -YY[MM[DD[HH[MM[SS]]]]]

Positive relative validities are interpreted as date offsets in the future
as seen from reference date, negative relativie validities are interpreted
as date offsets in the past.

Examples:

  -000001    (yesterday)
  +0003      (three months from now)

=head3 Usage example

  my $offset = DateTime->now( timezone => 'UTC' );
  $offset->add( months => 2 );

  my $somedate = OpenXPKI::DateTime::get_validity(
        {
        REFERENCEDATE => $offset,
        VALIDITY => '+0205',
        VALIDITYFORMAT => 'relativedate',
        },
    );
  print $somedate->datetime()

After this has been executed a date should be printed that is 2 years
and 7 months in the future: the relative validity 2 years, 5 months
is added to the offset which is 2 months in the future from now.

=head2 parse_date_utc

Helpermethod. Passes the given parameter $date_string  to Date::Parse::strptime and constructs from the return an UTC DateTime object

=head2 is_relative

Static helper, check if a datestring looks like a relative format.
(Check if the first character is a +/-).
