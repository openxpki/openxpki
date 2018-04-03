package TestNotificationDummyHandler;

use strict;
use warnings;
use English;

use Data::Dumper;

use DateTime;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;

use Moose;

extends 'OpenXPKI::Server::Notification::Base';

our $RESULT;

sub notify {
    my ($self, $args) = @_;

    my $msg  = $args->{MESSAGE};
    my $vars = $args->{VARS};

    my $rendered = $self->_render_template_file($msg, $vars);
    $RESULT = $rendered;
}

1;
