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

=head2 build_hash_from_payload I<param> I<allow_bool>

Parse the payload part given to the command into a hash structure.

Expects the I<param> hash of the command, not the payload argument itself!

The I<payload> can either be array ref holding strings of key=value or a
hash with the keys on the first level.

If I<allow_bool> is set, single words (in array mode) are considered to be a
boolean true value.

=cut

sub build_hash_from_payload ($self, $param, $allow_bool = 0) {
    return {} unless $param->has_payload;

    # if payload is injected from JSON it is already the expected structure
    if (ref $param->payload eq 'HASH') {
        return $param->payload;
    }

    my %result;
    # payload is a list of "key=value" strings or just "key" for boolean items
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

Run a regular command, requires a "regular" authenticated session
within a realm (usually done anonymously via the _System stack).

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

Run a protected command, will set the realm if one was given as
argument, otherwise runs in the _void realm.

Requires authentication via an admin key pair.

=cut

sub run_protected_command ($self, $command, $params = undef) {
    $self->log->debug("Running command '$command' in protected mode");
    my $msg = OpenXPKI::DTO::Message::ProtectedCommand->new(
        command => $command,
        defined $params ? (params => $params) : ()
    );

    return $self->_send_message($msg);
}

=head2 run_realm_command I<pki_realm>, I<command>, I<params>

Run a protected command and enforce the pki_realm to run this command.

=cut

sub run_realm_command ($self, $pki_realm, $command, $params = undef) {
    $self->log->debug("Running command '$command' in protected mode");
    my $msg = OpenXPKI::DTO::Message::ProtectedCommand->new(
        command => $command,
        pki_realm => $pki_realm,
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
