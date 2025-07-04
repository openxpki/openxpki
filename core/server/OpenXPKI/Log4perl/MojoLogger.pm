package OpenXPKI::Log4perl::MojoLogger;
use OpenXPKI qw( -class -nonmoose );

extends 'Mojo::EventEmitter';

use Log::Log4perl;
use Mojo::Util qw( monkey_patch );

Log::Log4perl->wrapper_register(__PACKAGE__); # make Log4perl step up to the next call frame

our $LOGGERS_BY_NAME = {};

has category => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has _logger => (
    is => 'rw',
    isa => 'Log::Log4perl::Logger',
    init_arg => undef,
    lazy => 1,
    default => sub { Log::Log4perl->get_logger(shift->category) },
);

has history => (
    is => 'rw',
    isa => 'ArrayRef',
    init_arg => undef,
    default => sub { [] },
);

has max_history_size => (
    is => 'rw',
    isa => 'Int',
    init_arg => undef,
    default => 10,
);

# Static method: constructor replacement
sub get_logger {
    my ($class, $category) = @_;

    # todo - check why we get requests without category
    $category //= 'fallback';

    # Have we created it previously?
    return $LOGGERS_BY_NAME->{$category} if exists $LOGGERS_BY_NAME->{$category};

    # Instantiate ourself
    my $logger = $class->new( category => $category );
    $LOGGERS_BY_NAME->{$category} = $logger; # save it in global structure

    return $logger;
}

# create log methods which will emit "message" events
for my $method ( qw{
    fatal error warn info debug trace
    logdie logwarn error_die error_warn
    logconfess logcroak logcluck logcarp
} ) {
    monkey_patch __PACKAGE__, $method => sub { shift->emit( message => ($method, @_) ) }
}

sub BUILD ($self, $args) {
    # consume "message" events
    $self->on( message => $self->can('_message') );
}

sub _message ($self, $method, @message) {
    if ($self->_logger->$method( @message )) {
        my $hist = $self->history;
        my $max = $self->max_history_size;
        push @$hist, [ time, $method, @message ];
        splice (@$hist, 0, scalar @$hist - $max) if scalar @$hist > $max;
    }
    return $self;
}

# Mojo::Log provides 'path' 'handle' and 'format' to handle log location and
# formatting. Those make no sense in Log4perl environment.
sub path   { warn 'path() is not implemented' }
sub handle { warn 'handle() is not implemented' }
# Simply return given strings joined by newlines as otherwise Mojo::Log complains.
sub format {
    state $format_warning_was_shown = 0;
    warn 'format() is not properly implemented. Please use appenders.' unless $format_warning_was_shown++;
    return sub { '[' . localtime(shift) . '] [' . shift() . '] ' . join("\n", @_, '') };
}

# Mojolicious 8.23 adds method context which needs to be implemented.
sub context { shift }

sub log { shift->emit('message', lc(shift), @_) }

sub is_trace { shift->_logger->is_trace }
sub is_debug { shift->_logger->is_debug }
sub is_info  { shift->_logger->is_info  }
sub is_warn  { shift->_logger->is_warn  }
sub is_error { shift->_logger->is_error }
sub is_fatal { shift->_logger->is_fatal }

sub is_level ($self, $level = undef) {
    return 0 unless $level;

    if ($level =~ m/^(?:trace|debug|info|warn|error|fatal)$/o) {
        my $is_level = "is_$level";
        return $self->_logger->$is_level;
    }
    else {
        return 0;
    }
}

sub level ($self, $level = undef) {
    require Log::Log4perl::Level;
    if ($level) {
        return $self->_logger->level( Log::Log4perl::Level::to_priority(uc $level) );
    }
    else {
        return Log::Log4perl::Level::to_level( $self->_logger->level() );
    }
}

__PACKAGE__->meta->make_immutable;

=head1 NAME

OpenXPKI::Log4perl::MojoLogger - Log::Log4perl and Mojo::Log compatible logger

=head1 SYNOPSIS

  use OpenXPKI::Log4perl::MojoLogger;

  $c->log( OpenXPKI::Log4perl::MojoLogger->get_logger('openxpki.x') );

=head1 DESCRIPTION:

This module provides a Mojo::Log implementation that uses Log::Log4perl as the
underlying log mechanism. It provides all the methods listed in Mojo::Log (and
many more from Log4perl - see below).

=head1 LOG LEVELS

  $log->warn("something's wrong");

Below are all log levels from C<OpenXPKI::Log4perl::MojoLogger>, in descending priority:

=head2 C<fatal>

=head2 C<error>

=head2 C<warn>

=head2 C<info>

=head2 C<debug>

=head2 C<trace>

=head2 C<log>

You can also use the C<< log() >> method just like in C<< Mojo::Log >>:

  $log->log( info => 'I can haz cheezburger');

=head1 CHECKING LOG LEVELS

  if ($log->is_debug) {
      # expensive debug here
  }

=head2 C<is_fatal>

=head2 C<is_error>

=head2 C<is_warn>

=head2 C<is_info>

=head2 C<is_debug>

=head2 C<is_trace>

=head2 C<is_level>

You can also use the C<< is_level() >> method just like in C<< Mojo::Log >>:

  $logger->is_level( 'warn' );

=head1 ADDITIONAL LOGGING METHODS

The following Log4perl methods are also available for direct usage:

=head2 C<logwarn>

   $logger->logwarn($message);

This will behave just like:

   $logger->warn($message)
       && warn $message;

=head2 C<logdie>

   $logger->logdie($message);

This will behave just like:

   $logger->fatal($message)
       && die $message;

If you also wish to use the ERROR log level with C<< warn() >> and C<< die() >>, you can:

=head2 C<error_warn>

   $logger->error_warn($message);

This will behave just like:

   $logger->error($message)
       && warn $message;

=head2 C<error_die>

   $logger->error_die($message);

This will behave just like:

   $logger->error($message)
       && die $message;


Finally, there's the Carp functions that do just what the Carp functions do, but with logging:

=head2 C<logcarp>

    $logger->logcarp();        # warn w/ 1-level stack trace

=head2 C<logcluck>

    $logger->logcluck();       # warn w/ full stack trace

=head2 C<logcroak>

    $logger->logcroak();       # die w/ 1-level stack trace

=head2 C<logconfess>

    $logger->logconfess();     # die w/ full stack trace

=head1 ATTRIBUTES

=head2 Differences from Mojo::Log

The original C<handle> and C<path> attributes from C<< Mojo::Log >> are not implemented.

The C<format> attribute is also not implemented, and will trigger a warning when used.
For compatibility with Mojolicious' current I<404> development page, this
attribute will work returning a basic formatted message as
I<"[ date ] [ level ] message">.

The following attributes are still available:

=head2 C<level>

  my $level = $logger->level();

This will return an UPPERCASED string with the current log level (C<'DEBUG'>, C<'INFO'>, ...).

=head2 C<history>

This returns the last few logged messages as an array reference in the format:

    [
        [ 'timestamp', 'level', 'message' ], # older first
        [ 'timestamp', 'level', 'message' ],
        ...
    ]

=head2 C<max_history_size>

Maximum number of messages to be kept in the history buffer (see above). Defaults to 10.
