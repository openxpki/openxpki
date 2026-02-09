package OpenXPKI::Client::API::Command::datapool::list;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::datapool::list

=head1 DESCRIPTION

List datapool keys in a given namespace.

=cut

command "list" => {
    namespace => { isa => 'Str', label => 'Datapool namespace to list', hint => 'hint_namespace', required => 1 },
    limit => { isa => 'Int', label => 'Maximum number of entries to return', default => 25 },
    metadata => { isa => 'Bool', label => 'Include creation date, expiration and encryption flag' },
} => sub ($self, $param) {

    my $query = {
        namespace => $param->namespace,
        $param->has_metadata ? (metadata => 1) : (),
    };
    my $res = $self->run_command('list_data_pool_entries', $query);
    return $res;

};

__PACKAGE__->meta->make_immutable;


