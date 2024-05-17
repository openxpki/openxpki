package OpenXPKI::Client::API::Command::datapool::list;
use OpenXPKI -plugin;

with 'OpenXPKI::Client::API::Command::datapool';
set_namespace_to_parent;
__PACKAGE__->needs_realm;

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

    my %query = (
        namespace => $param->namespace,
    );
    $query{metadata} = 1 if ($param->metadata);
    my $res = $self->rawapi->run_command('list_data_pool_entries', \%query );
    return $res;

};

__PACKAGE__->meta->make_immutable;


