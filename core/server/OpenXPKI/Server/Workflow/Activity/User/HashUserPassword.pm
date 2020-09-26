package OpenXPKI::Server::Workflow::Activity::User::HashUserPassword;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use IO::Prompt;
use Digest::SHA;
use Digest::MD5;
use Proc::SafeExec;
use MIME::Base64;
use Crypt::Argon2;
use Data::Dumper;

sub execute {
    # taken from hash_password() in bin/openxpkiadm
    my ($self, $workflow) = @_;
    my $context  = $workflow->context();
    my $passwd=$self->param('password');
    my $prefix = sprintf '{%s}', $self->param('scheme');
    my $computed_secret;
    if ($self->param('scheme') eq 'sha') {
        my $ctx = Digest::SHA->new();
        $ctx->add($passwd);
        $computed_secret = $ctx->b64digest();

    } elsif ($self->param('scheme') eq 'md5') {
        my $ctx = Digest::MD5->new();
        $ctx->add($passwd);
        $computed_secret = $ctx->b64digest();

    } elsif ($self->param('scheme') eq 'ssha') {
        my $ctx = Digest::SHA->new();
        my $salt = __create_salt(3);
        $ctx->add($passwd);
        $ctx->add($salt);
        $computed_secret = encode_base64( $ctx->digest() . $salt, '');

    } elsif ($self->param('scheme') eq 'smd5') {
        my $ctx = Digest::MD5->new();
        my $salt = __create_salt(3);
        $ctx->add($passwd);
        $ctx->add($salt);
        $computed_secret = encode_base64($ctx->digest() . $salt, '');

    } elsif ($self->param('scheme') eq 'crypt') {
        $computed_secret = crypt($passwd, __create_salt(3));

    } elsif ($self->param('scheme') eq 'argon2') {
        $computed_secret = Crypt::Argon2::argon2id_pass($passwd, __create_salt(16), 3, '32M', 1, 16);
        $prefix = '';
    }


    $context->param( $self->param('target_key') => $prefix . $computed_secret);

    return 1;
}

sub __create_salt {
    # taken from bin/openxpkiadm
    my $bytes = shift;
    my @exec = ('openssl', 'rand', '-base64', $bytes);
    my ($salt, undef) = Proc::SafeExec::backtick(@exec);
    chomp $salt;
    return $salt;
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

The scheme used for hashing the password, available are: sha, md5, ssha, smd5, crypt, argon2

=item target_key

Receives the password hash

=back
