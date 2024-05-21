package OpenXPKI::Client::API::Command::datapool::list;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::datapool::list

=head1 SYNOPSIS

List datapool keys/items for a given namespace

=cut

command "list" => {
    namespace => { isa => 'Str', label => 'Namespace', hint => 'hint_namespace', required => 1 },
    limit => { isa => 'Int', label => 'Result Count', default => 25 },
    metadata => { isa => 'Bool', label => 'Show Metadata' },
} => sub ($self, $param) {

    my $query = {
        namespace => $param->namespace,
        $param->has_metadata ? (metadata => 1) : (),
    };
    my $res = $self->run_command('list_data_pool_entries', $query);
    return $res;

};

__PACKAGE__->meta->make_immutable;


