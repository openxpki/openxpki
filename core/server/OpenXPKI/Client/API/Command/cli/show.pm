package OpenXPKI::Client::API::Command::cli::show;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::cli::show

=head1 DESCRIPTION

Show information related to connection and authentication of this client

=cut

command "show" => {
} => sub ($self, $param) {

    # accessing internals via rawapi
    my $client = $self->rawapi->client;
    my $res = {
        socketfile => $OpenXPKI::Defaults::SERVER_SOCKET,
        timeout => 30,
        account_key => 'none',
        ping => 'failed',
    };

    if (my $pk = $client->authenticator->account_key) {
        $res->{account_id} = $pk->export_key_jwk_thumbprint('SHA256');
        $res->{account_key} = $pk->export_key_pem('public');
    }
    return $res;

};

__PACKAGE__->meta->make_immutable;


