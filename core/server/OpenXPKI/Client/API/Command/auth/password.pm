package OpenXPKI::Client::API::Command::auth::password;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
;

use OpenXPKI::Password;

=head1 NAME

OpenXPKI::Client::API::Command::auth::password

=head1 DESCRIPTION

Create the (salted) hash of a password to be used with the internal user
database.

The password is read interactively, add C<stdin> to read the password from
stdin without confirmation.

Returns the hashed value including the used scheme as defined in RFC2307
(Argon2 uses its native encoding).

For C<argon2> you can pass computation paramters as extra arguments C<salt>,
C<saltbytes>, C<time>, C<memory>, C<p>, C<tag>

See L<OpenXPKI::Password> for the list of schemes and argon2 parameters.

=cut

command "password" => {
    scheme => { isa => 'Str', label => 'Hash scheme (sshaXXX|shaXXX|crypt|argon2)', default => 'ssha256' },
    stdin =>  { isa => 'Bool', label => 'Read password from stdin instead of prompting' },
} => sub ($self, $param) {

    my $scheme = $param->scheme;
    die "Unsupported scheme '$scheme', see 'perldoc OpenXPKI::Password'\n"
        unless OpenXPKI::Password::has_scheme($scheme);

    my $password;
    if ($param->stdin) {
        $password = <STDIN>;
        die "No password received on stdin\n" unless defined $password;
        chomp $password;
    } else {
        $password = main::read_password('Please enter the password to hash:');
        die "No password entered\n" unless $password;
        chomp $password;
        my $retype = main::read_password('Please re-type the password:');
        chomp $retype;
        die "The passwords do not match\n" unless ($retype eq $password);
    }

    die "The password must not be empty\n" unless length $password;

    my $params;
    if ($scheme eq 'argon2') {
        my $payload = $self->build_hash_from_payload($param, 1);
        for my $key (qw(salt saltbytes time memory p tag)) {
            $params->{$key} = $payload->{$key} if (defined $payload->{$key});
        }
    }

    my $hash = OpenXPKI::Password::hash($scheme, $password, $params);
    die "Unable to compute hash\n" unless $hash;

    return $hash;
};

__PACKAGE__->meta->make_immutable;
