package OpenXPKI::Client::API::Command::workflow::reset;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::workflow::reset

=head1 SYNOPSIS

Manually reset a hanging workflow, see I<reset_workflow> for details.

=cut

command "reset" => {
    id => { isa => 'Int', label => 'Workflow Id', required => 1 },
} => sub ($self, $param) {

    my $res = $self->rawapi->run_command('reset_workflow', {
        id => $param->id,
    });
    return $res;

};

__PACKAGE__->meta->make_immutable;
