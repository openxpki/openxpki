package OpenXPKI::Client::API::Command::token::delete;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
    protected => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::token::delete

=head1 DESCRIPTION

Delete the token for a given alias name

=cut

command "delete" => {
    alias => { isa => 'Str', 'label' => 'Alias', required => 1 },
    remove_key => { isa => 'Bool', 'label' => 'Remove the key', default => 0 },
} => sub ($self, $param) {

    my $alias = $param->alias;
    $self->check_alias($alias);

    my $res = $self->run_command('show_alias', { alias => $alias });
    die "Alias '$alias not' found\n" unless $res->param('alias');

    if ($param->remove_key) {
        my $token = $self->run_command('get_token_info', { alias => $alias });
        if ($token->param('key_store') ne 'DATAPOOL') {
            die "Unable to remove key as key is not stored in datapool\n";
        }
        $self->run_command('delete_data_pool_entry', {
            namespace => 'sys.crypto.keys',
            key => $token->param('key_name'),
        });
    }

    $res = $self->run_protected_command('delete_alias', { alias => $alias });

    return $res;
};

__PACKAGE__->meta->make_immutable;
