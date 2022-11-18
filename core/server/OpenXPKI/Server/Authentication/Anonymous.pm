package OpenXPKI::Server::Authentication::Anonymous;

use Moose;
extends 'OpenXPKI::Server::Authentication::Base';

use OpenXPKI::Debug;
use OpenXPKI::Server::Authentication::Handle;

has user => (
    is => 'ro',
    isa => 'Str',
    default => 'Anonymous',
);

has name => (
    is => 'ro',
    isa => 'Str',
    default => 'I18N_OPENXPKI_UI_USER_ANONYMOUS',
);

has email => (
    is => 'ro',
    isa => 'Str',
    default => '',
);

has '+role' => (
    default => 'Anonymous',
);


sub handleInput {

    ##! 1: 'start'
    my $self  = shift;
    my $msg   = shift;

    $self->logger->debug('Incoming auth using Anonymous handler');

    my %email = $self->email() ? ( email => $self->email() ) : ();
    return OpenXPKI::Server::Authentication::Handle->new(
        username => $self->user(),
        userid => $self->get_userid( $self->user() ),
        role => $self->role(),
        userinfo => {
            realname => $self->name(),
            %email
        },
    );
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 OpenXPKI::Server::Authentication::Anonymous

This is the class which supports OpenXPKI with an anonymous authentication
method. Incoming parameters are ignored, the authentication handle will
always contain the literal values set as parameters to the handler.

=head2 Parameters

=over

=item user

Value for username and userid, defaults to 'Anonymous'.

=item role

The role, default is 'Anonymous'.

=item name

The literal name of the the user, defaults to the translatable string
I18N_OPENXPKI_UI_USER_ANONYMOUS.

=item email

The email address assigned to the user. Default is empty.

=back