package OpenXPKI::Client::API::Command::workflow::show;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::workflow::show

=head1 SYNOPSIS

Show information on an existing workflow

=cut

command "show" => {
    id => { isa => 'Int', label => 'Workflow Id', required => 1 },
    attributes => { isa => 'Bool', label => 'Show Attributes', default => 0 },
    deserialize => { isa => 'Bool', label => 'Deserialize Context', description => 'Unpack serialized context items', default => 0 },
} => sub ($self, $param) {

    my $cmd_param = {
        id => $param->id,
        $param->attributes ? (with_attributes => 1) : (),
    };

    my $res = $self->rawapi->run_command('get_workflow_info', $cmd_param);
    $self->deserialize_context($res) if $param->deserialize;

    return $res;

};

__PACKAGE__->meta->make_immutable;


