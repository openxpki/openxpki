## OpenXPKI::Server::Log::NOOP.pm
##
## a dummy class that behaves like OpenXPKI::Server::Log, but does
## not log anything (used during server startup where logger is noy
## yet available)

package OpenXPKI::Server::Log::NOOP;

use strict;
use warnings;
use English;
use Log::Log4perl qw(:easy);

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    bless $self, $class;

    $self->{logger} = Log::Log4perl->easy_init($OFF);

    return $self;
}

sub log { 1; }

# system is used as default logger for the DBI class
sub system {
    my $self = shift;
    return $self->{logger};
}

# install wrapper / helper subs
no strict 'refs';
for my $prio (qw/ debug info warn error fatal /) {
    *{$prio} = sub { 1; };
}

1;
__END__

=head1 Name

OpenXPKI::Server::Log:NOOP - not a logging implementation for OpenXPKI

=head1 Description

This is a class that behaves from the outside like OpenXPKI::Server::Log,
but does not log anything. It is used during server initialization when
logger is not yet available.
