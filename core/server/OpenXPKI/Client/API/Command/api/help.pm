package OpenXPKI::Client::API::Command::api::help;
use OpenXPKI -plugin;

command_setup
    parent_namespace_role => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::api::help

=head1 SYNOPSIS

Show the argument list for the given command.

=cut

command "help" => {
    command => { isa => 'Str', label => 'Command', hint => 'hint_command', required => 1 },
} => sub ($self, $param) {

    return $self->help_command( $param->command );
};

__PACKAGE__->meta->make_immutable;
