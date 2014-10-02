package OpenXPKI::Server::Workflow::Activity::Skip;

use warnings;
use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

sub execute {
    my ($self) = @_;
    return undef;
}

1;

__END__

=head1 OpenXPKI::Server::Workflow::Activity::Skip

Does nothing, reserved for later use!
