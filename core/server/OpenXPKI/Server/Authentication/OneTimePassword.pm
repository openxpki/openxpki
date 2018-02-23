package OpenXPKI::Server::Authentication::OneTimePassword;

use strict;
use warnings;

use Moose;
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use Digest::SHA;
use MIME::Base64;

has label => (
    is => 'ro',
    isa => 'Str',
    default => 'One-Time-Password',
);

has description => (
    is => 'ro',
    isa => 'Str',
    default => 'Login using a One-Time-Password',
);

has namespace => (
    is => 'ro',
    isa => 'Str',
    default => 'sys.auth.otp',
);

has permanent => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

has salt => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has role => (
    is => 'ro',
    isa => 'Str',
    default => '',
);

around BUILDARGS => sub {

    my $orig  = shift;
    my $class = shift;

    my @path = split /\./, ;

    my $config = CTX('config')->get_hash($_[0]);

    return $class->$orig( $config );

};

sub login_step {

    ##! 1: 'start'
    my $self    = shift;
    my $arg_ref = shift;

    my $name    = $arg_ref->{HANDLER};
    my $msg     = $arg_ref->{MESSAGE};

    if (! exists $msg->{PARAMS}->{LOGIN} ) {
        ##! 4: 'no login data received (yet)'
        return (undef, undef, {
            SERVICE_MSG => "GET_PASSWD_LOGIN",
            PARAMS      => {
                NAME        => $self->label(),
                DESCRIPTION => $self->description(),
            },
        });
    }

    my $token = $msg->{PARAMS}->{LOGIN};

    my $ctx = Digest::SHA->new();
    $ctx->add($token);
    $ctx->add($self->salt());
    my $hashed_key = $ctx->hexdigest;

    CTX('log')->auth()->debug('OTP login - hashed token - ' . $hashed_key );

    my $val = CTX('api')->get_data_pool_entry({
        NAMESPACE => $self->namespace(),
        KEY => $hashed_key,
    });

    if (!$val->{VALUE}) {
        OpenXPKI::Exception->throw (
            message => "OTP Login failed - token not found",
        );
    }

    if ($val->{EXPIRATION_DATE} && $val->{EXPIRATION_DATE} < time()) {
        OpenXPKI::Exception->throw (
            message => "OTP Login failed - token expired",
        );
    }

    my $data = OpenXPKI::Serialization::Simple->new()->deserialize($val->{VALUE});
    if (!$data->{user}) {
        OpenXPKI::Exception->throw (
            message => "OTP Login failed - no username set",
        );
    }

    my $role = $self->role() || $data->{role};
    if (!$role) {
        OpenXPKI::Exception->throw (
            message => "OTP Login failed - no role set",
        );
    }

    # do not expire on first use
    if (!$self->permanent()) {
        CTX('api')->set_data_pool_entry({
            NAMESPACE => $self->namespace(),
            KEY => $hashed_key,
            VALUE => '',
        });
    }

    return ( $data->{user}, $role, {
        SERVICE_MSG => 'SERVICE_READY',
    });
}

1;

__END__

=head1 Name

OpenXPKI::Server::Authentication::OneTimePassword

=head1 Description

Provides an authentication handler for One Time Passwords based on
datapool items. The handler expects the token as username.

=head1 Functions

=head2 new

is the constructor. It requires the config prefix as single argument.

=head1 Configuration

=head2 Parameters

=over

=item type

Name of the authenticaton class, must be OneTimePassword

=item salt

To hide the plain tokens from database admins, the datapool key is the
salted and hashed token. This defines the used salt and is the only
mandatory parameter for the handler.

=item role, optional

Set a fixed role for this login handler, if not set the role must be
passed in the datapool item.

=item namespace, optional

The string used as namespace to lookup the datapool items, the default
is I<sys.auth.otp>.

=item permanent, optional

If set to a true value, the OTP is not purged after the login was
successful.

=back

=head2 Datapool Item

Realm and token expiration is controlled via the properties of the
datapool item, the user, role and token type are read from the value
held in the datapool. The value must be a (serialized) hash.

=over

=item user

The username to use

=item role

The role to set, only effective if the handler has not set a role.

=back


