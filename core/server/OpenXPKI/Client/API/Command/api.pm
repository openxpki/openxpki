package OpenXPKI::Client::API::Command::api;
use OpenXPKI -role;

=head1 NAME

OpenXPKI::CLI::Command::api

=head1 DESCRIPTION

Run API commands.

=cut

sub hint_command ($self, $input_params){
    my $actions = $self->run_enquiry('command');
    $self->log->trace(Dumper $actions->result) if $self->log->is_trace;
    return $actions->result || [];
}

sub help_command ($self, $command) {
    return $self->run_enquiry('command', { command => $command })->params;
}

1;
