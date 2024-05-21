package OpenXPKI::Client::API::Command::workflow::wakeup;
use OpenXPKI -plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::workflow::wakeup

=head1 SYNOPSIS

Manually wakeup a paused workflow.

=cut

command "wakeup" => {
    id => { isa => 'Int', label => 'Workflow Id', required => 1 },
    async => { isa => 'Bool' },
    wait => { isa => 'Bool' },
} => sub ($self, $param) {

    my $res = $self->rawapi->run_command('wakeup_workflow', {
        id => $param->id,
        async => $param->async ? 1 : 0,
        wait => $param->wait ? 1 : 0,
    });
    return $res;

};

__PACKAGE__->meta->make_immutable;

