package OpenXPKI::Server::Workflow::Activity::User::HashUserPassword;
use OpenXPKI;

use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Serialization::Simple;

use OpenXPKI::Password;

sub execute {
    # taken from hash_password() in bin/openxpkiadm
    my ($self, $workflow) = @_;
    my $context  = $workflow->context();
    my $passwd = $self->param('password');
    my $scheme = $self->param('scheme') || 'argon2';

    my $target_key =  $self->param('target_key') || '_password';

    my $hashed = OpenXPKI::Password::hash($scheme,$passwd);

    workflow_error('Unable to create hashed password') unless($hashed);

    $context->param( $target_key => $hashed );

    return 1;
}



1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::User::HashUserPassword

=head1 Description

Hashes a user password for e.g. storing in a user database

You can specify either the length of the generated string setting
I<length> or provide the number of random bytes with I<bytes>. You
must not set both.

You can set the charset that will be used for the password with
I<charset>.

The default are 16 characters in base64 encoding which is equal to
an entropy of 12 byte.

You can set the context key to write the password to using I<target_key>,
the default is I<_password>.

=head2 Parameters

=over

=item password

The password to be hashed

=item scheme

The scheme used for hashing the password, check OpenXPKI::Password for
supported schemes. Default is argon2.

=item target_key

Receives the password hash

=back
