package OpenXPKI::Client::API::Command::workflow::create;
use OpenXPKI -plugin;

with 'OpenXPKI::Client::API::Command::workflow';
set_namespace_to_parent;
__PACKAGE__->needs_realm;

=head1 NAME

OpenXPKI::Client::API::Command::workflow::create;

=head1 SYNOPSIS

Initiate a new workflow

=cut

sub hint_type ($self, $input_params) {
    # TODO - we need a new API method to get ALL types and not only the used ones!
    my $types = $self->rawapi->run_command('get_workflow_instance_types');
    my %types = $types->params->%*;
    $self->log->trace(Dumper \%types) if $self->log->is_trace;
    return [ map { sprintf '%s (%s)', $_, $types{$_}->{label} } sort keys %types ];
}

command "create" => {
    type => { isa => 'Str', label => 'Workflow Type', hint => 'hint_type', required => 1 },
} => sub ($self, $param) {

    my $wf_parameters = $self->_build_hash_from_payload($param);
    $self->log->info(Dumper $wf_parameters);

    my $res = $self->rawapi->run_command('create_workflow_instance', {
        workflow => $param->type,
        params => $wf_parameters,
    });
    return $res;

};

__PACKAGE__->meta->make_immutable;
