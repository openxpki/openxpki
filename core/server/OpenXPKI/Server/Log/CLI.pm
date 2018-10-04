## OpenXPKI::Server::Log::CLI.pm
##
## Logger class to be used in CLI scripts, logs to stdout
## Written in 2013 by Olvier Welter for the OpenXPKI Project
## (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Server::Log::CLI;

use strict;
use warnings;
use English;

use Log::Log4perl qw( :easy );

our $LEVEL;

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {};

    Log::Log4perl->easy_init( $OpenXPKI::Server::Log::CLI::LEVEL || $ERROR );

    bless $self, $class;

    $self->{logger} = Log::Log4perl->get_logger();

    return $self;
}

sub log
{
    my $self = shift;
    my $keys = { @_ };

    if ($keys->{PRIORITY} =~ / \A (trace|debug|info|warn|error|fatal) \z /i) {
        my $prio = $1;
        $self->{logger}->$prio( $keys->{MESSAGE} );
    }

    return 1;
}

# install wrapper / helper subs
no strict 'refs';
for my $prio (qw/ trace debug info warn error fatal /) {
    *{$prio} = sub {
        my ($self, $message, $facility) = @_;
        $self->{logger}->$prio( $message );
    };
}

for my $facility (qw/ application auth system workflow audit /) {
    *{$facility} = sub {
        my ($self) = @_;
        return $self->{logger};
    };
}

1;
__END__

=head1 Name

OpenXPKI::Server::Log::CLI

=head1 Description

This class has the same interface than OpenXPKI::Server::Log but
logs anything to stdout. By default only errors are logged, for other
loglevels you can set the level from your script:

    use Log::Log4perl::Level;
    use OpenXPKI::Server::Log::CLI;
    $OpenXPKI::Server::Log::CLI::LEVEL = $TRACE;
