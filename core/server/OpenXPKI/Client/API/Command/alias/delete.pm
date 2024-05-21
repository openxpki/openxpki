package OpenXPKI::Client::API::Command::alias::delete;
use OpenXPKI -plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
    protected => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::alias::delete

=head1 SYNOPSIS

Delete an alias

=cut

command "delete" => {
    alias => { isa => 'Str', 'label' => 'Alias', required => 1, trigger => \&check_alias },
    remove_key => { isa => 'Bool', 'label' => 'Remove the key' },
} => sub ($self, $param) {

    my $alias = $param->alias;
    my $cmd_param = { alias => $alias };

    my $res = $self->rawapi->run_command('show_alias', $cmd_param );
    die "Alias '$alias not' found" unless $res->param('alias');

    $res = $self->rawapi->run_protected_command('delete_alias', $cmd_param );
    return $res;
};

__PACKAGE__->meta->make_immutable;
