package OpenXPKI::Client::API::Command::api::execute;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::api::execute

=head1 DESCRIPTION

Run a named API command on the server.

The name of the command to run is taken from the command parameter, it
is also supported to replace the term I<execute> with the actual name
of the command, e.g. 'oxi api get_cert ...'.

Parameters for the command itself are just appended to the command
as I<key=value>, flags are given as I<key>.

Protected commands can be executed if called with a configured
authentication key. Even if the command itself might run in global
mode it is currently mandatory to provide a realm.

=cut

command "execute" => {
    command => { isa => 'Str', label => 'Command', hint => 'hint_command', required => 1 },
} => sub ($self, $param) {

    my $command = $param->command;
    my $payload = $self->build_hash_from_payload($param, 1);

    my $api_params = $self->help_command($command);
    my $args = $api_params->{arguments};
    my $protected = $api_params->{protected};

    my $cmd_parameters;
    foreach my $key (keys $args->%*) {
        $self->log->debug("Checking $key");
        if (defined $payload->{$key}) {
            $cmd_parameters->{$key} = $payload->{$key};
            delete $payload->{$key};
        } elsif ($args->{$key}->{required}) {
            die "The parameter *$key* is mandatory for running '$command'\n";
        }
    }

    if (my @keys = keys %$payload) {
        die "One or more arguments are not accepted by the API command: " . join(',', @keys) . "\n";
    }

    my $res;
    if ($protected) {
        $res = $self->run_protected_command($command, $cmd_parameters);
    } else {
        $res = $self->run_command($command, $cmd_parameters);
    }
    return $res;

};

__PACKAGE__->meta->make_immutable;
