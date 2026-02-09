package OpenXPKI::Client::API::Command::api::list;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::api::list

=head1 DESCRIPTION

List all available API commands on the server.

Returns an array of command names. Use C<api help E<lt>commandE<gt>>
to get details about a specific command.

=cut

command "list" => {
} => sub ($self, $param) {
    return hint_command($self,'');
};

__PACKAGE__->meta->make_immutable;
