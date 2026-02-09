package OpenXPKI::Client::API::Command::workflow::reset;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::workflow::reset

=head1 DESCRIPTION

Manually reset a hanging workflow.

See the C<reset_workflow> API command for details on the underlying
operation.

=cut

command "reset" => {
    id => { isa => 'Int', label => 'Workflow ID to reset', required => 1 },
} => sub ($self, $param) {

    my $res = $self->run_command('reset_workflow', {
        id => $param->id,
    });
    return $res;

};

__PACKAGE__->meta->make_immutable;
