package OpenXPKI::Client::API::Command::api::list;
use OpenXPKI -plugin;

with 'OpenXPKI::Client::API::Command::api';
set_namespace_to_parent;

=head1 NAME

OpenXPKI::Client::API::Command::api::list

=head1 SYNOPSIS

Show the list of available commands

=cut

command "list" => {
} => sub ($self, $param) {

    return $self->hint_command;
};

__PACKAGE__->meta->make_immutable;
