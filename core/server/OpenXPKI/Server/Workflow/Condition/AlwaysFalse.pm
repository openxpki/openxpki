package OpenXPKI::Server::Workflow::Condition::AlwaysFalse;
use OpenXPKI;

use base qw( Workflow::Condition );

use Workflow::Exception qw( condition_error configuration_error );

sub evaluate {
    condition_error("I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_ALWAYS_FALSE");
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::AlwaysFalse

=head1 DESCRIPTION

This condition always returns false. This is mainly useful as a dummy
condition that does not really check anything.
