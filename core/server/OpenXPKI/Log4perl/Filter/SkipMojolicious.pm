package OpenXPKI::Log4perl::Filter::SkipMojolicious;

use Log::Log4perl::Config; # subclassing Log::Log4perl::Filter without this import dies
use OpenXPKI -parent => 'Log::Log4perl::Filter';

use Log::Log4perl;

=head1 NAME

OpenXPKI::Log4perl::Filter::SkipMojolicious - C<Log4perl> filter to suppress Mojolicious messages

=head1 DESCRIPTION

Mojolicious creates some log messages that we want to suppress, e.g.:

    GET "/scep/generic" [Mojolicious::dispatch]
    Routing to a callback [Mojolicious::Routes::_callback]
    Routing to controller "OpenXPKI::Client::Web::Controller" and action "index" [Mojolicious::Routes::_controller]
    200 OK (0.170604s, 5.862/s) [Mojolicious::Controller::rendered]

We cannot use C<Log4perl> categories to distinct between server-level messages
from OpenXPKI and Mojolicious because our L<OpenXPKI::Log4perl::MojoLogger>
with log category I<openxpki.client.server> is used for both.

=cut

sub new {
    my ($class, %params) = @_;
    my $self = { %params };
    bless $self, $class;
    return $self;
}

# inspired by %M placeholder processing in Log::Log4perl::Layout::PatternLayout->render()
sub ok ($self, %p) {
    my $subroutine;
    my $caller_offset = Log::Log4perl::caller_depth_offset( $Log::Log4perl::caller_depth + 3 );
    my $levels_up = 0;
    while () {
        $levels_up++;
        my @callinfo = caller($caller_offset + $levels_up);
        $subroutine = $callinfo[3];
        # If we're inside an eval, go up one level further.
        last unless (defined $subroutine and $subroutine eq "(eval)");
    }
    $subroutine //= "main::";
    return $subroutine =~ /^Mojolicious/ ? 0 : 1;
}

1;