package OpenXPKI::Server::API2::Plugin::UI::send_notification;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::UI::send_notification

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 send_notification

Sends out a notification using the configured notification handlers.

B<Parameters>

=over

=item * C<message> I<Str> - message or message ID to be sent (depends on the
notification handlers)

=item * C<params> I<HashRef> - additional parameters to pass to the handler.
Optional.

=back

=cut
command "send_notification" => {
    message => { isa => 'AlphaPunct', required => 1, },
    params  => { isa => 'HashRef', default => sub { {} }, },
} => sub {
    my ($self, $params) = @_;

    return CTX('notification')->notify({
        MESSAGE => $params->message,
        DATA    => $params->params
    });
};

__PACKAGE__->meta->make_immutable;
