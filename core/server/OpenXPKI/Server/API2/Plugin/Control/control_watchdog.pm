package OpenXPKI::Server::API2::Plugin::Control::control_watchdog;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Control::control_watchdog

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::Control;


=head1 COMMANDS

=head2 control_watchdog

Control the watchdog process.

B<Parameters>

=over

=item * C<action> I<Str> - one of the following (case insensitive):

=over

=item * I<start>: start a watchdog process.

Returns 1 if the process was started or 0 if the watchdog was disabled via
configuration.

=item * I<stop>: stop all watchdog process(es)

=item * I<status>: returns a I<HashRef> with process information:

    {
        pid => [ ... ],  # watchdog process IDs
        children => $no, # number of child processes spawned as workers
    }

=back

=back

=cut
command "control_watchdog" => {
    action => { isa => 'Str', required => 1, matching => qr/^ ( start | stop | status ) $/sxi},
} => sub {
    my ($self, $params) = @_;
    my $action = lc($params->action);

    if ("start" eq $action) {
        CTX('log')->system->info("Watchdog start requested via API");
        return OpenXPKI::Server::Watchdog->start_or_reload;
    }
    if ("stop" eq $action) {
        CTX('log')->system->info("Watchdog termination requested via API");
        return OpenXPKI::Server::Watchdog->terminate;
    }
    if ("status" eq $action) {
        my $result = OpenXPKI::Control::get_pids;
        return {
            pid => $result->{watchdog},
            children => ref $result->{workflow} ? scalar @{$result->{workflow}} : 0
        }
    }
};

__PACKAGE__->meta->make_immutable;
