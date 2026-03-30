package OpenXPKI::Server::Workflow::Activity::Tools::GetSystemStatus;
use OpenXPKI;

use parent qw(OpenXPKI::Server::Workflow::Activity);

use OpenXPKI::Server::Context qw(CTX);
use OpenXPKI::Serialization::Simple;


sub execute {

    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    my $status =  CTX('api2')->get_ui_system_status();

    if (my $target_key = $self->param('target_key')) {
        $context->param( $target_key  => $status );
    } else {
        $context->param($status);
    }



}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::GetSystemStatus

=head1 Description

Fetches the current system status of the OpenXPKI server and writes it into
the workflow context.

See C<get_ui_system_status> for return values.

=head1 Configuration

=head2 Parameters

=over

=item target_key (optional)

Name of the context key under which the status hash is stored.
If no C<target_key> is given, all fields of the status hash are written
directly as individual keys into the context.

=back

=head1 Example

    class: OpenXPKI::Server::Workflow::Activity::Tools::GetSystemStatus
    param:
        target_key: system_status

The status is then available as a hash ref under C<system_status> in the
context and can be accessed e.g. via Template Toolkit:

    [% context.system_status.secret_offline %]

Without C<target_key>, the fields are written directly into the context:

    [% context.secret_offline %]
