package OpenXPKI::Server::Authentication::Handle;

use strict;
use warnings;

use Moose;
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

has error => (
    is => 'rw',
    isa => 'Int',
    predicate => 'has_error',
    clearer => 'clear_error',
    default => VALID,
    trigger => sub {
        my $self = shift;
        $self->clear_error_message();
    }
);

has error_message => (
    is => 'rw',
    isa => 'Str',
    builder => '__get_error_message',
    clearer => 'clear_error_message',
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


sub __get_error_message {

    my $self = shift;
    return '' unless ($self->has_error());

    my $msg = {
        VALID => '',
        USER_UNKNOWN => 'I18N_OPENXPKI_UI_LOGIN_USER_UNKNOWN',
        LOGIN_FAILED => 'I18N_OPENXPKI_UI_LOGIN_FAILED',
        USER_LOCKED => 'I18N_OPENXPKI_UI_LOGIN_USER_LOCKED',
        NOT_AUTHORIZED => 'I18N_OPENXPKI_UI_LOGIN_USER_NOT_AUTHORIZED',
        SERVICE_UNAVAILABLE  => 'I18N_OPENXPKI_UI_LOGIN_SERVICE_UNAVAILABLE',
        UNKNOWN_ERROR => 'I18N_OPENXPKI_UI_LOGIN_UNKNOWN_ERROR',
    };

    return $msg->{$self->error()} || 'I18N_OPENXPKI_UI_LOGIN_UNKNOWN_ERROR';

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

}

1;

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