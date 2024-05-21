package OpenXPKI::Client::API::Command::config::smtptest;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::config::smtptest

=head1 SYNOPSIS

Send a test message for the selected realm to validate SMTP is working.

This test requires that you have not modified or removed the default
test message from the configuration!

=cut

command "smtptest" => {
    mailto => { isa => 'Str', label => 'The email address to send the mail to', required => 1 },
    message => { isa => 'Str', label => 'The message template to send', default => 'testmail' },
} => sub ($self, $param) {

    my $res = $self->rawapi->run_command('send_notification', {
        message => $param->message,
        params => { notify_to => $param->mailto },
    });
    return $res;
};

__PACKAGE__->meta->make_immutable;


