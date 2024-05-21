package OpenXPKI::Client::API::Command::datapool::rename;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::datapool::rename

=head1 SYNOPSIS

Change the key of an existing datapool value

=cut

command "rename" => {
    namespace => { isa => 'Str', label => 'Namespace', hint => 'hint_namespace', required => 1 },
    key => { isa => 'Str', label => 'Key', hint => 'hint_key', required => 1 },
    newkey => { isa => 'Str', label => 'New value of for key', required => 1 },
} => sub ($self, $param) {

    my $res = $self->rawapi->run_command('modify_data_pool_entry', {
        namespace => $param->namespace,
        key =>  $param->key,
        newkey => $param->newkey,
    });
    return $res;

};

__PACKAGE__->meta->make_immutable;
