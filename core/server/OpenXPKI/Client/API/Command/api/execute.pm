package OpenXPKI::Client::API::Command::api::execute;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::api::execute

=head1 DESCRIPTION

Execute a named API command on the server.

The command name is taken from the C<command> parameter. It is also
possible to replace the term I<execute> with the actual command name,
e.g. C<oxi api get_cert ...>.

Parameters for the API command are appended as C<key=value> pairs;
boolean flags can be given as bare C<key>. The parameters are validated
against the command's signature before execution.

Protected commands are executed if called with a configured
authentication key. Even if the command itself runs in global mode it
is currently mandatory to provide a realm.

=cut

command "execute" => {
    command => { isa => 'Str', label => 'Name of the API command to execute', hint => 'hint_command', required => 1 },
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
