package OpenXPKI::Client::API::Command::config::smtptest;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::config::smtptest

=head1 DESCRIPTION

Send a test notification email to verify SMTP configuration.

Uses the notification framework of the selected realm to send a test
message. Requires that the default C<testmail> message template has not
been removed from the configuration unless another message template is selected.

=cut

command "smtptest" => {
    mailto => { isa => 'Str', label => 'Recipient email address for the test message', required => 1 },
    message => { isa => 'Str', label => 'Notification template name to use', default => 'testmail' },
} => sub ($self, $param) {

    my $res = $self->run_command('send_notification', {
        message => $param->message,
        params => { notify_to => $param->mailto },
    });
    return $res;
};

__PACKAGE__->meta->make_immutable;


