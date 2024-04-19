package OpenXPKI::Server::Authentication::OneTimePassword;

use Moose;
extends 'OpenXPKI::Server::Authentication::Base';

use OpenXPKI::Debug;
use OpenXPKI::Server::Authentication::Handle;
use OpenXPKI::Server::Context qw( CTX );

use Data::Dumper;
use Digest::SHA;
use MIME::Base64;


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

sub handleInput {

    ##! 1: 'start'
    my $self  = shift;
    my $msg   = shift;


    ##! 2: 'login data received'
    my $token = $msg->{LOGIN} // $msg->{token};

    return unless ($token);

    my $ctx = Digest::SHA->new();
    $ctx->add($token);
    $ctx->add($self->salt());
    my $hashed_key = $ctx->hexdigest;

    $self->log->debug("OTP login - plain token: $token - hashed token/dp key: $hashed_key");

    my $val = CTX('api2')->get_data_pool_entry(
        namespace => $self->namespace(),
        key => $hashed_key,
        deserialize => 'simple',
    );
    my $data = $val->{value};

    return OpenXPKI::Server::Authentication::Handle->new(
        username => $token,
        error => OpenXPKI::Server::Authentication::Handle::USER_UNKNOWN
    ) unless $data;

    $self->log->trace('Got OTP token ' . Dumper $val ) if ($self->log->is_trace);

    return OpenXPKI::Server::Authentication::Handle->new(
        username => $token,
        error => OpenXPKI::Server::Authentication::Handle::USER_LOCKED
    ) if ($val->{expiration_date} && $val->{expiration_date} < time());

    return OpenXPKI::Server::Authentication::Handle->new(
        username => $token,
        error => OpenXPKI::Server::Authentication::Handle::LOGIN_FAILED
    ) if (!$data->{user});

    my $role = $self->role() || $data->{role};
    return OpenXPKI::Server::Authentication::Handle->new(
        username => $token,
        userid => $data->{user},
        error => OpenXPKI::Server::Authentication::Handle::NOT_AUTHORIZED
    ) if (!$role);

    if (!$self->permanent()) {
        CTX('api2')->delete_data_pool_entry(
            namespace => $self->namespace(),
            key => $hashed_key,
        );
    }

    my $userid = $self->get_userid( $data->{user} );
    delete $data->{user};
    return OpenXPKI::Server::Authentication::Handle->new(
        username => $token,
        userid => $userid,
        role => $role,
        userinfo => $data || {},
    );

}

__PACKAGE__->meta->make_immutable;

__END__

=head1 Name

OpenXPKI::Server::Authentication::OneTimePassword

=head1 Description

Provides an authentication handler for One Time Passwords based on
datapool items.

=head2 Login Parameters

The handler expects the token with key I<token>.

=head2 Configuration Parameters

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

=item ...

The remaining hash is set as userinfo.

=back

=head2 Example Configuration

Create a stack with type I<password> and a single input field.

  stack:
    OTP:
      label: OneTimePassword
      handler: OneTimePassword
      type: passwd
      param:
        label: I18N_OPENXPKI_UI_OTP_LOGIN_LABEL
        description: I18N_OPENXPKI_UI_OTP_LOGIN_DESC
        button: I18N_OPENXPKI_UI_OTP_LOGIN_BUTTON
        field:
            - name: token
            label: I18N_OPENXPKI_UI_LOGIN_TOKEN
            type: password

  handler:
    OneTimePassword:
      type: OneTimePassword
      salt: openxpki
      role: User
