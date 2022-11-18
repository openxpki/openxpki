package TestNotificationDummyHandler;

use Moose;
extends 'OpenXPKI::Server::Notification::Base';

use English;

use DateTime;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;

our $RESULT;

sub notify {
    my ($self, $args) = @_;

    my $msg  = $args->{MESSAGE};
    my $vars = $args->{VARS};

    my $rendered = $self->_render_template_file($msg, $vars);
    $RESULT = $rendered;
}

__PACKAGE__->meta->make_immutable;
