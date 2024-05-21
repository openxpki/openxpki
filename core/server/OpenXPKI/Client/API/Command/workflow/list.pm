package OpenXPKI::Client::API::Command::workflow::list;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::workflow::list

=head1 SYNOPSIS

List workflow ids based on given filter criteria.

=cut

sub hint_type ($self, $input_params) {
    my $types = $self->rawapi->run_command('get_workflow_instance_types');
    $self->log->trace('Workflow instance types: ' . Dumper $types) if $self->log->is_trace;
    return [ map { sprintf '%s (%s)', $_, $types->{$_}->{label} } sort keys %$types ];
}

sub hint_proc_state ($self, $input_params) {
    return [qw( running manual finished pause exception retry_exceeded archived failed )];
}

command "list" => {
    state => { isa => 'Str', label => 'Workflow State' },
    proc_state => { isa => 'Str', label => 'Workflow Proc State', hint => 'hint_proc_state' },
    type => { isa => 'Str', label => 'Workflow Type', hint => 'hint_type' },
    limit => { isa => 'Int', label => 'Result Count', default => 25 },
} => sub ($self, $param) {

    my %query = map {
        my $predicate = "has_$_";
        $param->$predicate ? ($_ => $param->$_) : ()
    } qw( type proc_state state limit );

    my $res = $self->rawapi->run_command('search_workflow_instances', \%query );
    return $res;
};

__PACKAGE__->meta->make_immutable;
