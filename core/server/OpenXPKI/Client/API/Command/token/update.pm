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

Update an existing token alias.

Can update validity overrides and/or add or replace the private key.
Use C<key> to import a new key (fails if a key already exists) or
C<key_update> to overwrite an existing key.

=cut

sub hint_type ($self, $input_params) {
    my $groups = $self->run_command('list_token_groups');
    return [ keys %{$groups->params} ];
}

command "update" => {
    alias => { isa => 'Str', 'label' => 'Token alias to update', hint => 'hint_type', required => 1 },
    key => { isa => 'FileContents', label => 'PEM-encoded key file to add (fails if key exists)' },
    key_update => { isa => 'FileContents', label => 'PEM-encoded key file to replace existing key' },
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

    my $res;
    if ((scalar keys $cmd_param->%*) > 1) {
        $res = $self->run_protected_command('update_alias', $cmd_param );
        $self->log->debug("Alias '$alias' was updated");
    } else {
        $res = $self->run_command('show_alias', $cmd_param );
        die "Alias '$alias' not found" unless $res;
    }

    # update the key - the handle_key method will die if the alias is not a token
    if ($param->has_key) {
        # type "FileContents" is a ScalarRef
        my $token = $self->handle_key({
            alias => $alias,
            key => $param->key->$*
        });
        $self->log->debug("Key for '$alias' was added");
        $res->params->{key_name} = $token->param('key_name');
    # set force for update mode (overwrites exising key)
    } elsif ($param->has_key_update) {
        my $token = $self->handle_key({
            alias => $alias,
            key => $param->key_update->$*,
            force => 1,
        });
        $self->log->debug("Key for '$alias' was updated");
        $res->params->{key_name} = $token->param('key_name');
    }

    return $res;
};

__PACKAGE__->meta->make_immutable;
