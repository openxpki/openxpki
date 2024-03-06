package OpenXPKI::Role::Logger;

use Log::Log4perl qw(:easy);
use Moose::Role;
use OpenXPKI::Server::Context qw(CTX);

=head1 Attributes

=item log

Holds an instance of Log::Log4perl::Logger.

If not set from the implementation, C<_init_logger> is called as
builder on first use.

=cut

has log => (
    is => 'ro',
    isa => 'Log::Log4perl::Logger',
    builder => '_init_logger',
    lazy => 1,
);

=head1 Internal Methods

=head2 _init_logger

Returns C<CTX('log')->application()> if the context object is available.

Otherwise it returns the Log4perl default logger which is initializes
with with loglevel I<ERROR> in case it was not iniitalized before.

=cut

sub _init_logger {

    if (OpenXPKI::Server::Context::hascontext('log')) {
        return CTX('log')->application();
    }
    if(!Log::Log4perl->initialized()) {
        Log::Log4perl->easy_init($ERROR);
    }
    return Log::Log4perl->get_logger();

}

1;