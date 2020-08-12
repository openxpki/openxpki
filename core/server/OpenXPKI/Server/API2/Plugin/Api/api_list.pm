package OpenXPKI::Server::API2::Plugin::Api::api_list;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Api::api_list

=cut

=head1 COMMANDS

=head2 api_list

List all available API commands.

=cut
command "api_list" => {
} => sub {
    my ($self, $params) = @_;

    return join "\n", sort keys %{ $self->rawapi->commands };
};

__PACKAGE__->meta->make_immutable;
