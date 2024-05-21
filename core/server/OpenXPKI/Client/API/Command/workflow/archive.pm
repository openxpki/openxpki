package OpenXPKI::Client::API::Command::workflow::archive;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::workflow::archive

=head1 SYNOPSIS

Trigger archivial of a workflow.

=cut

command "archive" => {
    id => { isa => 'Int', label => 'Workflow Id', required => 1 },
} => sub ($self, $param) {

    my $res = $self->run_command('archive_workflow', {
        id => $param->id,
    });
    return $res;
};

__PACKAGE__->meta->make_immutable;
