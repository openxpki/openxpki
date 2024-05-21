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
    attributes => { isa => 'Bool', label => 'Show Attributes' },
    deserialize => { isa => 'Bool', label => 'Deserialize Context', description => 'Unpack serialized context items' },
} => sub ($self, $param) {

    my %param;
    if ($param->attributes) {
        $param{'with_attributes'} = 1;
    }
    $self->log->trace(Dumper \%param) if ($self->log->is_trace);
    my $res = $self->rawapi->run_command('get_workflow_info', { id => $param->id, %param });
    if ($param->deserialize) {
       $self->deserialize_context($res);
    }
    return $res;

};

__PACKAGE__->meta->make_immutable;


