package OpenXPKI::Client::API::Command::workflow::reset;
use OpenXPKI -plugin;

with 'OpenXPKI::Client::API::Command::workflow';
set_namespace_to_parent;
__PACKAGE__->needs_realm;

=head1 NAME

OpenXPKI::Client::API::Command::workflow::reset;

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
