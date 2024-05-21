package OpenXPKI::Client::API::PluginRole;
use OpenXPKI -role;

with 'OpenXPKI::Role::Logger';

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

sub build_hash_from_payload ($self, $param, $allow_bool = 0) {
    return {} unless $param->has_payload;

    my %result;
    foreach my $arg ($param->payload->@*) {
        my ($key, $val) = split('=', $arg, 2);
        $val = 1 if (not defined $val and $allow_bool);
        next unless defined $val;
        if ($result{$key}) {
            if (not ref $result{$key}) {
                $result{$key} = [$result{$key}, $val];
            } else {
                push @{$result{$key}}, $val;
            }
        } else {
            $result{$key} = $val;
        }
    }
    return \%result;
}

1;
