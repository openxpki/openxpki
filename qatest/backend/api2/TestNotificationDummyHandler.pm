package TestNotificationDummyHandler;
use OpenXPKI -class;

extends 'OpenXPKI::Server::Notification::Base';

use DateTime;
use OpenXPKI::Server::Context qw( CTX );

our $RESULT;

sub notify {
    my ($self, $args) = @_;

    my $msg  = $args->{MESSAGE};
    my $vars = $args->{VARS};

    my $rendered = $self->_render_template_file($msg, $vars);
    $RESULT = $rendered;
}

__PACKAGE__->meta->make_immutable;
