package OpenXPKI::Log4perl::MojoLogger;
use OpenXPKI qw( -class -nonmoose );

extends 'Mojo::EventEmitter';

=head1 NAME

OpenXPKI::Log4perl::MojoLogger - C<Log::Log4perl> and C<Mojo::Log> compatible logger

=head1 SYNOPSIS

  my $log = OpenXPKI::Log4perl::MojoLogger->get_logger('openxpki.x'); # constructor
  $log->info('...');

=head1 DESCRIPTION

This module provides a L<Mojo::>Log implementation that uses L<Log::Log4perl> as
the underlying log mechanism. It provides all the methods listed in L<Mojo::Log>
(and many more from L<Log::Log4perl::Logger> - see below).

=cut

use Log::Log4perl;
use Mojo::Util qw( monkey_patch );

Log::Log4perl->wrapper_register(__PACKAGE__); # make Log4perl step up to the next call frame
Log::Log4perl->wrapper_register('Mojo::EventEmitter');

our $LOGGERS_BY_NAME = {};


=head1 ATTRIBUTES

=head2 C<category>

Returns the logging category / facility of this logger.

=cut
has category => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

=head2 C<history>

This returns the last few logged messages as an array reference in the format:

    [
        [ 'timestamp', 'level', 'message' ], # older first
        [ 'timestamp', 'level', 'message' ],
        ...
    ]

=cut
has history => (
    is => 'rw',
    isa => 'ArrayRef',
    init_arg => undef,
    default => sub { [] },
);

=head2 C<max_history_size>

Maximum number of messages to be kept in the history buffer (see above). Defaults to 10.

=cut
has max_history_size => (
    is => 'rw',
    isa => 'Int',
    init_arg => undef,
    default => 10,
);

# Log4perl work horse doing the actual logging
has _logger => (
    is => 'rw',
    isa => 'Log::Log4perl::Logger',
    init_arg => undef,
    lazy => 1,
    default => sub { Log::Log4perl->get_logger(shift->category) },
);

=head1 METHODS

=cut
# Static method: constructor replacement
sub get_logger {
    my ($class, $category) = @_;

    # todo - check why we get requests without category
    $category //= 'fallback';

    # Have we created it previously?
    return $LOGGERS_BY_NAME->{$category} if exists $LOGGERS_BY_NAME->{$category};

    # Instantiate ourself
    my $log = $class->new( category => $category );
    $LOGGERS_BY_NAME->{$category} = $log; # save it in global structure

    return $log;
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

=head2 Log levels

  $log->warn("something's wrong");

Log methods in descending priority:

=head3 C<fatal>

=head3 C<error>

=head3 C<warn>

=head3 C<info>

=head3 C<debug>

=head3 C<trace>

=head2 Special logging methods

The following C<Log::Log4perl> methods are also available for direct usage:

=head3 C<logwarn>

   $log->logwarn($message);

This will behave just like:

   $log->warn($message)
       && warn $message;

=head3 C<logdie>

   $log->logdie($message);

This will behave just like:

   $log->fatal($message)
       && die $message;

If you also wish to use the ERROR log level with C<< warn() >> and C<< die() >>, you can:

=head3 C<error_warn>

   $log->error_warn($message);

This will behave just like:

   $log->error($message)
       && warn $message;

=head3 C<error_die>

   $log->error_die($message);

This will behave just like:

   $log->error($message)
       && die $message;


Finally, there's the Carp functions that do just what the Carp functions do, but with logging:

=head3 C<logcarp>

    $log->logcarp();        # warn w/ 1-level stack trace

=head3 C<logcluck>

    $log->logcluck();       # warn w/ full stack trace

=head3 C<logcroak>

    $log->logcroak();       # die w/ 1-level stack trace

=head3 C<logconfess>

    $log->logconfess();     # die w/ full stack trace

=cut

for my $method ( qw{
    fatal error warn info debug trace
    logdie logwarn error_die error_warn
    logconfess logcroak logcluck logcarp
} ) {
    monkey_patch __PACKAGE__, $method => sub ($self, @args) {
        $self->emit( message => ($method, @args) );
    }
}

=head3 C<log>

You can use the C<log()> method just like in C<Mojo::Log>:

  $log->log(info => 'I can haz cheezburger');

=cut
# create log methods which will emit "message" events
sub log ($self, $method, @args) {
    $self->emit( message => (lc($method), @args) );
}

=head2 Checking log levels

  $log->trace('...') if $log->is_trace; # guard expensive trace logging

=head3 C<is_fatal>

=head3 C<is_error>

=head3 C<is_warn>

=head3 C<is_info>

=head3 C<is_debug>

=head3 C<is_trace>

=cut
sub is_trace { shift->_logger->is_trace }
sub is_debug { shift->_logger->is_debug }
sub is_info  { shift->_logger->is_info  }
sub is_warn  { shift->_logger->is_warn  }
sub is_error { shift->_logger->is_error }
sub is_fatal { shift->_logger->is_fatal }

=head3 C<is_level>

You can also use the C<< is_level() >> method just like in C<< Mojo::Log >>:

  $log->is_level( 'warn' );

=cut
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

=head2 C<level>

  my $level = $log->level();

This will return an UPPERCASED string with the current log level, i.e. C<'DEBUG'>, C<'INFO'>, ...

=cut
sub level ($self, $level = undef) {
    require Log::Log4perl::Level;
    if ($level) {
        return $self->_logger->level( Log::Log4perl::Level::to_priority(uc $level) );
    }
    else {
        return Log::Log4perl::Level::to_level( $self->_logger->level() );
    }
}

=head1 DIFFERENCES TO MOJO::LOG

The C<handle>, C<path> and C<context> attributes from C<Mojo::Log> are not
implemented.

=cut

# Mojo::Log provides 'path' 'handle' and 'format' to handle log location and
# formatting. Those make no sense in Log4perl environment.
sub path {
    state $path_warning_was_shown = 0;
    warn 'path() is not implemented' unless $path_warning_was_shown++;
    shift
}

sub handle {
    state $handle_warning_was_shown = 0;
    warn 'handle() is not implemented' unless $handle_warning_was_shown++;
    shift
}

# Mojolicious 8.23 adds method context which needs to be implemented.
sub context { shift }

=pod

The C<format> attribute is also not implemented, and will trigger a warning when used.
For compatibility with Mojolicious' current I<404> development page, this
attribute will work returning a basic formatted message as
I<"[ date ] [ level ] message">.

=cut

# Simply return given strings joined by newlines as otherwise Mojo::Log complains.
sub format {
    state $format_warning_was_shown = 0;
    warn 'format() is not properly implemented. Please use appenders.' unless $format_warning_was_shown++;
    return sub { '[' . localtime(shift) . '] [' . shift() . '] ' . join("\n", @_, '') };
}

__PACKAGE__->meta->make_immutable;
