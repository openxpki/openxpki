package OpenXPKI::Server::Workflow::Activity::Log;

use warnings;
use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );
use OpenXPKI::Server::Context qw( CTX );


sub execute {
    my ($self) = @_;

    my $msg = $self->param('message');
    return unless ($msg);

    my $prio = $self->param('level') || 'info';
    $prio = 'info' unless ($prio =~ m{(warn|info|debug)});

    CTX('log')->application()->$prio($msg);

    return;
}

1;

__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Log

=head1 Description

Write a message to the application log.

=head2 Parameter

=over

=item message

The string to write to the log, if the string is empty the activity
silently does nothing.

=item level

The loglevel to use, the default is I<info>, alternative values are
I<debug> or I<warn>.

=back
