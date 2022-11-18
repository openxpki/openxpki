package OpenXPKI::Server::Authentication::Handle;

use Moose;

use Moose::Util::TypeConstraints;
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );

## constructor and destructor stuff

use constant {
    VALID => 0, # should never be set
    USER_UNKNOWN => 1,
    LOGIN_FAILED => 2,
    USER_LOCKED => 4,
    NOT_AUTHORIZED => 8,
    SERVICE_UNAVAILABLE  => 64,
    UNKNOWN_ERROR => 128,
};

has messages => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    default => sub { return {
        1   => 'I18N_OPENXPKI_UI_LOGIN_USER_UNKNOWN',
        2   => 'I18N_OPENXPKI_UI_LOGIN_FAILED',
        4   => 'I18N_OPENXPKI_UI_LOGIN_USER_LOCKED',
        8   => 'I18N_OPENXPKI_UI_LOGIN_USER_NOT_AUTHORIZED',
        64  => 'I18N_OPENXPKI_UI_LOGIN_SERVICE_UNAVAILABLE',
        128 =>'I18N_OPENXPKI_UI_LOGIN_UNKNOWN_ERROR'
    }; }
);

has error => (
    is => 'rw',
    isa => 'Int',
    predicate => 'has_error',
    clearer => 'clear_error',
    default => VALID,
);

has __error_message => (
    is => 'rw',
    isa => 'Str',
    predicate => 'has_error_message',
    clearer => 'clear_error_message',
    init_arg  => 'error_message',
);

has username => (
    is => 'rw',
    isa => 'Str',
);

has userid => (
    is => 'rw',
    isa => 'Str',
);

has role => (
    is => 'rw',
    isa => 'Str',
);

subtype 'TenantList' => as 'ArrayRef[Str]';
coerce 'TenantList' => from 'Str', via { [ $_ ] };

has tenants => (
    is => 'rw',
    isa => 'TenantList',
    coerce => 1,
    predicate => 'has_tenants',
);

has userinfo => (
    is => 'rw',
    isa => 'HashRef|Undef',
);

has handler => (
    is => 'rw',
    isa => 'Str',
);

has authinfo => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { return {}; }
);

sub error_message {

    my $self = shift;
    return '' unless ($self->has_error());

    return $self->__error_message() if ($self->has_error_message());

    return $self->messages()->{$self->error()} || 'I18N_OPENXPKI_UI_LOGIN_UNKNOWN_ERROR';

}


sub is_valid {

    my $self = shift;

    # error is set to a non-zero value
    if ($self->has_error() && $self->error()) {
        return;
    }

    # check if username, userid and role is set
    return unless($self->username());
    return unless($self->userid());
    return unless($self->role());

    return 1;

}

__PACKAGE__->meta->make_immutable;

__END__;

=head1 OpenXPKI::Server::Authentication::Handle

A stub class that encapsulates the result of a user authentication
attempt.

On success, the object will hold the information that was assigned to
the user by the authentication layer. This is at minimum a user id and
a role. Any additional information can be found as key/value items in
the userinfo section.

On error, you will find a verbose error message and an error code depending
on the reason for the authentication failure.