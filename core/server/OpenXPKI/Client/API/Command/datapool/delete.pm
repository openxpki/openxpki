package OpenXPKI::Client::API::Command::datapool::delete;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::datapool::delete

=head1 SYNOPSIS

Delete a single item or a full namespace from the datapool

=cut

command "delete" => {
    namespace => { isa => 'Str', label => 'Namespace', hint => 'hint_namespace', required => 1 },
    key => { isa => 'Str', label => 'Key if the item to be removed', hint => 'hint_key',},
    all => { isa => 'Bool', label => 'Remove the full namespace' },
} => sub ($self, $param) {

    my $res;
    if ($param->has_key) {
        $res = $self->rawapi->run_command('delete_data_pool_entry', {
            namespace => $param->namespace,
            key =>  $param->key,
        });
    } elsif ($param->has_all) {
        $res = $self->rawapi->run_command('clear_data_pool_namespace', {
            namespace => $param->namespace,
        });
    } else {
        die "You must pass either a key to be deleted or the --all flag"
    }
    return $res;

};

__PACKAGE__->meta->make_immutable;
