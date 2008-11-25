# OpenXPKI::Server::Workflow::Condition::CorrectTiming.pm
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::CorrectTiming;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use DateTime;
use OpenXPKI::DateTime;
use English;
use Data::Dumper;

__PACKAGE__->mk_accessors( 'difference' );

sub _init {
    my ( $self, $params ) = @_;

    # if existent, parse the passed time difference
    if (exists $params->{difference}) {

        # the time difference in the NEW format
        my $timeDifference = undef;

        # try to convert the time difference if it was passed in the ***OLD*** format
        if ($params->{difference} =~ /\A([0-9]+)([mhdw]?)\z/) {			
			# now read the passed time difference (old format is implicitly converted into new format)
			$timeDifference = readTimeDifferenceFromOldFormat($params->{difference});
        }

        # set the time difference if it was passed in the ***NEW*** format
        elsif ($params->{difference} =~ /\A([+\-]?\d+)\z/) {
            # set the time difference
            $timeDifference = $1;
        }

        # seems like the time difference format was not recognized
        else {
            OpenXPKI::Exception->throw(
                message => "I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CORRECTTIMING_INIT_INVALID_TIME_DIFFERECE_FORMAT",
                params  => {
                    MSG => "Time difference format was not recognized"
                }
            );
        }

        # store the time difference (in the new format) 
        $self->difference($timeDifference);
    }

    # if there is was no time difference passed, throw an exception
    else {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CORRECTTIMING_INIT_NO_TIME_DIFFERENCE_PARAMETER",
            params  => {
                MSG => "No time difference parameter was passed"
            } 
        );
    }
}

sub evaluate {
    ##! 16: 'start'
    my ( $self, $workflow ) = @_;

    my $notafter    = $workflow->context()->param('current_notafter');
    my $validity    = $self->difference();     
    my $currentDate = DateTime->now();

    # create date ('now' + 'difference)
    my $date = OpenXPKI::DateTime::get_validity({
                   REFERENCEDATE => $currentDate,
                   VALIDITY => $validity,
                   VALIDITYFORMAT => 'relativedate',
               });

    # timing is incorrect...
    # ...if $secondsUntilNotAfter is less than zero or 
    # ...if $secondsUntilNotAfter is greater than $secondsDifference
    my $secondsUntilNotAfter   = $notafter - $currentDate->epoch();
    my $secondsDifference      = $date->epoch() - $currentDate->epoch();

    # thrown an incorrect timing error
    if ($secondsUntilNotAfter < 0 || $secondsUntilNotAfter > $secondsDifference) {
        condition_error('I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CORRECTTIMING_EVALUATE_INCORRECT_TIMING');
    }

    return 1;
}

sub readTimeDifferenceFromOldFormat {
	my ( $self ) = @_;

	my $difference = shift;
	
	my $number = undef;
	my $modifier = undef;

	if ($difference =~ /\A([0-9]+)([mhdw]?)\z/) {
		$number = $1;
		$modifier = $2;
	}

	# temporary values
	my $timeSource = DateTime->now();
	my $timeTarget = $timeSource->clone();

	# minutes
	if ($modifier eq 'm') {
		$timeTarget->add(minutes => $number);
	}
	# hours
	elsif ($modifier eq 'h') {
		$timeTarget->add(hours => $number);
	}
	# days
	elsif ($modifier eq 'd') {
		$timeTarget->add(days => $number);
	}
	# weeks
	elsif ($modifier eq 'w') {
		$number *= 7;
		$timeTarget->add(days => $number);
	}
	# seconds
	elsif ($modifier eq '') {
		$timeTarget->add(seconds => $number);
	}
	# this should NOT happen
	else {
		OpenXPKI::Exception->throw(
        	message => "I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CORRECTTIMING_READ_TIME_DIFFERENCE_FROM_OLD_FORMAT_SYNTAX_INVALID",
            params  => {
            	MSG => "Please use the new syntax for relative dates (+yymmddhhmmss)"
            }
        );
   	}
	
	# calculate the time difference
	my $timeDifference = $timeTarget->subtract_datetime($timeSource);

	# the above function from DateTime does not output hours or years,
	# so we have to get cute in the following lines (see below)
	my $differenceSeconds 	= $timeDifference->{seconds};
	my $differenceMinutes 	= $timeDifference->{minutes};
	my $differenceHours		= 0;
	my $differenceDays		= $timeDifference->{days};
	my $differenceMonths	= $timeDifference->{months};
	my $differenceYears		= 0;

	# check if we need to convert minutes to hours and months to years (see above)
	while($differenceMinutes >= 60) {
		$differenceMinutes -= 60;
		$differenceHours += 1;
	}
	while($differenceMonths >= 12) {
		$differenceMonths -= 12;
		$differenceYears += 1;
	}

	# prepend leading zeros if necessary
	if($differenceSeconds < 10) {
		$differenceSeconds = "0$differenceSeconds";
	}
	if($differenceMinutes < 10) {
		$differenceMinutes = "0$differenceMinutes";
	}
	if($differenceHours < 10) {
		$differenceHours = "0$differenceHours";
	}
	if($differenceDays < 10) {
		$differenceDays = "0$differenceDays";
	}
	if($differenceMonths < 10) {
		$differenceMonths = "0$differenceMonths";
	}
	if($differenceYears < 10) {
		$differenceYears = "0$differenceYears";
	}

	# build the CORRECTLY FORMATTED time difference string (+yymmddHHMMSS)
	$timeDifference = "+$differenceYears$differenceMonths$differenceDays$differenceHours$differenceMinutes$differenceSeconds";
	
	return $timeDifference;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::CorrectTiming

=head1 SYNOPSIS

<action name="do_something">
  <condition name="correct_timing"
             class="OpenXPKI::Server::Workflow::Condition::CorrectTiming">
    <param name="difference" value="48h"/>
  </condition>
</action>

=head1 DESCRIPTION

The condition checks if a renewal SCEP request has the correct time
until the certificate becomes invalid. The definition of "correct" can be
tweaked by setting the condition parameter 'difference' to a corresponding
time value. There a two different formats to specify a time difference:

The new format uses a string of the following form "+yymmddhhmmss", where 
"yy", "mm", "dd", "hh", "mm" and "ss" indicates the years, months, days, 
hours, minutes and seconds of the date.

In the old format, a number without any modifier is interpreted as seconds.
Appending 'm' interprets the value as minutes, 'h' as hours, 'd' as days
and 'w' as weeks.
