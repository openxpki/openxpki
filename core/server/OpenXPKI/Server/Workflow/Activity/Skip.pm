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

=head1 Name

OpenXPKI::Server::Workflow::Activity::Skip

=head1 Description

Does nothing, reserved for later use!
