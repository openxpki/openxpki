package OpenXPKI::Client::API::PluginRole;
use OpenXPKI -role;

with 'OpenXPKI::Role::Logger';

# Project modules
use OpenXPKI::Client;
use OpenXPKI::DTO::Message::Command;
use OpenXPKI::DTO::Message::Enquiry;
use OpenXPKI::DTO::Message::ProtectedCommand;

=head1 NAME

OpenXPKI::Client::API::PluginRole - Role for client side command plugins

=head1 DESCRIPTION

B<Not intended for direct use> - this is part of the internal API magic.

=head1 METHODS

=head2 hint_realm

Return the list of available realms by calling the backend.

=cut
sub hint_realm ($self, $input_params) {
    my $realms = $self->run_enquiry('realm');
    $self->log->trace(Dumper $realms->result) if $self->log->is_trace;
    return [ map { $_->{name} } ($realms->result || [])->@* ] ;
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

=head2 run_enquiry I<topic>, I<params>

=cut

sub run_enquiry ($self, $topic, $params = undef) {
    $self->log->debug("Running service enquiry on topic '$topic'");
    my $msg = OpenXPKI::DTO::Message::Enquiry->new(
        topic => $topic,
        defined $params ? (params => $params) : ()
    );

    return $self->_send_message($msg);
}

=head2 run_command I<command>, I<params>

=cut

sub run_command ($self, $command, $params = undef) {
    $self->log->debug("Running command '$command'");
    my $msg = OpenXPKI::DTO::Message::Command->new(
        command => $command,
        defined $params ? (params => $params) : ()
    );

    return $self->_send_message($msg);
}

=head2 run_protected_command I<command>, I<params>

=cut

sub run_protected_command ($self, $command, $params = undef) {
    $self->log->debug("Running command '$command' in protected mode");
    my $msg = OpenXPKI::DTO::Message::ProtectedCommand->new(
        command => $command,
        defined $params ? (params => $params) : ()
    );

    return $self->_send_message($msg);
}

sub _send_message ($self, $msg) {
    my $resp = $self->rawapi->client->send_message($msg);

    OpenXPKI::Exception::Command->throw(
        message => $resp->message,
    ) if $resp->isa('OpenXPKI::DTO::Message::ErrorResponse');

    OpenXPKI::Exception::Command->throw(
        message => 'Got unknown response on command execution',
        error => $resp,
    ) unless $resp->isa('OpenXPKI::DTO::Message::Response');

    return $resp;
}

1;
