package OpenXPKI::Server::Workflow::Activity::Sleep;
use OpenXPKI;

use base qw( OpenXPKI::Server::Workflow::Activity );

use Workflow::Exception qw(configuration_error);

sub execute {
    my ($self) = @_;

    my $period = $self->param('period');

    if (!$period) {
        configuration_error('Sleep period is missing!');
    }

    sleep $period;

    return 1;
}

1;

__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Sleep

=head1 Description

Do a real, synchronus (and blocking) sleep. Use this only for some
seconds of sleep. If you need to interupt for longer please use the
Tools::Pause activity that uses the watchdog.

=head2 Activity Parameter

=over

=item period

The time to sleep in seconds.

=back
