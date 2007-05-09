# OpenXPKI::Server::Workflow::Condition::CorrectTiming.pm
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision$
package OpenXPKI::Server::Workflow::Condition::CorrectTiming;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use DateTime;
use English;

use Data::Dumper;

__PACKAGE__->mk_accessors( 'difference' );

sub _init
{
    my ( $self, $params ) = @_;
    if (exists $params->{difference}) {
        my ($number, $modifier)
            = ($params->{difference} =~ m{ ([0-9]+) ([mhdw]?) }xms);
        if ($modifier eq 'm') { # minutes
            $number = $number * 60;
        }
        elsif ($modifier eq 'h') { # hours
            $number = $number * 60 * 60;
        }
        elsif ($modifier eq 'd') { # days
            $number = $number * 60 * 60 * 24;
        }
        elsif ($modifier eq 'w') { # weeks
            $number = $number * 60 * 60 * 24 * 7;
        }
        ##! 16: 'difference in seconds: ' . $number
        $self->difference($number);
    }
    else {
        # TODO -- throw config error
    }
}

sub evaluate {
    ##! 16: 'start'
    my ( $self, $workflow ) = @_;

    my $context   = $workflow->context();

    my $notafter = $context->param('current_notafter');
    ##! 16: 'notafter: ' . $notafter
    my $now = DateTime->now()->epoch();
    ##! 16: 'now: ' . $now
    my $diff = $notafter - $now;
    ##! 16: 'difference: ' . $diff

    if ($diff < 0 || $diff > $self->difference()) {
        condition_error('I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CORRECTTIMING_INCORRECT_TIMING');
    }
    ##! 16: 'end'
    return 1;
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
time value. Here, a number without any modifier is interpreted as seconds.
Appending 'm' interprets the value as minutes, 'h' as hours, 'd' as days
and 'w' as weeks.
