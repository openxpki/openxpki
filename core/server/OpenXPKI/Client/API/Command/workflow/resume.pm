package OpenXPKI::Client::API::Command::workflow::resume;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::workflow::resume

=head1 DESCRIPTION

Resume a workflow from an exception state.

=cut

command "resume" => {
    id => { isa => 'Int', label => 'Workflow ID to resume', required => 1 },
    async => { isa => 'Bool', label => 'Execute the resume asynchronously' },
    wait => { isa => 'Bool', label => 'Wait for the workflow to reach the next stop point' },
    force => { isa => 'Bool', label => 'Force resume from I<running> state - this is dangerous!' },
} => sub ($self, $param) {

    my $res = $self->run_command('resume_workflow', {
        id => $param->id,
        async => $param->async ? 1 : 0,
        wait => $param->wait ? 1 : 0,
        force => $param->force ? 1 : 0,
    });
    return $res;
};

__PACKAGE__->meta->make_immutable;

