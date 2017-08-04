
package OpenXPKI::Server::Workflow::Activity::SmartCard::CheckServerStatus;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Control;

sub execute {

    my $self = shift;
    my $workflow = shift;

    my $context = $workflow->context();

    my $status = 'OK';
    my $max_process = $self->param('max_process') || 0;
    my $max_load = $self->param('max_load') || 0;

    my $process = OpenXPKI::Control::list_process();
    my $proc_count = scalar @{$process};

    if ($max_process > 0 && $proc_count > $max_process) {
        $status = 'BUSY';
    }

    $context->param({'proc_count' => $proc_count });

    # Replace with Sys::Load
    my $load = '';
    my $curr_load = 0;
    open( my $loadavg, "<", "/proc/loadavg" );
    if ($loadavg) {
        $load = <$loadavg>;
        chomp $load;
        ($curr_load) = ($load =~ m{\A (\d+\.\d+) }xms);
        if ($max_load > 0 && $curr_load > $max_load) {
            $status = 'BUSY';
        }
    }

    $context->param({'system_load' => $load });

    $context->param({'server_status' => $status });

    CTX('log')->application()->debug("Smartcard server load status is $status ($proc_count/$max_process, $load/$curr_load)");


    return 1;

}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartCard::CheckServerStatus

=head1 Description

Check if the system can handle smartcard personalizations based on the
current system load. Report I<BUSY> if one threshold is exceeded.

=head1 Configuration

=head2 Activity parameters

=over

=item max_load

Maximum allowed system load, 0 or undef to skip check.

=item max_process

Maximum allowed process count, 0 or undef to skip check.

=back

=head2 Context parameters

=over

=item server_status

Will hold the result of the check, possible values are I<OK> and I<BUSY>.

=item system_load

system load value (decimal)

=item proc_count

number of process

=back

=head1 Functions

=head2 execute

Executes the action.

