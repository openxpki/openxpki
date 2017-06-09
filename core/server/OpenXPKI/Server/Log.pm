package OpenXPKI::Server::Log;

use strict;
use warnings;
use English;
use Moose;

use Log::Log4perl qw(:easy);
use Log::Log4perl::Level;
use Log::Log4perl::MDC;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;

has 'CONFIG' => (
    isa     => 'Str',
    is      => 'ro',
    default => '/etc/openxpki/log.conf',
);

for my $name (qw( application auth system workflow )) {
    my $logger = 'openxpki.' . $name;
    has $name => (
        is      => 'ro',
        isa     => 'Log::Log4perl::Logger',
        default => sub { Log::Log4perl->get_logger($logger) }
    );
}

sub BUILD {
    my $self = shift;

    my $config = $self->CONFIG();

    if ( $config && -e $config ) {
        Log::Log4perl->init($config);
    }
    else {
        warn "Do easy_init - config $config not found ";
        Log::Log4perl->easy_init($WARN);
    }
}

=item audit

Audit logger has a subcategory

=cut
sub audit {
    my $self = shift;
    my $subcat = shift || 'system';
    return Log::Log4perl->get_logger("openxpki.audit.$subcat");
}

=item log DEPRECATED

This is the old method used in pre 1.18 and shouldnt be used any longer!
Each call triggers a deprecation warning with facility "openxpki.deprecated"

=cut

sub log {

    my $self = shift;
    my $keys = {@_};

    my ( $facility, $prio, $msg ) =
      ( "system", "FATAL", "EMPTY LOG MESSAGE WAS USED!" );

    my $callerlevel = 0;
    if ( defined $keys->{CALLERLEVEL} ) {
        $callerlevel = $keys->{CALLERLEVEL};
    }
    my ($package,   $filename, $line,       $subroutine, $hasargs,
        $wantarray, $evaltext, $is_require, $hints,      $bitmask
    ) = caller($callerlevel);

    ## get parameters
    if ( ref $keys->{FACILITY} eq 'ARRAY' ) {
        foreach my $entry ( @{ $keys->{FACILITY} } ) {
            $self->log(
                %{$keys},
                FACILITY    => $entry,
                CALLERLEVEL => $callerlevel + 1,
            );
        }
        return 1;
    }

    $facility = lc( $keys->{FACILITY} )
      if ( exists $keys->{FACILITY}
        and $keys->{FACILITY} =~
        m{ \A (?:application|auth|audit|system|workflow|) \z }xms
      );

    $prio = uc( $keys->{PRIORITY} )
      if ( exists $keys->{PRIORITY}
        and $keys->{PRIORITY} =~
        m{ \A (?:debug|info|warn|error|fatal) \z }xms );

    if ( exists $keys->{MESSAGE} and length( $keys->{MESSAGE} ) ) {
        $package = $keys->{MODULE} if ( exists $keys->{MODULE} );
        $line    = $keys->{LINE}   if ( exists $keys->{LINE} );
        $msg     = $keys->{MESSAGE};
    }

    OpenXPKI::Exception->throw(
        message => "I18N_OPENXPKI_SERVER_LOG_EMPTY_LOG_MESSAGE",
        params  => {
            "PACKAGE"  => $package,
            "FILENAME" => $filename,
            "LINE"     => $line
        }
    ) unless ($msg);

    # get session information
    my $user;
    my $role = '';
    my $session_short;
    if ( OpenXPKI::Server::Context::hascontext('session') ) {
        eval {
            no warnings;
            $user = CTX('session')->get_user();
        };
        eval {
            no warnings;
            $role = '(' . CTX('session')->get_role() . ')';
        };
        eval {
            no warnings;

         # first 4 characters of session id are enough to trace flow in sessions
            $session_short = substr( CTX('session')->get_id(), 0, 4 );
        };
    }

    # get workflow instance information
    my $wf_id = Log::Log4perl::MDC->get('wfid');

    ## build and store message
    $msg =
        "[$package" . " ($line)"
      . ( defined $user          ? '; ' . $user . $role : '' )
      . ( defined $session_short ? '@' . $session_short : '' )
      . ( $wf_id         ? '#' . $wf_id         : '' )
      . "] $msg";

    # remove trailing newline characters
    {
        local $INPUT_RECORD_SEPARATOR = '';
        chomp $msg;
    }

    Log::Log4perl->get_logger('openxpki.deprecated')->info(sprintf(
        'Deprecated log call, %s from %s:%i', lc( $keys->{FACILITY} ), $package, $line));

    return $self->$facility()->log( Log::Log4perl::Level::to_priority( ${prio} ), $msg );

}

# install wrapper / helper subs - DEPRECATED, use new format
no strict 'refs';
for my $prio (qw/ debug info warn error fatal trace /) {
    *{$prio} = sub {
        my ( $self, $message, $facility ) = @_;

        if (!$facility ||
            $facility !~ m{ \A (?:application|auth|audit|system|workflow) \z }xms) {
            $facility = 'system';
        }
        $self->$facility()->$prio($message);
    };
}

1;
__END__

=head1 Name

OpenXPKI::Server::Log - logging implementation for OpenXPKI

=head1 Description

This is the logging layer of OpenXPKI. Mainly we use Log::Log4perl.
The important difference is that we replace the original DBI appender
with our own appender which can handle some funny details of some
special databases. Additionally our log function do some special
things to meet our requirements.

=head1 Functions

=head2 new

This function only accepts one parameter - C<CONFIG>.
C<CONFIG> includes the filename of the Log::Log4perl configuration.

=head2 init

is used by both new and re_init to initialize the Log4perl objects

=head2 re_init

is just a fancier name for init, is called in the forked child
at ForkWorkflowInstance.pm

=head2 log

This function creates a new log message it accept the following
parameters:

=over

=item * PRIORITY (debug, info, warn, error, fatal)

=item * FACILITY (auth, audit, monitor, system, workflow)

It is possible to specify more than one facility by passing an array
reference here.

=item * MESSAGE (normal text string)

=item * MODULE (overwrites the internally determined caller) - optional

=item * FILENAME (overwrites the internally determined caller) - optional

=item * LINE (overwrites the internally determined caller - optional)

=back

Default is C<system.fatal: [OpenXPKI] undefined message>.

=head2 debug

Shortcut to L</log> that logs a message with C<< PRIORITY => "debug" >>.

Positional parameters:

=over

=item * B<$message> log message

=item * B<$facility> the logging facility - optional, default: C<monitor>

=back

=head2 info

Shortcut to L</log> that logs a message with C<< PRIORITY => "info" >>.

Similar to L</debug>.

=head2 warn

Shortcut to L</log> that logs a message with C<< PRIORITY => "warn" >>.

Similar to L</debug>.

=head2 error

Shortcut to L</log> that logs a message with C<< PRIORITY => "error" >>.

Similar to L</debug>.

=head2 fatal

Shortcut to L</log> that logs a message with C<< PRIORITY => "fatal" >>.

Similar to L</debug>.
