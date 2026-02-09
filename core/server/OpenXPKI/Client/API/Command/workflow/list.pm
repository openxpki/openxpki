package OpenXPKI::Client::API::Command::workflow::list;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::workflow::list

=head1 DESCRIPTION

List workflow instances matching the given filter criteria.

=cut

sub hint_type ($self, $input_params) {
    my $types = $self->run_command('get_workflow_instance_types');
    $self->log->trace('Workflow instance types: ' . Dumper $types) if $self->log->is_trace;
    return [ map { sprintf '%s (%s)', $_, $types->{$_}->{label} } sort keys %$types ];
}

sub hint_proc_state ($self, $input_params) {
    return [qw( running manual finished pause exception retry_exceeded archived failed )];
}

command "list" => {
    state => { isa => 'Str', label => 'Filter by workflow state' },
    proc_state => { isa => 'Str', label => 'Filter by processing state (e.g. running, manual, exception)', hint => 'hint_proc_state' },
    type => { isa => 'Str', label => 'Filter by workflow type', hint => 'hint_type' },
    limit => { isa => 'Int', label => 'Maximum number of results to return', default => 25 },
} => sub ($self, $param) {

    my %query = map {
        my $predicate = "has_$_";
        $param->$predicate ? ($_ => $param->$_) : ()
    } qw( type proc_state state limit );

    my $res = $self->run_command('search_workflow_instances', \%query );
    return $res;
};

__PACKAGE__->meta->make_immutable;
