package OpenXPKI::Client::API::Command::auth::verify;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
;

use OpenXPKI::Password;

=head1 NAME

OpenXPKI::Client::API::Command::auth::verify

=head1 DESCRIPTION

Verify a password against a given digest.

The digest is passed as an argument, the scheme is auto-detected from the
digest (RFC2307 prefix, native crypt or Argon2 encoding). The password is
read interactively (input is hidden) or, with C<stdin>, as a single line
from stdin.

The command dies with a non-zero exit code if the password does not match,
otherwise it returns a confirmation message.

B<Note> When used interactively you need to add quotes around any digest that
contains dollar signs to prevent the shell from expanding it.

=cut

command "verify" => {
    digest => { isa => 'Str', label => 'The password digest to verify against', required => 1 },
    stdin =>  { isa => 'Bool', label => 'Read password from stdin instead of prompting' },
} => sub ($self, $param) {

    my $password;
    if ($param->stdin) {
        $password = <STDIN>;
        die "No password received on stdin\n" unless defined $password;
        chomp $password;
    } else {
        $password = main::read_password('Please enter the password to verify:');
        die "No password entered\n" unless $password;
        chomp $password;
    }

    my $result = OpenXPKI::Password::check($password, $param->digest);
    die "Password does NOT match the given digest\n" unless $result;

    return 'Password matches the given digest';
};

__PACKAGE__->meta->make_immutable;
