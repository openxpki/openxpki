package OpenXPKI::Client::API::Command::alias::list;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

use List::Util 'any';

=head1 NAME

OpenXPKI::Client::API::Command::alias::list

=head1 SYNOPSIS

List (non-token) alias entries

=cut

sub hint_group ($self, $input_params) {
    my $aliases = $self->rawapi->run_command('list_alias_groups');
    my $tokens = $self->rawapi->run_command('list_token_groups');

    my @groups;
    while (my $item = shift @{$aliases->param('result')}) {
        push @groups, $item unless (any { $item eq $_ } values %{$tokens->params});
    }
    return  \@groups;
}

command "list" => {
    group => { isa => 'Str', label => 'Token group (e.g. tg_server)', hint => 'hint_group' },
    expired => { isa => 'Bool' },
    valid => { isa => 'Bool' },
    upcoming => { isa => 'Bool' },
} => sub ($self, $param) {

    $self->check_group($param->group);

    my $groups = $self->hint_group();
    my $res = {};

    my %validity;
    foreach my $key ('expired','valid','upcoming') {
        $validity{$key} = 1 if $param->$key;
    }

    foreach my $group (@$groups) {
        my $entries = $self->rawapi->run_command('list_aliases', { group => $group, %validity } );
        $res->{$group} = {
            count => (scalar @{$entries->result}),
            item => $entries->result,
        };
    }
    return $res;
};

__PACKAGE__->meta->make_immutable;
