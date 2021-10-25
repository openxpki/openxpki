package OpenXPKI::Server::Authentication::Connector;

use strict;
use warnings;
use English;

use OpenXPKI::Debug;
use OpenXPKI::Server::Authentication::Handle;
use OpenXPKI::Server::Context qw( CTX );

use Moose;

extends 'OpenXPKI::Server::Authentication::Base';

has '+role' => (
    required => 1,
);

has mode => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    matching => qr{ \A(authonly|combined|userinfo|)\z }xms,
    default => sub {
        my $self = shift;
        return 'authonly'
            unless(CTX('config')->exists( [ @{$self->prefix()}, 'user' ]));

        return 'combined'
            unless(CTX('config')->exists( [ @{$self->prefix()}, 'source' ]));

        return 'userinfo';
    },
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

    my $userinfo;
    my $result;
    eval {
        my $mode = $self->mode();
        $self->logger->debug("Query username $username with mode $mode");
        # combined mode, make a "bind" query with get_hash
        # using a non-empty response as userinfo
        if ($mode eq 'combined') {
            $userinfo = CTX('config')->get_hash( [ @{$self->prefix()}, 'user', $username ], { password =>  $passwd } );
            $result = $userinfo if (keys %{$userinfo});
        } else {
            $result = CTX('config')->get( [ @{$self->prefix()}, 'source', $username ], { password =>  $passwd } );

            # fetch userinfo from handler if login was ok and mode is userinfo
            $userinfo = $self->get_userinfo($username) if ($result && $mode eq 'userinfo');
        }
    };

    # connector died, return service unavailable message
    return OpenXPKI::Server::Authentication::Handle->new(
        username => $username,
        error => OpenXPKI::Server::Authentication::Handle::SERVICE_UNAVAILABLE,
        error_message => "$EVAL_ERROR"
    ) if ($EVAL_ERROR);

    # none or false result -> login failed, details are unknown
    return OpenXPKI::Server::Authentication::Handle->new(
        username => $username,
        error => OpenXPKI::Server::Authentication::Handle::LOGIN_FAILED,
    ) unless ($result);

    # all good - login the user
    # check for tenant
    $userinfo //= {};
    my $tenants = $userinfo->{tenant}; # Str or ArrayRef
    delete $userinfo->{tenant};

    return OpenXPKI::Server::Authentication::Handle->new(
        username => $username,
        userid => $self->get_userid( $username ),
        role => $self->role(),
        userinfo => $userinfo || {},
        tenants => $tenants || [],
    );

}


1;

__END__

=head1 OpenXPKI::Server::Authentication::Connector

Passphrase based authentication using connector backend.

Alternative to OpenXPKI::Server::Authentication::Password which checks the
password aganist a connector backend using the password as bind parameter.

Returns an instance of OpenXPKI::Server::Authentication::Handle
or undef if not login parameters are given.

=head2 Configuration

=head3 Authentication Only

Requires I<role> to be set, will use the incoming username to query the
connector at I<$prefix.source.$username>, sending the password as "bind"
password in the data section. Suited connectors are e.g.
Connector::Builtin::Authentication::*

    User Password:
        type: Connector
        role: User
        source@: connector:auth.connector.localuser

=head3 Authentication plus dedicated userinfo

If you add a node I<user> to the configuration, the class will first
perform the authentication and, if successful, run a second query to
I<$prefix.user.$username>. The query is done B<without> the password
and expects a hash to be returned. The hash will be returned in the
I<userinfo> attribute.

    User Password:
        type: Connector
        role: User
        source@: connector:auth.connector.localuser
        user@: connector:auth.connector.userinfo

=head3 Combined mode

If B<only> the I<user> node exists, only a single query B<including>
the password is done on I<$prefix.user.$username>. The login is
successful, if a non-empty hash is returned. The unfiltered hash is
set as I<userinfo>.
