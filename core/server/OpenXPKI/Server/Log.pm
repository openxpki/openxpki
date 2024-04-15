package OpenXPKI::Server::Log;

use Moose;

=head1 Name

OpenXPKI::Server::Log - logging implementation for OpenXPKI

=head1 Description

This is the logging layer of OpenXPKI. Mainly we use Log::Log4perl.
The important difference is that we replace the original DBI appender
with our own appender which can handle some funny details of some
special databases. Additionally our log function do some special
things to meet our requirements.

=head1 Functions

=cut

use English;

use OpenXPKI::Log4perl;
use Log::Log4perl::Level;
use Log::Log4perl::MDC;
use OpenXPKI::Exception;

has 'CONFIG' => (
    isa     => 'Str|ScalarRef|Undef',
    is      => 'ro',
    default => '/etc/openxpki/log.conf',
);

for my $name (qw( application auth system workflow deprecated )) {
    my $logger = 'openxpki.' . $name;
    has $name => (
        is      => 'ro',
        isa     => 'Log::Log4perl::Logger',
        default => sub { Log::Log4perl->get_logger($logger) }
    );
}

# alias for "application"
has app => (
    is => 'ro',
    isa => 'Log::Log4perl::Logger',
    init_arg => undef,
    lazy => 1,
    default => sub { shift->application }
);

=head2 Constructor

The constructor only accepts the named parameter C<CONFIG> which can either be

=over

=item * a path to the L<Log::Log4perl> configuration file,

=item * a reference to a scalar holding the Log4perl configuration string or

=item * undef to either use an already initialized Log4perl or create a screen
only logger using L<Log::Log4perl/easy_init>

=back

=cut

sub BUILD {
    my $self = shift;

    my $config = $self->CONFIG();

    # caller explicitely asked to NOT use config: try reusing Log4perl
    return if not(defined $config) and Log::Log4perl->initialized;

    # CONFIG was provided
    OpenXPKI::Log4perl->init_or_fallback( $config );
}

=head2 audit

Returns the audit logger of the given subcategory I<openxpki.audit.$subcat>.

Positional parameters:

=over

=item * B<$subcat> sub category - optional, default: I<system>

=back


=cut

sub audit {
    my $self = shift;
    my $subcat = shift || 'system';
    return Log::Log4perl->get_logger("openxpki.audit.$subcat");
}

# TODO Remove deprecated CTX('log')->log() method
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
    my $user = Log::Log4perl::MDC->get('user');
    my $role = Log::Log4perl::MDC->get('role');
    my $session_short = Log::Log4perl::MDC->get('sid');

    # get workflow instance information
    my $wf_id = Log::Log4perl::MDC->get('wfid');

    ## build and store message
    $msg =
        "[$package" . " ($line)"
      . ( $user ? '; ' . $user . ($role ? "($role)" : "") : '' )
      . ( $session_short ? '@' . $session_short : '' )
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
# TODO Remove deprecated CTX('log')->debug() method etc.
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

__PACKAGE__->meta->make_immutable;

__END__

