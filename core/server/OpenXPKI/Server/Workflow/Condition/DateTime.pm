package OpenXPKI::Server::Workflow::Condition::DateTime;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::DateTime;
use OpenXPKI::Debug;
use English;

__PACKAGE__->mk_accessors( qw(contextkey notbefore notafter) );

sub _init
{
    my ( $self, $params ) = @_;
    unless ( $params->{contextkey} )
    {
        configuration_error
             "You must define one value for 'contextkey' in ",
             "declaration of condition ", $self->name;
    }
    $self->contextkey($params->{contextkey});

    $self->notbefore($params->{notbefore});
    $self->notafter($params->{notafter});
}

sub evaluate
{
    ##! 64: 'start'
    my ( $self, $wf ) = @_;
    my $context = $wf->context();

    my $key = $self->contextkey();
    my $probe = $context->param($key);
    my $notbefore = $self->notbefore();
    my $notafter = $self->notafter();
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
            CTX('log')->application()->info("DateTime condition failed $key $dt_probe < $dt_notbefore");

            condition_error ("$key $dt_probe is less then notbefore $dt_notbefore");
        }
        CTX('log')->application()->info("DateTime condition passed $key $dt_probe > $dt_notbefore");

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

<condition name=""
    class="OpenXPKI::Server::Workflow::Condition::DateTime">
    <param name="contextkey" value="invalidity_time"/>
    <param name="notbefore" value="20140101000000"/>
    <param name="notafter" value="+0001"/>
</condition>

=head1 DESCRIPTION

The condition checks if the value found at contextkey is within the bounds
given by notbefore/notafter. Any value accepted by the OpenXPKI::DateTime
autodetect mechanism is useable. To check against "now", set a "0", to check
only against one bound just leave the second parameter undefined.