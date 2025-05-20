package OpenXPKI::Client::API::Command::cli::ping;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::cli::show

=head1 DESCRIPTION

Show information related to connection and authentication of this client

=cut

command "ping" => {
} => sub ($self, $param) {

    return $self->run_enquiry('ping');
};

__PACKAGE__->meta->make_immutable;


