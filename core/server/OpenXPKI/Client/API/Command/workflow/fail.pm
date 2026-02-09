package OpenXPKI::Client::API::Command::workflow::fail;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::workflow::fail

=head1 DESCRIPTION

Manually set a hanging workflow to the failed state.

See the C<fail_workflow> API command for details on the underlying
operation.

=cut

command "fail" => {
    id => { isa => 'Int', label => 'Workflow ID to fail', required => 1 },
    error => { isa => 'Str', label => 'Error message to record' },
    reason => { isa => 'Str', label => 'Error reason to record' },
} => sub ($self, $param) {

    my $res = $self->run_command('fail_workflow', {
        id => $param->id,
        error => $param->error || '',
        reason => $param->reason || '',
    });
    return $res;

};

__PACKAGE__->meta->make_immutable;
