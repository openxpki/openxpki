package OpenXPKI::Client::API::Command::alias::delete;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
    protected => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::alias::delete

=head1 DESCRIPTION

Delete an alias

=cut

command "delete" => {
    alias => { isa => 'Str', 'label' => 'Alias', required => 1 },
    remove_key => { isa => 'Bool', 'label' => 'Remove the key' },
} => sub ($self, $param) {

    # TODO Parameter remove_key is not processed

    my $alias = $param->alias;
    $self->check_alias($alias);

    my $cmd_param = { alias => $alias };

    my $res = $self->run_command('show_alias', $cmd_param );
    die "Alias '$alias not' found" unless $res->param('alias');

    $res = $self->run_protected_command('delete_alias', $cmd_param );
    return $res;
};

__PACKAGE__->meta->make_immutable;
