package OpenXPKI::Client::API::PluginRole;
use OpenXPKI -role;

use OpenXPKI::Client;

=head1 NAME

OpenXPKI::Client::API::PluginRole - Role for client side command plugins

=head1 DESCRIPTION

B<Not intended for direct use> - this is part of the internal API magic.

=head1 METHODS

=head2 hint_realm

Return the list of available realms by calling the backend.

=cut
sub hint_realm ($self, $input_params) {
    state $client = OpenXPKI::Client->new({
        SOCKETFILE => '/var/openxpki/openxpki.socket'
    });
    my $reply = $client->send_receive_service_msg('GET_REALM_LIST');
    $self->log->trace('Reply from GET_REALM_LIST: ' . Dumper $reply) if $self->log->is_trace;
    return [ map { $_->{name} } $reply->{PARAMS}->@* ];
}

1;
