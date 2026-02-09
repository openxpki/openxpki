package OpenXPKI::Client::API::Command::cli::create;
use OpenXPKI -client_plugin;

use Crypt::PK::ECC;

command_setup
    parent_namespace_role => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::cli::create

=head1 DESCRIPTION

Generate a new ECC (secp256r1) key pair for CLI client authentication.

Returns the private key, public key (both PEM-encoded) and the JWK
thumbprint as key identifier. The private key can optionally be
encrypted with a password.

Store the B<private> key in a file with restricted permissions and
reference it via C<--auth-key>, or place it at F<~/.oxi/client.key>
for automatic loading.

Add the B<public> key to the server configuration at C<system.cli.auth>.

=cut

command "create" => {
    nopass => { isa => 'Bool', label => 'Generate key without password encryption' },
    stdin =>  { isa => 'Bool', label => 'Read encryption password from stdin instead of prompting' },
    keyout => { isa => 'Bool', label => 'Output only the private key PEM block' },
} => sub ($self, $param) {

    my $pass;

    if ($param->stdin) {
        $pass = <STDIN>;
        chomp $pass;
        die "no password was found on stdin\n" unless($pass);
    } elsif ($param->nopass) {
        $self->log->warn('generating key without password');
    } else {
        $pass = main::read_password("Please enter password to encrypt the key (empty to skip):");
        if ($pass) {
            chomp $pass;
            my $retype = main::read_password("Please retype password:");
            chomp $retype;
            die "Given passwords do not match\n" unless ($retype eq $pass);
        }
    }

    #Key generation
    my $pk = Crypt::PK::ECC->new();
    $pk->generate_key('secp256r1');

    # return private key only
    return $pk->export_key_pem('private', $pass)
        if ($param->keyout);

    # return structure
    return {
        private => $pk->export_key_pem('private', $pass),
        public  => $pk->export_key_pem('public'),
        id => $pk->export_key_jwk_thumbprint('SHA256'),
    };

};

__PACKAGE__->meta->make_immutable;


