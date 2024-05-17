package OpenXPKI::Client::API::Command;
use OpenXPKI -role;

with 'OpenXPKI::Role::Logger';

use OpenXPKI::Client;

=head1 NAME

OpenXPKI::Client::API::Command

=head1 SYNOPSIS

Base role for all implementations handled by C<OpenXPKI::Client::API>.

=head1 METHODS

=cut
sub needs_realm ($class) {
    $class->meta->add_default_attribute_spec(
        realm => {
            isa => 'Str', required => 1,
            label => 'PKI Realm', description => 'Name of the realm to operate this command on',
            hint => 'list_realm',
        }
    );
}

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

=head2 is_protected

Return true if the command is marked as a protected command

=cut
sub is_protected ($self) {
    return $self->DOES('OpenXPKI::Client::API::Command::Protected');
}

sub _build_hash_from_payload ($self, $param, $allow_bool = 0) {
    return {} unless $param->has_payload;

    my %params;
    foreach my $arg ($param->payload->@*) {
        my ($key, $val) = split('=', $arg, 2);
        $val = 1 if (not defined $val and $allow_bool);
        next unless defined $val;
        if ($params{$key}) {
            if (not ref $params{$key}) {
                $params{$key} = [$params{$key}, $val];
            } else {
                push @{$params{$key}}, $val;
            }
        } else {
            $params{$key} = $val;
        }
    }
    return \%params;
}

1;
