package OpenXPKI::Server::Workflow::Activity::Noop;
use OpenXPKI;

use parent qw( OpenXPKI::Server::Workflow::Activity );

sub execute {
    my ($self) = @_;
    return undef;
}

1;

__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Noop - No-op activity

=head1 Description

The OpenXPKI equivalent to Workflow::Action::Null.
