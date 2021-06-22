package OpenXPKI::Server::Authentication::Password;

use strict;
use warnings;
use English;

use Moose;
use Data::Dumper;
use OpenXPKI::Debug;
use OpenXPKI::Password;
use OpenXPKI::Server::Authentication::Handle;
use OpenXPKI::Server::Context qw( CTX );

extends 'OpenXPKI::Server::Authentication::Base';

sub handleInput {

    ##! 1: 'start'
    my $self  = shift;
    my $msg   = shift;

    ##! 64: $msg
    my $username = $msg->{LOGIN} // $msg->{username};
    my $passwd  = $msg->{PASSWD} // $msg->{password};

    return unless ($username && defined $passwd);
    ##! 2: 'login data received'
    ##! 16: "Got username $username"

    my $role = $self->role() || '';
    my $digest;

    # check account - the handler config has a connector at .user
    # that returns password or password and role for a requested username
    my $userinfo;
    eval {
        if (!$role) {
            $userinfo = CTX('config')->get_hash( [ @{$self->prefix()}, 'user', $username ] );
            ##! 64: $userinfo
            $self->logger->trace("Got userinfo for #$username#: " . Dumper $userinfo) if ($self->logger->is_trace);
            $digest = $userinfo->{digest} || '';
            delete $userinfo->{digest};
            $role = $userinfo->{role} || '';
            delete $userinfo->{role};
        } else {
            $digest = CTX('config')->get( [ @{$self->prefix()}, 'user', $username ] );
            ##! 64: $digest
        }
    };
    return OpenXPKI::Server::Authentication::Handle->new(
        username => $username,
        error => OpenXPKI::Server::Authentication::Handle::SERVICE_UNAVAILABLE,
        error_message => "$EVAL_ERROR"
    ) if ($EVAL_ERROR);

    return OpenXPKI::Server::Authentication::Handle->new(
        error => OpenXPKI::Server::Authentication::Handle::USER_UNKNOWN,
    ) unless($digest);

    return OpenXPKI::Server::Authentication::Handle->new(
        username => $username,
        error => OpenXPKI::Server::Authentication::Handle::NOT_AUTHORIZED,
    ) unless($role);

    return OpenXPKI::Server::Authentication::Handle->new(
        username => $username,
        error => OpenXPKI::Server::Authentication::Handle::LOGIN_FAILED,
    ) unless(OpenXPKI::Password::check($passwd,$digest));

    ##! 4: 'succeeded'

    return OpenXPKI::Server::Authentication::Handle->new(
        username => $username,
        userid => $self->get_userid( $username ),
        role => $role,
        userinfo => $userinfo || {},
    );
}

1;

__END__


=head1 OpenXPKI::Server::Authentication::Password

Passphrase based authentication against a given user database. The users
must be provided as a key/value list where the key is equal to the
username that is passed to the handler.

If you have set a static default role via the I<role> parameter, the user
source must return a scalar that contains the hashed password in a format
that is understod by C<OpenXPKI::Password::check>.

If no role is set, the source must return a key value list with the keys
I<role> and I<digest>. Additional parameters are set as I<userinfo>.

SCHEME is one of sha (SHA1), md5 (MD5), crypt (Unix crypt), smd5 (salted
MD5) or ssha (salted SHA1).

If you add the I<role> parameter to the config, the configuration must return
a scalar value for each username representing the digest.

=head2 Login Parameters

Expects the credentials given as I<username> and I<password>.
