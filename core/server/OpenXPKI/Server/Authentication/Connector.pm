package OpenXPKI::Server::Authentication::Connector;

use strict;
use warnings;

use OpenXPKI::Debug;
use OpenXPKI::Server::Authentication::Handle;
use OpenXPKI::Server::Context qw( CTX );

use Moose;

extends 'OpenXPKI::Server::Authentication::Base';

has '+role' => (
    required => 1,
);

sub handleInput {

    ##! 1: 'start'
    my $self  = shift;
    my $msg   = shift;


    ##! 2: 'login data received'
    my $username = $msg->{LOGIN} // $msg->{username};
    my $passwd  = $msg->{PASSWD} // $msg->{password};

    return unless ($username && defined $passwd);

    # check account - password checking is done using an authentication
    # connector with password binding.

    my $result = CTX('config')->get( [ @{$self->prefix()}, 'source', $username ], { password =>  $passwd } );

    # as we use a bind connect, we dont know the exact reason
    return OpenXPKI::Server::Authentication::Handle->new(
        username => $username,
        error => OpenXPKI::Server::Authentication::Handle::LOGIN_FAILED,
    ) unless ($result);

    # this usually means a wrong connector definition
    return OpenXPKI::Server::Authentication::Handle->new(
        username => $username,
        error => OpenXPKI::Server::Authentication::Handle::UNKNOWN_ERROR,
        error_message => 'Password connector did not return a scalar'
    ) if (defined $result && ref $result ne '');

    # fetch userinfo from handler- will be undef if not set
    my $userinfo = $self->get_userinfo($username);

    return OpenXPKI::Server::Authentication::Handle->new(
        username => $username,
        userid => $username,
        role => $self->role(),
        userinfo => $userinfo || {},
    );

}


1;

__END__

=head1 OpenXPKI::Server::Authentication::Connector

Passphrase based authentication using connector backend.

Alternative to OpenXPKI::Server::Authentication::Password which checks the
password aganist a connector backend using the password as bind parameter.

=head2 Configuration

Requires I<role> to be set, will use the incoming username to query the
connector at I<$prefix.source.$username>, sendind the password as "bind"
password in the data section. Suited connectors are e.g.
Connector::Builtin::Authentication::*

    User Password:
        type: Connector
        role: User
        source@: connector:auth.connector.localuser
        user@: connector:auth.connector.userinfo

If the user parameter is set, the username is used to fetch the
I<userinfo> hash.

Returns an instance of OpenXPKI::Server::Authentication::Handle
or undef if not login parameters are given