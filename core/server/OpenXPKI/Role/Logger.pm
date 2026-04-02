package OpenXPKI::Role::Logger;
use OpenXPKI qw( -role -typeconstraints );

# Project modules
use OpenXPKI::Log4perl;

=head1 ATTRIBUTES

=over

=item log

Holds a logger object that provides the following methods:

=over

=item * C<trace>

=item * C<debug>

=item * C<info>

=item * C<warn>

=item * C<error>

=item * C<fatal>

=item * corresponding C<is_*> methods

=back

Defaults to C<OpenXPKI::Log4perl-E<gt>get_logger>.

=back

=cut

has log => (
    is => 'ro',
    isa => duck_type( [qw(
           trace    debug    info    warn    error    fatal
        is_trace is_debug is_info is_warn is_error is_fatal
    )] ),
    builder => '_build_logger',
    lazy => 1,
);

=head1 INTERNAL METHODS

=head2 _build_logger

Returns C<CTX('log')->application()> if the server context object is available.

Otherwise it returns the default logger which is initializes with with loglevel
I<ERROR> in case it was not initalized before.

=cut

sub _build_logger {
    # init Log4perl - no-op if already initialized
    OpenXPKI::Log4perl->init_or_fallback;
    # return default logger set via OpenXPKI::Log4perl->set_default_facility()
    return OpenXPKI::Log4perl->get_logger;
}

1;