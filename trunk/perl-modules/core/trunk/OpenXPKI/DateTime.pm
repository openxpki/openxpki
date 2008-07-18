# OpenXPKI::DateTime.pm 
# Written by Martin Bartosch for the OpenXPKI project
# Copyright (C) 2005-2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::DateTime;

use OpenXPKI::Exception;
use English;

use DateTime;


# static function
sub convert_date {
    my $params = shift;
    
    my $outformat = exists $params->{OUTFORMAT} 
        ? $params->{OUTFORMAT} 
        : 'iso8601';

    my $date = $params->{DATE};

    if (! defined $date) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_DATETIME_CONVERT_DATE_INVALID_DATE",
	    );
    }

    # convert to UTC
    eval {
	$date->set_time_zone('UTC');
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_DATETIME_CONVERT_DATE_INVALID_DATE",
	    params => {
		ERROR => $EVAL_ERROR,
	    },
	    );
    }

    return $date->epoch()                   if ($outformat eq 'epoch');
    return $date->iso8601()                 if ($outformat eq 'iso8601');
    return $date->strftime("%y%m%d%H%M%SZ") if ($outformat eq 'openssltime');
    return $date->strftime("%Y%m%d%H%M%S")  if ($outformat eq 'terse');
    return $date->strftime("%F %T")         if ($outformat eq 'printable');

    OpenXPKI::Exception->throw (
	message => "I18N_OPENXPKI_DATETIME_CONVERT_DATE_INVALID_FORMAT",
	params => {
	    OUTFORMAT => $outformat,
	}
	);
 }




sub get_validity {
    my $params = shift;

    my $validity         
	= defined $params->{VALIDITY}
          ? $params->{VALIDITY}
          : "";

    my $validityformat   
	= defined $params->{VALIDITYFORMAT}
          ? $params->{VALIDITYFORMAT}
          : 'relativedate';

    # referencedate is used for relative date computations
    my $refdate 
	= defined $params->{REFERENCEDATE} 
          ? $params->{REFERENCEDATE}->clone()
          : DateTime->now( time_zone => 'UTC' );

    if ($validityformat eq 'days') {
	if ($validity !~ m{ \A [+\-]?\d+ \z }xms) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_DATETIME_GET_VALIDITY_INVALID_VALIDITY",
		params  => {
		    VALIDITYFORMAT => $validityformat,
		    VALIDITY => $validity,
		},
		);
	}
	$refdate->add( days => $validity );

	return $refdate;
    }
    
    if (($validityformat eq 'absolutedate') ||
	($validityformat eq 'relativedate')) {

	my $relative = "";
	if ($validityformat eq 'relativedate') {
	    ($relative, $validity) 
		= ( $validity =~ m{ \A ([+\-]?)(\d+) \z }xms );
	}
	
	if ((! defined $validity) || ($validity eq "")) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_DATETIME_GET_VALIDITY_INVALID_VALIDITY",
		params  => {
		    VALIDITYFORMAT => $validityformat,
		    VALIDITY => $params->{VALIDITY},
		},
		);
	}
	
	my %date;
	# get year
	my $datelength = ( $relative eq "" ) ? 4 : 2;
	( $date{year}, $validity ) = 
	    ( $validity =~ m{ \A (\d{$datelength}) (\d*) \z }xms );
	
	# month, day, hour, minute, second
	foreach my $item (qw ( month day hour minute second ) ) {
	    if (defined $validity) {
		my $value;
		( $value, $validity ) = ( $validity =~ m{ \A (\d{2}) (\d*) \z }xms );
		if (defined $value) {
		    $date{$item} = $value;
		}
	    }
	}
	
	# absolute validity
	if ($relative eq "") {
	    return DateTime->new(
		%date,
		time_zone => 'UTC',
		);
	}
	else
	{
	    # append an 's' character to the has keys (year -> years)
	    %date = map { $_ . 's' => $date{$_} } keys %date;
	    
	    if ($relative eq "+") {
		$refdate->add( %date );
		return $refdate;
	    }
	    
	    if ($relative eq "-") {
		$refdate->subtract( %date );
		return $refdate;
	    }
	}
    }
    
    OpenXPKI::Exception->throw (
	message => "I18N_OPENXPKI_DATETIME_GET_VALIDITY_INVALID_VALIDITY_FORMAT",
	params  => {
	    VALIDITYFORMAT => $validityformat,
	    VALIDITY => $validity,
	},
	);
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
terse date string. This is the default.

=item *

'absolutedate': the specified validity is interpreted as an absolute 
terse date string.

=item * 

'days': the specified validity is interpreted as an integer number of days
(positive or negative) as an offset to the reference date.

=back

=head3 Reference date

If a relative validity is specified the duration is added to a reference
date that defaults to the current time (UTC).

If the named parameter REFERENCEDATE is specified and contains a DateTime
object this date is taken as the basis for calculating the relative
date.

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
