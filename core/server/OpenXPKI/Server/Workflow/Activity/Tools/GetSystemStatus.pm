package OpenXPKI::Server::Workflow::Activity::Tools::GetSystemStatus;

use strict;
use base qw(OpenXPKI::Server::Workflow::Activity);

use OpenXPKI::Server::Context qw(CTX);
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;


sub execute {

    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    my $status =  CTX('api2')->get_ui_system_status();

    $context->param($status);
}

1;
__END__
