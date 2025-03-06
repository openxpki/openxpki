package OpenXPKI::Client::API::Command::alias::list;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

use List::Util 'any';

=head1 NAME

OpenXPKI::Client::API::Command::alias::list

=head1 DESCRIPTION

List (non-token) alias entries

=cut

sub hint_group ($self, $input_params) {
    my $aliases = $self->run_command('list_alias_groups');
    my $tokens = $self->run_command('list_token_groups');
    my @groups;
    foreach my $item ($aliases->result()->@*) {
        next unless ($item);
        push @groups, $item unless (any { $item eq $_ } values %{$tokens->params});
    }
    $self->log->trace(Dumper \@groups);
    return  \@groups;
}

command "list" => {
    group => { isa => 'Str', label => 'Token group (e.g. tg_server)', hint => 'hint_group' },
    expired => { isa => 'Bool' },
    valid => { isa => 'Bool' },
    upcoming => { isa => 'Bool' },
} => sub ($self, $param) {

    my $groups;
    if ($param->group) {
        $self->check_group($param->group);
        $groups = [ $param->group ];
    } else {
        $groups = hint_group($self, '');
    }

    my $res = {};
    my %validity;
    foreach my $key ('expired','valid','upcoming') {
        $validity{$key} = 1 if $param->$key;
    }

    foreach my $group (@$groups) {
        my $entries = $self->run_command('list_aliases', { group => $group, %validity } );
        $res->{$group} = {
            count => (scalar @{$entries->result}),
            item => $entries->result,
        };
    }
    return $res;
};

__PACKAGE__->meta->make_immutable;
