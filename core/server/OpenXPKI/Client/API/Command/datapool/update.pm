package OpenXPKI::Client::API::Command::datapool::update;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::datapool::update

=head1 DESCRIPTION

Update the value and/or expiration date of a datapool item

=cut

command "update" => {
    namespace => { isa => 'Str', label => 'Namespace', hint => 'hint_namespace', required => 1 },
    key => { isa => 'Str', label => 'Key', hint => 'hint_key', required => 1 },
    value => { isa => 'Str', label => 'Value' },
    expiry => { isa => 'Epoch', label => 'Expiry Date' },
} => sub ($self, $param) {

    my $res;
    if ($param->has_value) {
        # get the old value to copy over expiry and encryption
        my $old = $self->run_command('get_data_pool_entry', {
            namespace => $param->namespace,
            key =>  $param->key,
        });

        my $expiration = $param->expiry // $old->param('expiration_date');
        my $encrypt = $old->param('encrypt') // 0;

        $self->run_command('set_data_pool_entry', {
            namespace => $param->namespace,
            key =>  $param->key,
            value => $param->value,
            ($expiration ? (expiration_date => $expiration) : ()),
            encrypt => $encrypt,
            force => 1,
        });

        $res = $self->run_command('get_data_pool_entry', {
            namespace => $param->namespace,
            key =>  $param->key,
        });

    } elsif ($param->has_expiry) {
        $res = $self->run_command('modify_data_pool_entry', {
            namespace => $param->namespace,
            key =>  $param->key,
            expiration_date => $param->expiry,
        });
    } else {
        die "You must provide at least one of value or expiry date to update";
    }
    return $res;

};

__PACKAGE__->meta->make_immutable;
