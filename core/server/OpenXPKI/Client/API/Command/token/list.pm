package OpenXPKI::Client::API::Command::token::list;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::token::list

=head1 SYNOPSIS

Show information about the active crypto tokens in a realm.

=cut

command "list" => {
    type => { isa => 'Str', 'label' => 'Token type (e.g. certsign)', hint => 'hint_type' },
} => sub ($self, $param) {

    my $groups = $self->rawapi->run_command('list_token_groups');
    my $res = { token_types => $groups->params, token_groups => {} };

    my @names = values %{$groups->params};
    if ($param->has_type) {
        @names = ( $groups->param($param->type) );
    }

    foreach my $group (@names) {
        my $entries = $self->rawapi->run_command('list_active_aliases', { group => $group });
        my $grp = {
            count => (scalar @{$entries->result}),
            active => $entries->result->[0]->{alias},
            token => [],
        };
        foreach my $entry (@{$entries->result}) {
            my $token = $self->rawapi->run_command('get_token_info', { alias => $entry->{alias} });
            delete $token->params->{key_cert};
            push @{$grp->{token}}, $token->params;
        }
        $res->{token_groups}->{$group} = $grp;
    }
    return $res;
};

__PACKAGE__->meta->make_immutable;
