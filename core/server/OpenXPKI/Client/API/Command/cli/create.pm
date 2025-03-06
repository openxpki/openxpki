package OpenXPKI::Client::API::Command::cli::create;
use OpenXPKI -client_plugin;

use Crypt::PK::ECC;

command_setup
    parent_namespace_role => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::cli::create

=head1 DESCRIPTION

Generate a new key pair to use it as authentication key for this client.

The command will provide the public and private key as PEM encoded blocks.
Put the B<private> key into a file, ensure proper permissions on it to
manage access. Reference the key file usig I<--auth-key> when using this
tool or place the key to a file named I<~/.oxi/client.key> where it gets
automatically loaded.

Add the public key to the system configuration at I<system.cli.auth>.

=cut

command "create" => {
} => sub ($self, $param) {

    #Key generation
    my $pk = Crypt::PK::ECC->new();
    $pk->generate_key('secp256r1');
    return {
        private => $pk->export_key_pem('private','secret'),
        public  => $pk->export_key_pem('public'),
        id => $pk->export_key_jwk_thumbprint('SHA256'),
    };

};

__PACKAGE__->meta->make_immutable;


