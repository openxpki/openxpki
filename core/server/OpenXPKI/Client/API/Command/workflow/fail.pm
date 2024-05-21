package OpenXPKI::Client::API::Command::workflow::fail;
use OpenXPKI -plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::workflow::fail

=head1 SYNOPSIS

Manually set a hanging workflow to failed, see I<fail_workflow> for
details.

=cut

command "fail" => {
    id => { isa => 'Int', label => 'Workflow Id', required => 1 },
    error => { isa => 'Bool', label => 'Error message' },
    reason => { isa => 'Bool', label => 'Error reason' },
} => sub ($self, $param) {

    my $res = $self->rawapi->run_command('fail_workflow', {
        id => $param->id,
        error => $param->error || '',
        reason => $param->reason || '',
    });
    return $res;

};

__PACKAGE__->meta->make_immutable;
