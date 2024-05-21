package OpenXPKI::Client::API::Command::api::execute;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::api::execute

=head1 SYNOPSIS

Run a bare API command on the server

=cut

sub hint_command ($self, $input_params) {
    my $actions = $self->rawapi->run_enquiry('command');
    $self->log->trace(Dumper $actions->result) if ($self->log->is_trace);
    return $actions->result || [];
}

command "execute" => {
    command => { isa => 'Str', label => 'Command', hint => 'hint_command', required => 1 },
} => sub ($self, $param) {

    my $command = $param->command;
    my $payload = $self->build_hash_from_payload($param, 1);

    my $api_params = $self->help_command($command);
    my $cmd_parameters;
    foreach my $key (keys %$api_params) {
        $self->log->debug("Checking $key");
        if (defined $payload->{$key}) {
            $cmd_parameters->{$key} = $payload->{$key};
            delete $payload->{$key};
        } elsif ($api_params->{$key}->{required}) {
            die "The parameter $key is mandatory for running $command";
        }
    }

    if (my @keys = keys %$payload) {
        die "One or more arguments are not accepted by the API command: " . join(',', @keys);
    }

    my $res = $self->rawapi->run_command($param->command, $cmd_parameters);
    return $res;

};

__PACKAGE__->meta->make_immutable;
