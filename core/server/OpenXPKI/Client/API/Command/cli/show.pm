package OpenXPKI::Client::API::Command::cli::show;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::cli::show

=head1 DESCRIPTION

Show information related to connection and authentication of this client.

Tries to connect to the backend. If an authentication key is found, the public
key and key identifier are printed and the key is used to connect.

If the I<pubkey> flag is given, only prints the public key.

=cut

command "show" => {
    pubkey => { isa => 'Bool', label => 'Output public key only' },
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

    # keyout only
    if ($param->pubkey) {
        # keyout requested but no key found
        die "export of key request but no key found\n" unless ($res->{account_key});
        return $res->{account_key};
    }

    try {
        my $ping = $self->run_enquiry('ping');
        $res->{ping} = $ping->result() if (blessed $ping);
    } catch($err) {
        $res->{ping} = "failed ($err)";
    }

    return $res;

};

__PACKAGE__->meta->make_immutable;


