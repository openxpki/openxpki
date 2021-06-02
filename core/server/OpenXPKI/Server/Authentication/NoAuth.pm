package OpenXPKI::Server::Authentication::NoAuth;

use strict;
use warnings;

use Moose;
use OpenXPKI::Debug;
use OpenXPKI::Password;
use OpenXPKI::Server::Authentication::Handle;
use OpenXPKI::Server::Context qw( CTX );

extends 'OpenXPKI::Server::Authentication::Base';


sub parseRole {

    my $self  = shift;
    my $msg   = shift;

    if ($self->has_role()) {
        return $self->role();
    }

    return $self->map_role($msg->{role});

}


sub handleInput {

    ##! 1: 'start'
    my $self  = shift;
    my $msg   = shift;

    ##! 2: 'login data received'
    ##! 64: $msg
    my $username = $msg->{username};

    return unless($username);

    my $role = $self->parseRole($msg);

    return OpenXPKI::Server::Authentication::Handle->new(
        username => $username,
        error => OpenXPKI::Server::Authentication::Handle::NOT_AUTHORIZED,
    ) unless($role);

    my %userinfo = %{$msg};
    delete $userinfo{username};
    delete $userinfo{role};

    return OpenXPKI::Server::Authentication::Handle->new(
        username => $username,
        userid => $self->get_userid( $username ),
        role => $role,
        userinfo => \%userinfo,
        authinfo => {
            uid => $username,
            %{$self->authinfo()},
        },
    );
}

1;

__END__

=head1 OpenXPKI::Server::Authentication::NoAuth

This handler does not perform any authentication, it relies on an
external party to pass in authenticated information.

Handler returns undef unless the I<username> attribute is a true
value. If you provide the I<role> attribute as parameter to the handler,
it will be assigned to any incoming username. Otherwise the key I<role>
from the incoming message is used. In case I<rolemap> is set, the role
given role name will be translated using the map.

Any additional parameters set in the incoming hash will be set as
I<userinfo>.

The I<authinfo> section can be set as parameter to the handler (HashRef),
the key I<uid> is always populated with the I<username>.


=head2 Login Parameters

Expects the username given as I<username>.

=head2 Postprocess role

If you need to postprocess the role information, inherit from this class
and provide a I<parseRole> method that receives the incoming message as
key/value list and returns the name of the role as string.

