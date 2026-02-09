package OpenXPKI::Client::API::Command::alias::update;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
    protected => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::alias::update

=head1 DESCRIPTION

Update validity overrides of an existing non-token alias.

At least one of the update parameters must be provided.

=cut

sub hint_alias ($self, $input_params) {
    my $groups = $self->run_command('list_token_groups');
    return [ keys %{$groups->params} ];
}

command "update" => {
    alias => { isa => 'Str', 'label' => 'Alias name to update', hint => 'hint_alias', required => 1 },
    notbefore => { isa => 'Epoch', label => 'Override validity start (epoch)' },
    notafter => { isa => 'Epoch', label => 'Override validity end (epoch)' },
} => sub ($self, $param) {

    my $alias = $param->alias;
    $self->check_alias($alias);

    my $cmd_param = { alias => $alias };

    foreach my $key (qw( notbefore notafter )) {
        my $predicate = "has_$key";
        $cmd_param->{$key} = $param->$key if $param->$predicate;
    }

    die "At least one update parameter is mandatory" unless (scalar keys %$cmd_param);

    my $res = $self->run_protected_command('update_alias', $cmd_param);
    $self->log->debug("Alias '$alias' was updated");
    return $res;
};

__PACKAGE__->meta->make_immutable;
