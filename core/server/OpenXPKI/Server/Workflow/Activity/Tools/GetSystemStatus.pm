package OpenXPKI::Server::Workflow::Activity::Tools::GetSystemStatus;
use OpenXPKI;

use OpenXPKI::Server::Context qw(CTX);

use parent qw(OpenXPKI::Server::Workflow::Activity::Status::GetSystemStatus);

sub init {
    my ( $self, $wf, $params ) = @_;
    CTX('log')->deprecated->warn('The class Activity::Tools::GetSystemStatus has been renamed to Activity::Status::GetSystemStatus');
    return $self->SUPER::init($wf, $params);
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::GetSystemStatus

=head1 Description

The class has been renamed to
C<OpenXPKI::Server::Workflow::Activity::Status::GetSystemStatus>