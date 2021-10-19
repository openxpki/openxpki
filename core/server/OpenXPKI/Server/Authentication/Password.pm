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

has mode => (
    is => 'ro',
    isa => 'Str',
    default => 'digest'
);

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
    my $mode = $self->mode();
    my $digest;

    # check account - the handler config has a connector at .user
    # that returns password or password and role for a requested username
    my $userinfo;
    my $tenant;
    eval {

        if ($mode eq 'hash' || !$role) {
            $userinfo = CTX('config')->get_hash( [ @{$self->prefix()}, 'user', $username ] );
            ##! 64: $userinfo
            $self->logger->trace("Got userinfo for #$username#: " . Dumper $userinfo) if ($self->logger->is_trace);
            $digest = $userinfo->{digest} || '';
            delete $userinfo->{digest};
            # use role only if no static role is set
            if (!$role) {
                $role = $userinfo->{role};
            }
            delete $userinfo->{role};
            $tenant = $userinfo->{tenant};
            delete $userinfo->{tenant};
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
        tenant => $tenant,
        userinfo => $userinfo || {},
    );

}

1;

__END__


=head1 OpenXPKI::Server::Authentication::Password

Passphrase based authentication against a given user database. The users
must be provided as a key/value list where the key is equal to the
username that is passed to the handler.
The value depends on the chosen mode of operation:

=over

=item static role, no user information

I<mode> must be I<digest> (default) and I<role> must be set. The value
must be a scalar that represents the hashed password in a format that
is understod by C<OpenXPKI::Password::check>. If the password matches,
the user is logged in with the given static role. I<userinfo> remains
empty.

=item static role, with user information

I<mode> must be I<hash> (default) and I<role> must be set. The user
source must at least return a hash with the key I<digest> holding the
password. The user is logged in with the given role, I<tenant> is set
if present, all other keys, except for I<role> which is deleted unused,
are returned as I<userinfo>.

=item dynamic role with optional information

I<role> must be empty, same as above but the role is read from the key
I<role> from the result. If the result does not have a non-empty value
the login fails.

=back

=head2 Login Parameters

Expects the credentials given as I<username> and I<password>.
