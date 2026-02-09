package OpenXPKI::Client::API::Command::api::help;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::api::help

=head1 DESCRIPTION

Show the argument list and documentation for a given API command.

Returns the command's parameter definitions including types, defaults
and whether a parameter is required or optional.

=cut

command "help" => {
    command => { isa => 'Str', label => 'Name of the API command to describe', hint => 'hint_command', required => 1 },
} => sub ($self, $param) {

    return $self->help_command( $param->command );
};

__PACKAGE__->meta->make_immutable;
