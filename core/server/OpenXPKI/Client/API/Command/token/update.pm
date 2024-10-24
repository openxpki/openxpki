package OpenXPKI::Client::API::Command::token::update;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
    protected => 1,
;

use OpenXPKI::Serialization::Simple;

=head1 NAME

OpenXPKI::Client::API::Command::token::update

=head1 DESCRIPTION

Add a new generation of a crytographic token.

=cut

sub hint_type ($self, $input_params) {
    my $groups = $self->run_command('list_token_groups');
    return [ keys %{$groups->params} ];
}

command "update" => {
    alias => { isa => 'Str', 'label' => 'Alias', hint => 'hint_type', required => 1 },
    key => { isa => 'FileContents', label => 'Key file (new)' },
    key_update => { isa => 'FileContents', label => 'Key file (update)' },
    notbefore => { isa => 'Epoch', label => 'Validity override (notbefore)' },
    notafter => { isa => 'Epoch', label => 'Validity override (notafter)' },
} => sub ($self, $param) {

    my $alias = $param->alias;
    $self->check_alias($alias);

    my $cmd_param = { alias => $alias };

    foreach my $key (qw( notbefore notafter )) {
        my $predicate = "has_$key";
        $cmd_param->{$key} = $param->$key if $param->$predicate;
    }

    my $res;
    if ((scalar keys %$param) > 1) {
        $res = $self->run_protected_command('update_alias', $cmd_param );
        $self->log->debug("Alias '$alias' was updated");
    } else {
        $res = $self->run_command('show_alias', $cmd_param );
        die "Alias '$alias' not found" unless $res;
    }

    # update the key - the handle_key method will die if the alias is not a token
    if ($param->has_key) {
        my $token = $self->handle_key($alias, $param->key->$*); # type "FileContents" is a ScalarRef
        $self->log->debug("Key for '$alias' was added");
        $res->params->{key_name} = $token->param('key_name');
    # set force for update mode (overwrites exising key)
    } elsif ($param->has_key_update) {
        my $token = $self->handle_key($alias, $param->key_update->$*, 1); # type "FileContents" is a ScalarRef
        $self->log->debug("Key for '$alias' was updated");
        $res->params->{key_name} = $token->param('key_name');
    }

    return $res;
};

__PACKAGE__->meta->make_immutable;
