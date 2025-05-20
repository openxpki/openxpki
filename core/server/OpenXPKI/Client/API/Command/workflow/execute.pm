package OpenXPKI::Client::API::Command::workflow::execute;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::workflow::execute

=head1 DESCRIPTION

Run action on an existing workflow instance

=cut

sub hint_action ($self, $input_params) {
    my $actions = $self->run_command('get_workflow_activities', { id => $input_params->{id} });
    $self->log->trace(Dumper $actions->result) if ($self->log->is_trace);
    return $actions->result || [];
}

command "execute" => {
    id => { isa => 'Int', label => 'Workflow Id', required => 1 },
    action => { isa => 'Str', label => 'Action', hint => 'hint_action', required => 1 },
} => sub ($self, $param) {

    my $wf_parameters = $self->build_hash_from_payload($param);

    my $res = $self->run_command('execute_workflow_activity', {
            id => $param->id,
            activity => $param->action,
            params => $wf_parameters,
    });
    return $res;

};

__PACKAGE__->meta->make_immutable;
