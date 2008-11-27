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

        # the time difference
        my $timeDifference = undef;

        # set the time difference if it was passed in the ***OLD*** format
        if ($params->{difference} =~ m{ \A (\d+) ([mhdw]?) \z }xms) {			
			# now read the passed time difference in seconds
			$timeDifference = returnTimeDifferenceFromOldFormatInSeconds($params->{difference});
        }

        # set the time difference if it was passed in the ***NEW*** format
        elsif ($params->{difference} =~ m{ \A ([+\-]{1} \d+) \z }xms) {
            # set the time difference
            $timeDifference = $1;
        }

        # seems like the time difference format was not recognized
        else {
            OpenXPKI::Exception->throw(
                message => "I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CORRECTTIMING_INIT_INVALID_TIME_DIFFERENCE_FORMAT",
                params  => {
                    MSG => "Time difference format was not recognized"
                }
            );
        }

        # store the time difference 
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
	my $currentDate	= DateTime->now();     
	my $validDate	= undef;

	# set validDate if we got the validity in the ***OLD*** format
    if ($validity =~ m{ \A \d+ \z }xms) {
        # create date ('now' + 'validity')
        $validDate = $currentDate->epoch() + $validity;
    }

	# set validDate if we got the validity in the ***NEW*** format	
	if ($validity =~ m{ \A [+\-]{1} \d+ \z }xms) {
	    # create date ('now' + 'validity')
	    $validDate = OpenXPKI::DateTime::get_validity({
                   REFERENCEDATE => $currentDate,
                   VALIDITY => $validity,
                   VALIDITYFORMAT => 'relativedate',
		});
	}

   	# timing is incorrect...
   	# ...if $secondsUntilNotAfter is less than zero or 
   	# ...if $secondsUntilNotAfter is greater than $secondsDifference
   	my $secondsUntilNotAfter   = $notafter - $currentDate->epoch();
   	my $secondsDifference      = $validDate->epoch() - $currentDate->epoch();
    
	# thrown an incorrect timing error
	if ($secondsUntilNotAfter < 0 || $secondsUntilNotAfter > $secondsDifference) {
        	condition_error('I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CORRECTTIMING_EVALUATE_INCORRECT_TIMING');
	}

    return 1;
}

sub returnTimeDifferenceFromOldFormatInSeconds {
	my ( $self ) = @_;

	my $difference = shift;
	
	my $number = undef;
	my $modifier = undef;

	if ($difference =~ m{ \A ([0-9]+) ([mhdw]?) \z }xms) {
		$number = $1;
		$modifier = $2;
	}

	# minutes
	if ($modifier eq 'm') {
		$number = $number * 60;
	}
	# hours
	elsif ($modifier eq 'h') {
		$number = $number * 60 * 60;
	}
	# days
	elsif ($modifier eq 'd') {
		$number = $number * 60 * 60 * 24;
	}
	# weeks
	elsif ($modifier eq 'w') {
		$number = $number * 60 * 60 * 24 * 7;
	}

	# return the time difference in seconds	
	return $number;
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
