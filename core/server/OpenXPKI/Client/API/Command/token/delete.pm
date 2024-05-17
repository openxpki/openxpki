package OpenXPKI::Client::API::Command::token::delete;
use OpenXPKI -plugin;

with 'OpenXPKI::Client::API::Command::token';
set_namespace_to_parent;
__PACKAGE__->needs_realm;
with 'OpenXPKI::Client::API::Command::Protected';

=head1 NAME

OpenXPKI::Client::API::Command::token::delete

=head1 SYNOPSIS

Delete the token for a given alias name

=cut

command "delete" => {
    alias => { isa => 'Str', 'label' => 'Alias', required => 1, trigger => \&check_alias  },
    remove_key => { isa => 'Bool', 'label' => 'Remove the key' },
} => sub ($self, $param) {

    my $alias = $param->alias;

    my $res = $self->rawapi->run_command('show_alias', { alias => $alias });
    die "Alias '$alias not' found\n" unless $res->param('alias');

    if ($param->remove_key) {
        my $token = $self->rawapi->run_command('get_token_info', { alias => $alias });
        if ($token->param('key_store') ne 'DATAPOOL') {
            die "Unable to remove key as key is not stored in datapool\n";
        }
        $self->rawapi->run_command('delete_data_pool_entry', {
            namespace => 'sys.crypto.keys',
            key => $token->param('key_name'),
        });
    }

    $res = $self->rawapi->run_protected_command('delete_alias', { alias => $alias });

    return $res;
};

__PACKAGE__->meta->make_immutable;
