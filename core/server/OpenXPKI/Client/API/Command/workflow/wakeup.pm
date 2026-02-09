package OpenXPKI::Client::API::Command::workflow::wakeup;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::workflow::wakeup

=head1 DESCRIPTION

Manually wake up a paused workflow.

=cut

command "wakeup" => {
    id => { isa => 'Int', label => 'Workflow ID to wake up', required => 1 },
    async => { isa => 'Bool', label => 'Execute the wakeup asynchronously' },
    wait => { isa => 'Bool', label => 'Wait for the workflow to reach the next stop point' },
} => sub ($self, $param) {

    my $res = $self->run_command('wakeup_workflow', {
        id => $param->id,
        async => $param->async ? 1 : 0,
        wait => $param->wait ? 1 : 0,
    });
    return $res;

};

__PACKAGE__->meta->make_immutable;

