package OpenXPKI::Server::Workflow::Condition::DateTime;

use strict;
use warnings;
use base qw( OpenXPKI::Server::Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::DateTime;
use OpenXPKI::Debug;
use English;

sub _evaluate
{
    ##! 64: 'start'
    my ( $self, $wf ) = @_;
    my $context = $wf->context();

    my $key = $self->param('contextkey');

    my $probe;
    if ($key) {
        $probe = $context->param($key);
    } else {
        $probe = $self->param('value');
    }

    my $notbefore = $self->param('notbefore');
    my $notafter = $self->param('notafter');
    my $dt_now = DateTime->now();

    ##! 32: 'Probe ' . $probe . ' nb: ' . $notbefore  . ' - na: ' . $notafter

    condition_error ("DateTime context value ($key) to test is missing or empty") unless ($probe);

    my $dt_probe = OpenXPKI::DateTime::get_validity({
        VALIDITY => $probe,
        VALIDITYFORMAT => 'detect'
    });

    ##! 32: ' $dt_probe : ' . $dt_probe
    if (defined $notbefore) {
        ##! 32: ' Has notbefore ' . $notbefore
        my $dt_notbefore = $notbefore
            ? OpenXPKI::DateTime::get_validity({
                VALIDITY => $notbefore,
                VALIDITYFORMAT => 'detect'
            })
            : $dt_now;

        if ($dt_probe <= $dt_notbefore) {
            CTX('log')->application()->debug("DateTime condition failed $key $dt_probe < $dt_notbefore");

            condition_error ("$key $dt_probe is less then notbefore $dt_notbefore");
        }
        CTX('log')->application()->debug("DateTime condition passed $key $dt_probe > $dt_notbefore");

    }

    if (defined $notafter) {
        ##! 32: ' Has  notafter ' . $notafter
        my $dt_notafter = $notafter
            ? OpenXPKI::DateTime::get_validity({
                VALIDITY => $notafter,
                VALIDITYFORMAT => 'detect'
            })
            : $dt_now;

        if ($dt_probe >= $dt_notafter) {
            CTX('log')->application()->debug("DateTime condition failed - $key $dt_probe > $dt_notafter");

            condition_error ("$key $dt_probe is larger then notafter $dt_notafter");
        }

        CTX('log')->application()->debug("DateTime condition passed $key $dt_probe < $dt_notafter");

    }

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::DateTime

Generic class to check a value against a timespec.

=head1 SYNOPSIS

is_in_datetime_interval:
    class: OpenXPKI::Server::Workflow::Condition::DateTime
    param:
        notbefore: 20140101000000
        notafter: +0001
        _map_value: $probe_date

=head1 DESCRIPTION

The condition checks if the value given to value is within the bounds
given by notbefore/notafter. Any value accepted by the OpenXPKI::DateTime
autodetect mechanism is useable. To check against "now", set a "0", to check
only against one bound just leave the second parameter undefined.

=head2 Paramaters

=over

=item value

The reference to test against.

=item notbefore

=item notafter

=item contextkey (deprecated)

Legacy parameter - load the value to probe against from this context key.
Should not be used, use the I<_map_> syntax instead.

=back



