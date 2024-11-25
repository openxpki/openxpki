package OpenXPKI::Server::Workflow::Condition::AlwaysTrue;
use OpenXPKI;

use base qw( Workflow::Condition );

use Workflow::Exception qw( condition_error configuration_error );

sub evaluate {
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::AlwaysTrue

=head1 DESCRIPTION

This condition always returns true. This is mainly useful as a dummy
condition that does not really check anything.
