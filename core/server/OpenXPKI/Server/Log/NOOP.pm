## OpenXPKI::Server::Log::NOOP.pm
##
## a dummy class that behaves like OpenXPKI::Server::Log, but does
## not log anything (used during server startup where dbi_log is noy
## yet available)
## Written in 2007 by Alexander Klink for the OpenXPKI Project
## (C) Copyright 2007 by The OpenXPKI Project

package OpenXPKI::Server::Log::NOOP;

use strict;
use warnings;
use English;

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    bless $self, $class;

    return $self;
}


sub re_init {
    my $self = shift;

    return 1;
}

sub log
{
    my $self = shift;
    my $keys = { @_ };

    return 1;
}

# install wrapper / helper subs
no strict 'refs';
for my $prio (qw/ debug info warn error fatal /) {
    *{$prio} = sub {
        my ($self, $message, $facility) = @_;
        $self->log(
            MESSAGE  => $message,
            PRIORITY => $prio,
            CALLERLEVEL => 1,
            FACILITY => $facility // "monitor",
        );
    };
}

1;
__END__

=head1 Name

OpenXPKI::Server::Log:NOOP - not a logging implementation for OpenXPKI

=head1 Description

This is a class that behaves from the outside like OpenXPKI::Server::Log,
but does not log anything. It is used during server initialization when
dbi_log is not yet available.
