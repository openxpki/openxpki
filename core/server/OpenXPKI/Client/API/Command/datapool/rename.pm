package OpenXPKI::Client::API::Command::datapool::rename;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::datapool::rename

=head1 DESCRIPTION

Rename the B<key> of an existing datapool entry.

The value and all metadata are preserved; only the key name changes.

=cut

command "rename" => {
    namespace => { isa => 'Str', label => 'Datapool namespace', hint => 'hint_namespace', required => 1 },
    key => { isa => 'Str', label => 'Current key name', hint => 'hint_key', required => 1 },
    newkey => { isa => 'Str', label => 'New key name', required => 1 },
} => sub ($self, $param) {

    my $res = $self->run_command('modify_data_pool_entry', {
        namespace => $param->namespace,
        key =>  $param->key,
        newkey => $param->newkey,
    });
    return $res;

};

__PACKAGE__->meta->make_immutable;
