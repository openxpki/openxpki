package OpenXPKI::Client::API::Command::config::smtptest;

use Moose;
extends 'OpenXPKI::Client::API::Command::config';
with 'OpenXPKI::Client::API::Command::NeedRealm';

use MooseX::ClassAttribute;

use OpenXPKI::Client::API::Response;
use OpenXPKI::DTO::Field;
use OpenXPKI::DTO::Field::String;

=head1 NAME

OpenXPKI::Client::API::Command::config::smtptest;

=head1 SYNOPSIS

Send a test message for the selected realm to validate SMTP is working.

This test requires that you have not modified or removed the default
test message from the configuration!

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::String->new( name => 'mailto', label => 'The email address to send the mail to', required => 1 ),
        OpenXPKI::DTO::Field::String->new( name => 'message', label => 'The message template to send', value => 'testmail' ),
    ]},
);

sub execute {

    my $self = shift;
    my $req = shift;

    my $res = $self->api->run_command('send_notification', {
        message => $req->param('message'),
        params => { notify_to => $req->param('mailto') },
    });
    return OpenXPKI::Client::API::Response->new( payload => $res );
}

__PACKAGE__->meta()->make_immutable();

1;


