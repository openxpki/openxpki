package OpenXPKI::Server::Log;
use OpenXPKI -class;

=head1 NAME

OpenXPKI::Server::Log - logging implementation for OpenXPKI

=head1 DESCRIPTION

This is the logging layer of OpenXPKI, a wrapper around L<Log::Log4perl>.

One important enhancement is that we replace the original DBI appender with our
own appender which can handle some funny details of some special databases.

=cut

# CPAN modules
use Log::Log4perl::Level;
use Log::Log4perl::MDC;

# Project modules
use OpenXPKI::Log4perl;

=head1 ATTRIBUTES

=head2 config

Either

=over

=item * a path to the L<Log::Log4perl> configuration file or

=item * a reference to a scalar holding the Log4perl configuration string.

=back

=cut

has 'config' => (
    isa => 'Str|ScalarRef|Undef',
    is => 'ro',
    default => '/etc/openxpki/log.conf',
    predicate => 'has_config',
);

=head2 use_current_config

Set this to C<1> to either use an already initialized Log4perl (i.e. the
currently active configuration) or create a fallback screen only logger using
L<Log::Log4perl/easy_init>.

=cut

has 'use_current_config' => (
    isa => 'Bool',
    is => 'ro',
    default => 0,
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
has 'app' => (
    is => 'ro',
    isa => 'Log::Log4perl::Logger',
    init_arg => undef,
    lazy => 1,
    default => sub { shift->application }
);

=head2 Constructor

The constructor only accepts the named parameter C<config> which can either be

=over

=item * a path to the L<Log::Log4perl> configuration file,

=item * a reference to a scalar holding the Log4perl configuration string or

=item * C<undef> to either use an already initialized Log4perl or create a
screen only logger using L<Log::Log4perl/easy_init>

=back

=cut

sub BUILD ($self, $args) {
    # caller explicitely asked to NOT use config: try reusing Log4perl
    if ($self->use_current_config and Log::Log4perl->initialized) {
        return;
    } else {
        OpenXPKI::Log4perl->init_or_fallback($self->config);
    }
}

=head1 METHODS

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

__PACKAGE__->meta->make_immutable;

__END__

