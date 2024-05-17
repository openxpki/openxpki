package OpenXPKI::Client::API::Command::workflow::resume;
use OpenXPKI -plugin;

with 'OpenXPKI::Client::API::Command::workflow';
set_namespace_to_parent;
__PACKAGE__->needs_realm;

=head1 NAME

OpenXPKI::Client::API::Command::workflow::resume;

=head1 SYNOPSIS

Resume a workflow from an exception state.

=cut

command "resume" => {
    id => { isa => 'Int', label => 'Workflow Id', required => 1 },
    async => { isa => 'Bool' },
    wait => { isa => 'Bool' },
    force => { isa => 'Bool' },
} => sub ($self, $param) {

    my $res = $self->rawapi->run_command('resume_workflow', {
        id => $param->id,
        async => $param->async ? 1 : 0,
        wait => $param->wait ? 1 : 0,
    });
    return $res;
};

__PACKAGE__->meta->make_immutable;

