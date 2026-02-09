package OpenXPKI::Client::API::Command::datapool::delete;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::datapool::delete

=head1 DESCRIPTION

Delete a single entry or an entire namespace from the datapool.

Either C<key> or C<all> must be provided.

=cut

command "delete" => {
    namespace => { isa => 'Str', label => 'Datapool namespace', hint => 'hint_namespace', required => 1 },
    key => { isa => 'Str', label => 'Key of the entry to delete', hint => 'hint_key',},
    all => { isa => 'Bool', label => 'Delete all entries in the namespace' },
} => sub ($self, $param) {

    my $res;
    if ($param->has_key) {
        $res = $self->run_command('delete_data_pool_entry', {
            namespace => $param->namespace,
            key =>  $param->key,
        });
    } elsif ($param->has_all) {
        $res = $self->run_command('clear_data_pool_namespace', {
            namespace => $param->namespace,
        });
    } else {
        die "You must pass either a key to be deleted or the --all flag"
    }
    return $res;

};

__PACKAGE__->meta->make_immutable;
