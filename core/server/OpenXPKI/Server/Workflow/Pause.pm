package OpenXPKI::Server::Workflow::Pause;
use OpenXPKI;

use OpenXPKI::Server::Context;

use Exception::Class (
    "OpenXPKI::Server::Workflow::Pause" =>
    {
        fields => [ "cause" ],
    }
);


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Pause - special Workflow-Exception

=head1 Description

aborts the execution of OpenXPKI::Server::Workflow::Activity::run()
is caught and handled from within OpenXPKI::Server::Workflow::execute_action

=head1 Intended use

no manual use of this class is intended. the class is used from within OpenXPKI::Server::Workflow::Activity::pause()